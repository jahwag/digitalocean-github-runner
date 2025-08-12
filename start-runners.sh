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

# Start runners with unique names
for i in $(seq 1 $TOTAL_RUNNERS); do
    echo "Starting runner $i of $TOTAL_RUNNERS..."
    RUNNER_NUMBER=$i docker compose up -d --scale runner=$i
done

echo ""
echo "All $TOTAL_RUNNERS runners started successfully!"
echo "They will appear in your GitHub organization settings in 1-2 minutes."
echo ""
echo "Commands:"
echo "  docker compose ps          # Check status"
echo "  docker compose logs         # View logs"
echo "  docker compose down         # Stop all runners"