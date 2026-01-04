# Docker Hub Deployment

This document explains how to set up automated Docker image publishing to Docker Hub using GitHub Actions.

## Overview

The GitHub Actions workflow automatically builds and publishes two Docker images to Docker Hub:
- `evilnovnc` - The main application container
- `evilnginx` - The nginx reverse proxy container

## Prerequisites

1. A Docker Hub account
2. Repository secrets configured in GitHub

## Setup Instructions

### 1. Create Docker Hub Access Token

1. Log in to [Docker Hub](https://hub.docker.com/)
2. Go to Account Settings → Security → [New Access Token](https://hub.docker.com/settings/security)
3. Create a new access token with Read & Write permissions
4. Copy the generated token (you won't be able to see it again)

### 2. Configure GitHub Secrets

Add the following secrets to your GitHub repository:

1. Go to your repository on GitHub
2. Navigate to Settings → Secrets and variables → Actions
3. Click "New repository secret" and add:

   - **Name**: `DOCKER_USERNAME`
     - **Value**: Your Docker Hub username

   - **Name**: `DOCKER_PASSWORD`
     - **Value**: Your Docker Hub access token (from step 1)

### 3. Workflow Triggers

The workflow automatically runs when:

- **Push to main/master branch**: Builds and pushes images with the `latest` tag and branch name
- **Push tags**: When you push a version tag (e.g., `v1.0.0`), it creates versioned images
- **Manual trigger**: You can manually trigger the workflow from the Actions tab

### 4. Tagging and Versioning

The workflow uses the following tagging strategy:

- `latest` - Always points to the most recent build from the default branch
- `main` or `master` - Tagged with the branch name
- `v1.0.0` - Semantic version tags (when you push git tags)
- `v1.0` - Major.minor version
- `v1` - Major version only

#### Creating a Release

To create a versioned release:

```bash
git tag -a v1.0.0 -m "Release version 1.0.0"
git push origin v1.0.0
```

## Using Published Images

Once the images are published to Docker Hub, users can pull them directly:

```bash
# Pull the latest version
docker pull <your-dockerhub-username>/evilnovnc:latest
docker pull <your-dockerhub-username>/evilnginx:latest

# Pull a specific version
docker pull <your-dockerhub-username>/evilnovnc:v1.0.0
docker pull <your-dockerhub-username>/evilnginx:v1.0.0
```

### Update Makefile (Optional)

You can update the Makefile to pull images from Docker Hub instead of building locally:

```makefile
pull:
	docker pull <your-dockerhub-username>/evilnovnc:latest
	docker pull <your-dockerhub-username>/evilnginx:latest
	docker tag <your-dockerhub-username>/evilnovnc:latest evilnovnc
	docker tag <your-dockerhub-username>/evilnginx:latest evilnginx
```

## Monitoring Deployments

1. Go to the "Actions" tab in your GitHub repository
2. Click on "Publish Docker Images to Docker Hub" workflow
3. View the status and logs of each deployment

## Troubleshooting

### Authentication Failed

- Verify that `DOCKER_USERNAME` and `DOCKER_PASSWORD` secrets are correctly set
- Ensure the Docker Hub access token has Read & Write permissions
- Check that the access token hasn't expired

### Build Failed

- Check the workflow logs in the Actions tab
- Ensure the Dockerfiles are valid and all required files exist
- Verify that the base images specified in Dockerfiles are accessible

### Images Not Appearing on Docker Hub

- Confirm the workflow completed successfully
- Check your Docker Hub repositories page
- Verify the repository names match your username

## Security Notes

- Never commit Docker Hub credentials to the repository
- Use GitHub Secrets to store sensitive information
- Regularly rotate Docker Hub access tokens
- Use tokens with minimal required permissions

## Additional Resources

- [Docker Build Push Action Documentation](https://github.com/docker/build-push-action)
- [Docker Hub Documentation](https://docs.docker.com/docker-hub/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
