#!/bin/bash
set -e

# Detect number of CPU cores
CPU_CORES=$(nproc)
RUNNERS_PER_CORE=3
TOTAL_RUNNERS=$((CPU_CORES * RUNNERS_PER_CORE))

echo "Detected $CPU_CORES CPU cores"
echo "Starting $TOTAL_RUNNERS runners (${RUNNERS_PER_CORE} per core)..."

# Check for required environment variables
if [ ! -f .env ]; then
    echo "Error: .env file not found"
    exit 1
fi

# Load environment variables
export $(cat .env | grep -v '^#' | xargs)

# Get hostname for unique naming
HOSTNAME=$(hostname)

# Create a docker-compose override file with unique runner configurations
cat > docker-compose.override.yml << EOF
version: '3.8'

services:
EOF

# Generate service definitions for each runner
for i in $(seq 1 $TOTAL_RUNNERS); do
    cat >> docker-compose.override.yml << EOF
  runner-$i:
    build: .
    container_name: github-runner-$i
    environment:
      - GITHUB_TOKEN=\${GITHUB_TOKEN}
      - GITHUB_ORG=\${GITHUB_ORG}
      - RUNNER_NAME=${HOSTNAME}-runner-$i
      - RUNNER_LABELS=self-hosted,Linux,X64,docker
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    restart: unless-stopped
    networks:
      - runner-network

EOF
done

# Add networks section
cat >> docker-compose.override.yml << EOF

networks:
  runner-network:
    driver: bridge
EOF

# Start all runners
echo "Starting runners..."
docker compose -f docker-compose.yml -f docker-compose.override.yml up -d --build

echo ""
echo "All $TOTAL_RUNNERS runners started successfully!"
echo "They will appear in your GitHub organization settings in 1-2 minutes."
echo ""
echo "Runner names:"
for i in $(seq 1 $TOTAL_RUNNERS); do
    echo "  - ${HOSTNAME}-runner-$i"
done
echo ""
echo "Commands:"
echo "  docker compose -f docker-compose.yml -f docker-compose.override.yml ps"
echo "  docker compose -f docker-compose.yml -f docker-compose.override.yml logs"
echo "  docker compose -f docker-compose.yml -f docker-compose.override.yml down"