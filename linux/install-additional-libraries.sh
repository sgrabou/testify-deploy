#!/usr/bin/env bash

######################################################################
#                                                                    #
#        Very basic script that start the installation script        #
#                     from the jenkins containers                    #
#                The package to install must already be              #
#                          in the container                          #
#                                                                    #
######################################################################

source ./config.sh

echo
echo "Installing libraries inside jenkins' container..."
echo

docker exec ct-jenkins /install-libraries.sh
