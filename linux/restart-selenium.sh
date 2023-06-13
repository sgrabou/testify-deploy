#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./config.sh
WORK_DIR=$(pwd)

PROGRAM=$(basename "$0")

cd ${DOCKER_DIR_CT}

echo
echo "Stopping Selenium and nodes..."
docker-compose -f docker-compose-prod.yml stop selenium-hub chrome firefox opera

echo
echo "Starting Selenium and nodes..."
docker-compose -f docker-compose-prod.yml up -d selenium-hub chrome firefox opera

echo
echo "Restarting NGINX Proxy..."
docker-compose -f docker-compose-prod.yml restart nginx

echo
echo "Selenium and nodes have been started successfully!"
