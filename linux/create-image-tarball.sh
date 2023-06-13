#!/usr/bin/env bash

#
# Pull the docker image for testify and create a tarball with them.
# Will also pull the images related to the docker node
#

set -e

PROGRAM=$(basename "$0")
WORK_DIR=$(pwd)

err() {
  echo "$@" >&2
}

# CHECK IF THE USER IS ROOT / SUDO
if [[ $EUID -ne 0 ]]; then
  err ""
  err "This script must be run as root or with sudo."
  err ""
  exit 1
fi

usage() {
  echo "Usage: ${PROGRAM} dockerTag"
  echo "    dockerTag"
  echo "       Specify the docker tag to install (mandatory)"
  echo
  exit 1
}

if ! [[ -z $2 ]]; then
  err ""
  err "Too many arguments"
  err ""
  usage
fi

if [[ -z $1 ]]; then
  err ""
  err "Must give a docker tag..."
  err ""
  usage
fi

DOCKER_TAG=$1

echo
echo Pulling Testify Images...
docker pull artifactory.testify.com:6556/ct-vault:${DOCKER_TAG}
docker pull artifactory.testify.com:6556/ct-springboot:${DOCKER_TAG}
docker pull artifactory.testify.com:6556/ct-postgres:${DOCKER_TAG}
docker pull artifactory.testify.com:6556/ct-keycloak:${DOCKER_TAG}
docker pull artifactory.testify.com:6556/ct-jenkins:${DOCKER_TAG}
docker pull artifactory.testify.com:6556/ct-internal-proxy:${DOCKER_TAG}
docker pull artifactory.testify.com:6556/ct-external-proxy:${DOCKER_TAG}

echo
echo Pulling Selnium Images...
docker pull selenium/hub
docker pull selenium/node-chrome
docker pull selenium/node-firefox
docker pull selenium/node-opera

echo
echo Compressing images as tar file, this process takes several minutes...
docker save -o testify-ct-$1-images.tar.gz \
  artifactory.testify.com:6556/ct-vault:${DOCKER_TAG} \
  artifactory.testify.com:6556/ct-springboot:${DOCKER_TAG} \
  artifactory.testify.com:6556/ct-postgres:${DOCKER_TAG} \
  artifactory.testify.com:6556/ct-keycloak:${DOCKER_TAG} \
  artifactory.testify.com:6556/ct-jenkins:${DOCKER_TAG} \
  artifactory.testify.com:6556/ct-internal-proxy:${DOCKER_TAG} \
  artifactory.testify.com:6556/ct-external-proxy:${DOCKER_TAG} \
  selenium/hub \
  selenium/node-chrome \
  selenium/node-firefox \
  selenium/node-opera

echo
echo Process completed, the following file has been created: testify-ct-$1-images.tar.gz
echo
echo
