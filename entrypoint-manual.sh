#!/bin/bash
set -e

# Check for registration token passed directly
if [ -z "${REG_TOKEN}" ]; then
    echo "Error: REG_TOKEN is required"
    echo "Get one from: https://github.com/organizations/Bytelope/settings/actions/runners/new"
    exit 1
fi

# Configure the runner with the provided token
echo "Configuring runner..."
./config.sh \
    --url "https://github.com/${GITHUB_ORG:-Bytelope}" \
    --token "${REG_TOKEN}" \
    --name "${RUNNER_NAME:-$(hostname)}" \
    --labels "${RUNNER_LABELS:-self-hosted,Linux,X64}" \
    --unattended \
    --replace

# Note: Can't deregister on exit without a PAT
# The runner will show as "offline" when container stops

# Start the runner
echo "Starting runner..."
./run.sh