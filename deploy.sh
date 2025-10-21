#!/bin/bash


set -e  # Exit immediately on error
LOG_FILE="deploy_$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -i $LOG_FILE)
exec 2>&1

echo "... Collecting Deployment Parameters ..."

read -p "Enter Git repository URL: " REPO_URL
read -p "Enter GitHub Personal Access Token (PAT): " PAT
read -p "Enter branch name [default: main]: " BRANCH
BRANCH=${BRANCH:-main}

read -p "Enter remote server username (e.g., ubuntu): " REMOTE_USER
read -p "Enter remote server IP address: " SERVER_IP
read -p "Enter path to your SSH key (.pem): " SSH_KEY
read -p "Enter application port (container internal port): " APP_PORT

echo "All parameters successfully collected."

echo "... Cloning Repository ..."
REPO_DIR=$(basename "$REPO_URL" .git)

if [ -d "$REPO_DIR" ]; then
  echo "Repository already exists. Pulling latest changes..."
  cd "$REPO_DIR"
  git pull origin "$BRANCH"
else
  GIT_URL_WITH_TOKEN=${REPO_URL/https:\/\//https:\/\/$PAT@}
  git clone -b "$BRANCH" "$GIT_URL_WITH_TOKEN"
  cd "$REPO_DIR"
fi

# Check for Dockerfile or docker-compose.yml
if [ -f "Dockerfile" ] || [ -f "docker-compose.yml" ]; then
  echo "Docker configuration found."
else
  echo " No Dockerfile or docker-compose.yml found. Exiting."
  exit 1
fi

echo "....Connecting to Remote Server ($SERVER_IP) ..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$REMOTE_USER@$SERVER_IP" << 'EOF'
  set -e
  echo "Updating system and installing dependencies..."
  sudo apt update -y
  sudo apt install -y docker.io docker-compose nginx

  echo "Adding user to Docker group..."
  sudo usermod -aG docker $USER

  echo "Enabling and starting services..."
  sudo systemctl enable docker
  sudo systemctl enable nginx
  sudo systemctl start docker
  sudo systemctl start nginx

  echo "Docker version:"
  docker --version
EOF

echo "Remote environment setup complete."

echo "... Deploying Dockerized Application ..."

scp -i "$SSH_KEY" -r . "$REMOTE_USER@$SERVER_IP:/home/$REMOTE_USER/app"

ssh -i "$SSH_KEY" "$REMOTE_USER@$SERVER_IP" << 'EOF'
  cd ~/app
  if [ -f "docker-compose.yml" ]; then
    echo "Running docker-compose..."
    sudo docker-compose up -d --build
  else
    echo "Building and running Docker container..."
    sudo docker build -t stage1app .
    sudo docker run -d -p 5000:5000 stage1app
  fi
EOF

echo "Application deployed successfully."


echo "....Configuring Nginx as Reverse Proxy..."

ssh -i "$SSH_KEY" "$REMOTE_USER@$SERVER_IP" <<EOF
  sudo bash -c 'cat > /etc/nginx/sites-available/stage1app <<CONFIG
server {
    listen 80;
    server_name _;
    location / {
        proxy_pass http://localhost:$APP_PORT;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
CONFIG'

  sudo ln -sf /etc/nginx/sites-available/stage1app /etc/nginx/sites-enabled/
  sudo nginx -t && sudo systemctl reload nginx
EOF

echo "Nginx configured successfully."

echo "..Validating Deployment...."

ssh -i "$SSH_KEY" "$REMOTE_USER@$SERVER_IP" <<EOF
  sudo systemctl status docker | grep active
  sudo systemctl status nginx | grep active
  sudo docker ps
  curl -I localhost
EOF

echo "Deployment Validation Complete."
echo "Check your app at: http://$SERVER_IP"

git init
git add deploy.sh README.md
git commit -m "Stage 1 DevOps deployment script"
git remote add origin https://github.com/<username>/<repo>.git
git push -u origin main