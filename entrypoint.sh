#!/bin/bash
set -e

# Ensure proper permissions for work directory
if [ -d "/home/runner/_work" ]; then
    sudo chown -R runner:runner /home/runner/_work
    chmod -R 755 /home/runner/_work
fi

# Create required directories with proper permissions
mkdir -p /home/runner/_work/_tool /home/runner/_work/_temp /home/runner/_work/_actions
chmod -R 755 /home/runner/_work

# Check required environment variables
if [ -z "${GITHUB_TOKEN}" ]; then
    echo "Error: GITHUB_TOKEN is required"
    exit 1
fi

if [ -z "${GITHUB_ORG}" ]; then
    echo "Error: GITHUB_ORG is required"  
    exit 1
fi

# Get registration token from GitHub API
echo "Getting registration token..."
REG_TOKEN=$(curl -s -X POST \
    -H "Authorization: token ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github.v3+json" \
    https://api.github.com/orgs/${GITHUB_ORG}/actions/runners/registration-token | jq -r .token)

if [ "$REG_TOKEN" == "null" ]; then
    echo "Failed to get registration token. Check your GITHUB_TOKEN permissions."
    exit 1
fi

# Configure the runner
echo "Configuring runner..."
./config.sh \
    --url "https://github.com/${GITHUB_ORG}" \
    --token "${REG_TOKEN}" \
    --name "${RUNNER_NAME:-$(hostname)}" \
    --labels "${RUNNER_LABELS:-self-hosted,Linux,X64}" \
    --unattended \
    --replace

# Cleanup function
cleanup() {
    echo "Removing runner..."
    ./config.sh remove --token "${REG_TOKEN}" || true
}

# Trap exit signals
trap cleanup EXIT INT TERM

# Start the runner
echo "Starting runner..."
./run.sh