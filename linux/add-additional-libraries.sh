#!/usr/bin/env bash

#################################################################
#                                                               #
#        Simple script that moves a directory inside the        #
#             jenkins container at "/opt/testify/"               #
#                                                               #
#################################################################

PROGRAM=$(basename "$0")
source ./config.sh

# Usage documentation
usage() {
  echo
  echo "Usage: ${PROGRAM} [TESTIFY LIBRARY DIRECTORY]"
  echo
  echo "Example: ${PROGRAM} /opt/testify/libraries"
  echo
  exit 1
}

if [[ -z "$1" ]]; then
  usage
fi

if [[ ! -d "$1" ]]; then
  echo
  echo "The following directory does not exist: $1"
  echo
  exit 1
fi

echo
echo "Copying libraries from host to jenkins docker container..."
echo

docker exec ct-jenkins rm -rf /opt/testify/libraries/*

docker cp "$1" ct-jenkins:/opt/testify
