#!/usr/bin/env bash

####################################################################
#                                                                  #
#       Utility File to Load Docker image from tar ball            #
#                                                                  #
####################################################################

source ./config.sh

if [[ -z "$1" ]]; then
  echo
  echo "Docker images tar ball must be specified , example:"
  echo "   sudo ./load-image-from-tarball.sh ./testify-ct-2.5.0-images.tar.gz"
  echo
  exit 1
fi

if [[ -f $1 ]]; then

  echo
  echo "Loading $1 images from file..."
  echo
  docker load -i "$1"

else
  echo
  echo "The following tar file has not been found: $1"

fi

echo
