#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

clear
echo -e "${BLUE}GitHub Runner - Simple Deploy${NC}"
echo "=============================="
echo ""

# Check doctl
if ! command -v doctl &> /dev/null; then
    echo -e "${RED}Error: doctl not found${NC}"
    echo "Install: brew install doctl (Mac) or snap install doctl (Linux)"
    exit 1
fi

# Get inputs
read -sp "GitHub PAT: " GITHUB_TOKEN
echo ""
read -p "GitHub Org (default: Bytelope): " ORG_NAME
ORG_NAME=${ORG_NAME:-Bytelope}

# Choose size
echo ""
echo "Choose size:"
echo "1) $12/month (2GB RAM, 1 CPU)"
echo "2) $24/month (4GB RAM, 2 CPU)"
read -p "Choice [1-2]: " choice
SIZE=${choice:-1}
SIZE_SLUG=$([[ $SIZE == "2" ]] && echo "s-2vcpu-4gb" || echo "s-1vcpu-2gb")

# Generate random password to bypass the issue
RANDOM_PASS=$(openssl rand -base64 32)

# Create simple startup script
cat > startup.sh << 'SCRIPT'
#!/bin/bash
curl -fsSL https://get.docker.com | sh
git clone https://github.com/jahwag/digitalocean-github-runner /opt/runner
cd /opt/runner
docker build -t runner .
docker run -d --name runner --restart always \
  -e GITHUB_TOKEN=TOKEN_PLACEHOLDER \
  -e GITHUB_ORG=ORG_PLACEHOLDER \
  runner
SCRIPT

# Replace placeholders
sed -i "s/TOKEN_PLACEHOLDER/${GITHUB_TOKEN}/" startup.sh
sed -i "s/ORG_PLACEHOLDER/${ORG_NAME}/" startup.sh

# Encode script for user data
SCRIPT_B64=$(base64 -w0 startup.sh)

# Create droplet with password set
echo -e "${YELLOW}Creating droplet...${NC}"
DROPLET_ID=$(doctl compute droplet create github-runner-$(date +%s) \
    --region ams3 \
    --size "$SIZE_SLUG" \
    --image ubuntu-20-04-x64 \
    --user-data "#!/bin/bash
echo 'root:${RANDOM_PASS}' | chpasswd
echo '${SCRIPT_B64}' | base64 -d > /root/setup.sh
chmod +x /root/setup.sh
nohup /root/setup.sh > /root/setup.log 2>&1 &" \
    --wait \
    --format ID \
    --no-header)

# Get info
DROPLET_IP=$(doctl compute droplet get "$DROPLET_ID" --format PublicIPv4 --no-header)
DROPLET_NAME=$(doctl compute droplet get "$DROPLET_ID" --format Name --no-header)

# Cleanup
rm -f startup.sh

echo ""
echo -e "${GREEN}✅ Deployed!${NC}"
echo "============"
echo "Droplet: $DROPLET_NAME"
echo "IP: $DROPLET_IP"
echo ""
echo "Runner will appear in 3-5 minutes at:"
echo "https://github.com/organizations/${ORG_NAME}/settings/actions/runners"