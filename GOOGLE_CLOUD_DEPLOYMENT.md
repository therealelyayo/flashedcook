# Google Cloud Deployment Guide

This guide provides instructions for deploying the EvilnoVNC application to Google Cloud Platform.

## Overview

This Docker-orchestrated application is **fully compatible** with Google Cloud Platform. Unlike Vercel, GCP supports:
- Docker container orchestration
- Persistent connections (VNC/WebSocket)
- Dynamic container creation
- File system writes

## Deployment Options

### Option 1: Google Compute Engine (Recommended)

Best for full functionality with Docker-in-Docker support.

#### Prerequisites
- Google Cloud account with billing enabled
- `gcloud` CLI installed ([Install Guide](https://cloud.google.com/sdk/docs/install))
- Docker installed locally (for testing)

#### Step 1: Setup GCloud CLI

```bash
# Login to Google Cloud
gcloud auth login

# Set your project ID
gcloud config set project YOUR_PROJECT_ID

# Enable required APIs
gcloud services enable compute.googleapis.com
gcloud services enable container.googleapis.com
```

#### Step 2: Create a VM Instance

```bash
# Create a VM with Docker pre-installed
gcloud compute instances create evilnovnc-vm \
    --zone=us-central1-a \
    --machine-type=e2-standard-4 \
    --image-family=cos-stable \
    --image-project=cos-cloud \
    --boot-disk-size=50GB \
    --boot-disk-type=pd-standard \
    --tags=http-server,https-server \
    --metadata=startup-script='#!/bin/bash
        # Docker is pre-installed in Container-Optimized OS
        echo "VM ready for Docker deployment"'

# Create firewall rule for HTTP traffic
gcloud compute firewall-rules create allow-http \
    --allow tcp:80 \
    --target-tags http-server \
    --description="Allow HTTP traffic"

# Create firewall rule for HTTPS traffic
gcloud compute firewall-rules create allow-https \
    --allow tcp:443 \
    --target-tags https-server \
    --description="Allow HTTPS traffic"
```

#### Step 3: Deploy the Application

```bash
# SSH into the VM
gcloud compute ssh evilnovnc-vm --zone=us-central1-a

# Once inside the VM, clone the repository
# Note: Replace with your fork's URL if you've modified the code
git clone https://github.com/therealelyayo/flashedcook.git
cd flashedcook

# Build Docker images
sudo docker build -f evilnovnc.Dockerfile -t evilnovnc .
sudo docker build -f nginx.Dockerfile -t evilnginx .

# Create Downloads directory with proper permissions
sudo mkdir -p Downloads && sudo chown -R 103 Downloads

# Run the application
./start_auto.sh https://your-target-url.com
```

#### Step 4: Access Your Application

```bash
# Get the external IP of your VM
gcloud compute instances describe evilnovnc-vm \
    --zone=us-central1-a \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)'

# Access the application at http://EXTERNAL_IP
```

#### Step 5: (Optional) Setup a Domain

```bash
# Reserve a static IP
gcloud compute addresses create evilnovnc-ip \
    --region=us-central1

# Get the static IP
gcloud compute addresses describe evilnovnc-ip \
    --region=us-central1 \
    --format='get(address)'

# Update your VM to use the static IP
gcloud compute instances delete-access-config evilnovnc-vm \
    --zone=us-central1-a \
    --access-config-name="external-nat"

gcloud compute instances add-access-config evilnovnc-vm \
    --zone=us-central1-a \
    --address=STATIC_IP
```

Then configure your domain's DNS A record to point to the static IP.

---

### Option 2: Google Kubernetes Engine (GKE)

For production-scale deployment with better orchestration.

#### Prerequisites
- `kubectl` installed ([Install Guide](https://kubernetes.io/docs/tasks/tools/))

#### Step 1: Create a GKE Cluster

```bash
# Create a GKE cluster
gcloud container clusters create evilnovnc-cluster \
    --zone=us-central1-a \
    --machine-type=e2-standard-4 \
    --num-nodes=3 \
    --enable-autoscaling \
    --min-nodes=1 \
    --max-nodes=5

# Get credentials for kubectl
gcloud container clusters get-credentials evilnovnc-cluster \
    --zone=us-central1-a
```

#### Step 2: Build and Push Docker Images

```bash
# Configure Docker to use gcloud as credential helper
gcloud auth configure-docker

# Build and tag images
docker build -f evilnovnc.Dockerfile -t gcr.io/YOUR_PROJECT_ID/evilnovnc:latest .
docker build -f nginx.Dockerfile -t gcr.io/YOUR_PROJECT_ID/evilnginx:latest .

# Push to Google Container Registry
docker push gcr.io/YOUR_PROJECT_ID/evilnovnc:latest
docker push gcr.io/YOUR_PROJECT_ID/evilnginx:latest
```

#### Step 3: Deploy Using Kubernetes Manifests

Use the provided Kubernetes manifests in the `k8s/` directory:

```bash
# Apply Kubernetes configurations
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/deployment.yaml
kubectl apply -f k8s/service.yaml

# Get the external IP
kubectl get service evilnovnc-service -n evilnovnc
```

See `kubernetes-deployment.yaml` for the full manifest.

---

### Option 3: Google Cloud Run (Limited)

⚠️ **Not Recommended** - Cloud Run has limitations:
- No Docker-in-Docker support
- 15-minute request timeout
- Cannot create dynamic containers

Only suitable for serving static files (same limitations as Vercel).

---

## Cost Estimation

### Compute Engine (e2-standard-4)
- **VM**: ~$120/month (4 vCPUs, 16 GB RAM)
- **Storage**: ~$4/month (50 GB)
- **Network**: Variable based on traffic
- **Total**: ~$125-150/month

### GKE (3 nodes)
- **Cluster**: ~$360/month (3 x e2-standard-4)
- **Storage**: ~$10/month
- **Network**: Variable
- **Total**: ~$370-400/month

### Tips to Reduce Costs
- Use preemptible VMs (70% discount, but can be terminated)
- Use committed use discounts (up to 57% discount)
- Auto-scale based on demand
- Use regional instances instead of zonal

```bash
# Create a preemptible VM instance (much cheaper)
gcloud compute instances create evilnovnc-vm-preemptible \
    --zone=us-central1-a \
    --machine-type=e2-standard-4 \
    --preemptible \
    --image-family=cos-stable \
    --image-project=cos-cloud
```

---

## Monitoring and Logs

```bash
# View VM logs
gcloud compute instances get-serial-port-output evilnovnc-vm \
    --zone=us-central1-a

# SSH and check Docker logs
gcloud compute ssh evilnovnc-vm --zone=us-central1-a
sudo docker logs evilnginx
sudo docker logs <container-id>

# For GKE
kubectl logs -f deployment/evilnovnc -n evilnovnc
```

---

## Cleanup

### Compute Engine
```bash
# Stop the VM
gcloud compute instances stop evilnovnc-vm --zone=us-central1-a

# Delete the VM
gcloud compute instances delete evilnovnc-vm --zone=us-central1-a

# Delete firewall rules
gcloud compute firewall-rules delete allow-http
gcloud compute firewall-rules delete allow-https

# Release static IP (if created)
gcloud compute addresses delete evilnovnc-ip --region=us-central1
```

### GKE
```bash
# Delete the cluster
gcloud container clusters delete evilnovnc-cluster --zone=us-central1-a

# Delete images from Container Registry
gcloud container images delete gcr.io/YOUR_PROJECT_ID/evilnovnc:latest
gcloud container images delete gcr.io/YOUR_PROJECT_ID/evilnginx:latest
```

---

## Security Considerations

1. **Firewall Rules**: Only open necessary ports (80, 443)
2. **IAM Permissions**: Use least privilege principle
3. **Network Policies**: Implement network segmentation in GKE
4. **SSL/TLS**: Use Google-managed SSL certificates or Let's Encrypt
5. **Regular Updates**: Keep Docker images and OS updated

```bash
# Add SSL with Google-managed certificate (GKE)
kubectl apply -f k8s/managed-certificate.yaml
kubectl apply -f k8s/ingress.yaml
```

---

## Troubleshooting

### VM won't start
```bash
# Check VM status
gcloud compute instances describe evilnovnc-vm --zone=us-central1-a

# Check quota limits
gcloud compute project-info describe --project=YOUR_PROJECT_ID
```

### Docker containers not starting
```bash
# SSH into VM
gcloud compute ssh evilnovnc-vm --zone=us-central1-a

# Check Docker status
sudo docker ps -a
sudo docker logs evilnginx

# Check disk space
df -h
```

### Cannot access application
```bash
# Verify firewall rules
gcloud compute firewall-rules list

# Check VM external IP
gcloud compute instances describe evilnovnc-vm \
    --zone=us-central1-a \
    --format='get(networkInterfaces[0].accessConfigs[0].natIP)'

# Test connectivity
curl http://EXTERNAL_IP
```

---

## Additional Resources

- [Google Compute Engine Documentation](https://cloud.google.com/compute/docs)
- [Google Kubernetes Engine Documentation](https://cloud.google.com/kubernetes-engine/docs)
- [Container-Optimized OS](https://cloud.google.com/container-optimized-os/docs)
- [Google Cloud Pricing Calculator](https://cloud.google.com/products/calculator)

---

## Support

For issues specific to Google Cloud deployment:
- [Google Cloud Support](https://cloud.google.com/support)
- [Stack Overflow - google-cloud-platform](https://stackoverflow.com/questions/tagged/google-cloud-platform)

For application-specific issues:
- See the main [README.md](README.md)
