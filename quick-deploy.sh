#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${BLUE}╔══════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     GitHub Runner Quick Deploy Tool      ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════╝${NC}"
echo ""

# Check if doctl is installed
if ! command -v doctl &> /dev/null; then
    echo -e "${YELLOW}Installing DigitalOcean CLI...${NC}"
    if [[ "$OSTYPE" == "darwin"* ]]; then
        brew install doctl
    else
        snap install doctl || (cd ~ && wget https://github.com/digitalocean/doctl/releases/download/v1.104.0/doctl-1.104.0-linux-amd64.tar.gz && tar xf doctl-1.104.0-linux-amd64.tar.gz && sudo mv doctl /usr/local/bin)
    fi
fi

# Check if authenticated
if ! doctl auth whoami &> /dev/null 2>&1; then
    echo -e "${YELLOW}First, let's connect to DigitalOcean${NC}"
    echo "Get your token from: https://cloud.digitalocean.com/account/api/tokens"
    echo ""
    read -p "Paste your DigitalOcean API token: " DO_TOKEN
    doctl auth init -t "$DO_TOKEN"
    echo ""
fi

# Get GitHub PAT
echo -e "${YELLOW}Now let's set up your GitHub runner${NC}"
echo "Create a PAT at: https://github.com/settings/tokens"
echo "Required scope: admin:org"
echo ""
read -p "Paste your GitHub Personal Access Token: " GITHUB_TOKEN

# Choose size
echo ""
echo -e "${YELLOW}Choose your droplet size:${NC}"
echo "1) Small - 2GB RAM, 1 CPU ($12/month) - Basic builds"
echo "2) Medium - 4GB RAM, 2 CPU ($24/month) - Java/Docker builds"
echo "3) Large - 8GB RAM, 4 CPU ($48/month) - Heavy workloads"
read -p "Enter choice [1-3]: " size_choice

case $size_choice in
    1) SIZE="s-2vcpu-2gb"; DESC="2GB RAM" ;;
    2) SIZE="s-2vcpu-4gb"; DESC="4GB RAM" ;;
    3) SIZE="s-4vcpu-8gb"; DESC="8GB RAM" ;;
    *) SIZE="s-2vcpu-2gb"; DESC="2GB RAM" ;;
esac

# Get organization name
read -p "GitHub organization name (default: Bytelope): " ORG_NAME
ORG_NAME=${ORG_NAME:-Bytelope}

# Create cloud-init
echo -e "${YELLOW}Creating configuration...${NC}"
TEMP_FILE=$(mktemp)
cat > "$TEMP_FILE" << EOF
#cloud-config
runcmd:
  - curl -fsSL https://get.docker.com | sh
  - git clone https://github.com/jahwag/digitalocean-github-runner /opt/runner
  - cd /opt/runner
  - docker build -t runner .
  - |
    docker run -d --name runner --restart always \
      -e GITHUB_TOKEN=${GITHUB_TOKEN} \
      -e GITHUB_ORG=${ORG_NAME} \
      runner
EOF

# Deploy
echo ""
echo -e "${YELLOW}Deploying your runner...${NC}"
echo "• Size: $DESC"
echo "• Region: Amsterdam"
echo "• Organization: $ORG_NAME"
echo ""

DROPLET_ID=$(doctl compute droplet create github-runner-$(date +%s) \
    --region ams3 \
    --size "$SIZE" \
    --image ubuntu-24-04-x64 \
    --user-data-file "$TEMP_FILE" \
    --wait \
    --format ID \
    --no-header)

DROPLET_IP=$(doctl compute droplet get "$DROPLET_ID" --format PublicIPv4 --no-header)
DROPLET_NAME=$(doctl compute droplet get "$DROPLET_ID" --format Name --no-header)

# Cleanup
rm -f "$TEMP_FILE"

# Done!
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         ✅ Deployment Complete!          ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
echo ""
echo "Droplet Name: $DROPLET_NAME"
echo "IP Address: $DROPLET_IP"
echo "Monthly Cost: \$${SIZE:2:2}"
echo ""
echo -e "${BLUE}Your runner will appear in 2-3 minutes at:${NC}"
echo "https://github.com/organizations/${ORG_NAME}/settings/actions/runners"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "• Check status: doctl compute ssh $DROPLET_NAME --ssh-command 'docker logs runner'"
echo "• SSH access: doctl compute ssh $DROPLET_NAME"
echo "• Delete runner: doctl compute droplet delete $DROPLET_NAME"
echo ""