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

# Get organization name
read -p "GitHub organization name: " ORG_NAME
if [ -z "$ORG_NAME" ]; then
    echo "Error: Organization name is required"
    exit 1
fi

# Verify GitHub PAT and org access
echo -e "${YELLOW}Verifying GitHub credentials...${NC}"
VERIFY_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/orgs/$ORG_NAME")

if [ "$VERIFY_RESPONSE" = "404" ]; then
    echo -e "${RED}Error: Organization '$ORG_NAME' not found or no access${NC}"
    exit 1
elif [ "$VERIFY_RESPONSE" = "401" ]; then
    echo -e "${RED}Error: Invalid GitHub token${NC}"
    exit 1
elif [ "$VERIFY_RESPONSE" != "200" ]; then
    echo -e "${RED}Error: Unable to verify GitHub credentials (HTTP $VERIFY_RESPONSE)${NC}"
    exit 1
fi

# Verify admin:org scope
REG_TEST=$(curl -s -X POST \
    -H "Authorization: token $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github.v3+json" \
    "https://api.github.com/orgs/$ORG_NAME/actions/runners/registration-token" | jq -r .message)

if [ "$REG_TEST" = "Must have admin rights to Repository." ] || [ "$REG_TEST" = "Bad credentials" ]; then
    echo -e "${RED}Error: Token needs 'admin:org' scope to manage runners${NC}"
    echo "Please create a new token with the correct permissions"
    exit 1
fi

echo -e "${GREEN}✓ GitHub credentials verified${NC}"

# Choose size
echo ""
echo -e "${YELLOW}Choose your droplet size:${NC}"
echo "1) Micro - 1 CPU, 1GB RAM ($6/month) - 2 runners"
echo "2) Basic - 1 CPU, 2GB RAM ($12/month) - 3 runners"
echo "3) Standard - 2 CPU, 2GB RAM ($18/month) - 5 runners"
read -p "Enter choice [1-3]: " size_choice

case $size_choice in
    1) SIZE="s-1vcpu-1gb"; DESC="1 CPU, 1GB RAM"; RUNNERS=2 ;;
    2) SIZE="s-1vcpu-2gb"; DESC="1 CPU, 2GB RAM"; RUNNERS=3 ;;
    3) SIZE="s-2vcpu-2gb"; DESC="2 CPU, 2GB RAM"; RUNNERS=5 ;;
    *) SIZE="s-1vcpu-1gb"; DESC="1 CPU, 1GB RAM"; RUNNERS=2 ;;
esac

# Create cloud-init  
echo -e "${YELLOW}Creating configuration...${NC}"
TEMP_FILE="cloud-init-$$.yaml"
cat > "$TEMP_FILE" << EOF
#cloud-config
package_update: true

runcmd:
  - apt-get update
  - apt-get install -y docker.io docker-compose-v2 git
  - systemctl start docker
  - systemctl enable docker
  - git clone https://github.com/jahwag/digitalocean-github-runner /opt/runner
  - cd /opt/runner
  - |
    cat > .env << 'ENVEOF'
    GITHUB_TOKEN=${GITHUB_TOKEN}
    GITHUB_ORG=${ORG_NAME}
    ENVEOF
  - chmod +x start-runners.sh
  - ./start-runners.sh
EOF

# Deploy
echo ""
echo -e "${YELLOW}Deploying your runner...${NC}"
echo "• Size: $DESC"
echo "• Runners: $RUNNERS"
echo "• Region: Amsterdam"
echo "• Organization: $ORG_NAME"
echo ""

# Create SSH key if needed
SSH_KEY_NAME="github-runner-key"
if ! doctl compute ssh-key list --format Name --no-header | grep -q "$SSH_KEY_NAME"; then
    echo -e "${YELLOW}Creating SSH key...${NC}"
    ssh-keygen -t ed25519 -f /tmp/runner-key -N "" -q
    PUB_KEY=$(cat /tmp/runner-key.pub)
    SSH_KEY_ID=$(doctl compute ssh-key create "$SSH_KEY_NAME" --public-key "$PUB_KEY" --format ID --no-header)
    rm -f /tmp/runner-key /tmp/runner-key.pub
else
    SSH_KEY_ID=$(doctl compute ssh-key list --format ID,Name --no-header | grep "$SSH_KEY_NAME" | awk '{print $1}')
fi

DROPLET_ID=$(doctl compute droplet create github-runner-$(date +%s) \
    --region ams3 \
    --size "$SIZE" \
    --image ubuntu-24-04-x64 \
    --ssh-keys "$SSH_KEY_ID" \
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
echo -e "${BLUE}Your $RUNNERS runners will appear in 2-3 minutes at:${NC}"
echo "https://github.com/organizations/${ORG_NAME}/settings/actions/runners"
echo ""
echo -e "${YELLOW}Useful commands:${NC}"
echo "• SSH access: doctl compute ssh $DROPLET_NAME"
echo "• Check cloud-init: doctl compute ssh $DROPLET_NAME --ssh-command 'sudo cat /var/log/cloud-init-output.log'"
echo "• Check runners: doctl compute ssh $DROPLET_NAME --ssh-command 'cd /opt/runner && docker compose ps'"
echo "• View logs: doctl compute ssh $DROPLET_NAME --ssh-command 'cd /opt/runner && docker compose logs'"
echo "• Check .env: doctl compute ssh $DROPLET_NAME --ssh-command 'cat /opt/runner/.env'"
echo "• Delete droplet: doctl compute droplet delete $DROPLET_NAME"
echo ""