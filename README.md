# hng13-stage1-devops
Automates full Docker + Nginx app deployment to AWS EC2 with a single Bash script

#Stage 1 DevOps Deployment Script

This repo contains a Bash automation script (`deploy.sh`) that handles full app deployment on a remote Ubuntu server using Docker and Nginx

# What It Does
- Connects to your EC2 instance via SSH  
- Installs Docker, Nginx, and updates packages  
- Clones your GitHub repo and builds containers  
- Sets up Nginx as a reverse proxy on port 80  
- Verifies that your app is running and accessible  

Author

Igbinosa Osarumen Wisdom (Rurutech)
DevOps | IT Solutions | Business Operations
Building simple, powerful tools for smarter automation.
