# Vercel Deployment Notes

## Important Limitations

This application is **NOT fully compatible** with Vercel due to its architecture:

### What This Application Does:
- Runs Docker containers dynamically for each user session
- Uses nginx as a reverse proxy
- Manages VNC connections to browser instances
- Requires persistent container management
- Uses a Go server to orchestrate Docker operations

### Why It Can't Run on Vercel:
1. **No Docker Support**: Vercel does not support Docker or container orchestration
2. **No Long-Running Processes**: The application requires persistent containers, but Vercel only supports serverless functions (max 10-60 seconds)
3. **No VNC Support**: VNC connections require persistent WebSocket connections
4. **File System Limitations**: Vercel has read-only file systems except for /tmp

## What CAN Be Deployed to Vercel

The Vercel configuration in this repository will only serve the **static HTML/JS files** from the `Files` directory. This is essentially just the loading screen and will not function as intended since:
- The `/reso` endpoint (Go server) won't exist
- No Docker containers can be created
- No VNC sessions can be established

## Recommended Deployment Platforms

For this application to work properly, consider these alternatives:

### 1. **DigitalOcean App Platform** or **Google Cloud Run**
- Supports Docker containers
- Can run the full application

### 2. **AWS EC2** or **DigitalOcean Droplet**
- Full control over the environment
- Can install Docker and run the application as intended
- Follow the existing installation instructions in README.md

### 3. **Kubernetes Cluster** (GKE, EKS, AKS)
- For production-scale deployment
- Better container orchestration

## To Deploy on Vercel Anyway (Static Only)

If you still want to deploy the static files to Vercel:

```bash
# Install Vercel CLI
npm install -g vercel

# Deploy
vercel

# Or link to a project
vercel --prod
```

This will only serve the static HTML/JS files and **will not function** as a working application.

## Adapting for Vercel (Major Refactoring Required)

To make this work on Vercel, you would need to:

1. **Remove all Docker dependencies**
2. **Rewrite the Go server as Vercel serverless functions** (Go or Node.js)
3. **Remove VNC functionality** entirely (not supported)
4. **Redesign the application** without persistent connections
5. **Use external services** for any stateful operations

This would essentially be building a completely different application.

## Conclusion

While `vercel.json` has been added to this repository, **deploying this application to Vercel will not result in a functional system**. Please use a Docker-compatible hosting platform as described above.
