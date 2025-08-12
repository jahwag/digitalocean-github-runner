#!/bin/bash

echo "Stopping all runners..."

if [ -f docker-compose.override.yml ]; then
    docker compose -f docker-compose.yml -f docker-compose.override.yml down
    rm -f docker-compose.override.yml
    echo "All runners stopped and configuration cleaned up."
else
    docker compose down
    echo "All runners stopped."
fi