#!/usr/bin/env bash

######################################################################
#                                                                    #
#     Script that creates the needed volume for Testify            #
#                                                                    #
######################################################################

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./config.sh

echo
echo "Creating docker volumes..."
echo

for volumeName in ${TESTIFY_DOCKER_VOLUMES[@]}; do
  docker volume create --name ${volumeName}
done
