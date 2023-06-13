#!/usr/bin/env bash

####################################################################
#                                                                  #
#      This script removes the internal proxy config volume.       #
#                                                                  #
####################################################################

MOUNT_POINT_INTERNAL_PROXY_CONFIG="/var/lib/docker/volumes/internal-proxy-config"
VOLUME_NAME="internal-proxy-config"

if ! [[ -d ${MOUNT_POINT_INTERNAL_PROXY_CONFIG} ]]; then
  echo
  echo "WARNING: Internal proxy config volume does not exist, maybe the temporary script could be removed?"
  echo
else
  echo "Removing internal proxy config volume: ${MOUNT_POINT_INTERNAL_PROXY_CONFIG}"
  docker volume rm --force ${VOLUME_NAME} >/dev/null 2>&1 && echo "Deleted volume ${VOLUME_NAME}" || echo "Volume ${VOLUME_NAME} already deleted..."
  rm -rf ${MOUNT_POINT_INTERNAL_PROXY_CONFIG}
fi
