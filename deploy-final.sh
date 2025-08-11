#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}GitHub Runner Deploy${NC}"
echo "===================="

# Get inputs
read -sp "GitHub PAT: " GITHUB_TOKEN
echo ""
read -p "GitHub Org (default: Bytelope): " ORG
ORG=${ORG:-Bytelope}

# Create SSH key for access
SSH_KEY="/tmp/runner-key-$$"
ssh-keygen -t ed25519 -f "$SSH_KEY" -N "" -q

# Upload key to DO
KEY_ID=$(doctl compute ssh-key create runner-key-$$ --public-key-file "${SSH_KEY}.pub" --format ID --no-header)

# Create init script that bypasses password
cat > /tmp/init.sh << 'EOF'
#!/bin/bash
# Disable password expiry completely
sed -i 's/^PASS_MAX_DAYS.*/PASS_MAX_DAYS 99999/' /etc/login.defs
passwd -d root
chage -M 99999 root

# Install Docker
curl -fsSL https://get.docker.com | sh

# Setup runner
git clone https://github.com/jahwag/digitalocean-github-runner /opt/runner
cd /opt/runner
docker build -t runner .
docker run -d --name runner --restart always \
  -e GITHUB_TOKEN=__TOKEN__ \
  -e GITHUB_ORG=__ORG__ \
  runner
EOF

# Replace placeholders
sed -i "s/__TOKEN__/${GITHUB_TOKEN}/" /tmp/init.sh
sed -i "s/__ORG__/${ORG}/" /tmp/init.sh

# Create droplet
echo -e "${YELLOW}Creating droplet...${NC}"
DROPLET_ID=$(doctl compute droplet create github-runner-$(date +%s) \
    --region ams3 \
    --size s-1vcpu-2gb \
    --image debian-12-x64 \
    --ssh-keys "$KEY_ID" \
    --user-data-file /tmp/init.sh \
    --wait \
    --format ID \
    --no-header)

DROPLET_IP=$(doctl compute droplet get "$DROPLET_ID" --format PublicIPv4 --no-header)

# Wait and check
echo "Waiting for setup..."
sleep 30

# Check status via SSH
ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" root@"$DROPLET_IP" "docker ps"

# Cleanup
rm -f /tmp/init.sh "$SSH_KEY" "${SSH_KEY}.pub"
doctl compute ssh-key delete "$KEY_ID" -f

echo -e "${GREEN}✅ Done!${NC}"
echo "IP: $DROPLET_IP"
echo "Check: https://github.com/organizations/${ORG}/settings/actions/runners"