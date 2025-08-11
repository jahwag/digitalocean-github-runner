#!/bin/bash
set -e

echo "GitHub Runner - One Click Deploy"
echo "================================"
echo ""
echo "This will create a $12/month runner on DigitalOcean"
echo ""

# Get token
read -sp "Enter your GitHub PAT: " TOKEN
echo ""

# Create droplet with inline script
doctl compute droplet create runner-$(date +%s) \
  --size s-1vcpu-2gb \
  --image docker-20-04 \
  --region ams3 \
  --user-data "#!/bin/bash
docker run -d --restart always \
  --name runner \
  myoung34/github-runner:latest \
  -e RUNNER_NAME=do-runner \
  -e RUNNER_TOKEN=$TOKEN \
  -e RUNNER_ORGANIZATION=Bytelope" \
  --wait

echo "✅ Done! Check https://github.com/organizations/Bytelope/settings/actions/runners"