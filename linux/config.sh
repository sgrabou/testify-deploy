#!/usr/bin/env bash

# CHECK IF THE USER IS ROOT / SUDO
# In config file since most the script use this file and they must be executed as root
if [[ $EUID -ne 0 ]]; then
  echo
  echo "This script must be run as root or with sudo."
  echo
  exit 1
fi

set -e

# Testify paths
TESTIFY_HOME=/opt/testify
TESTIFY_LIBRARIES_DIRECTORY=${TESTIFY_HOME}/libraries
DOCKER_DIR=${TESTIFY_HOME}/docker
DOCKER_DIR_EXTERNAL_PROXY=${DOCKER_DIR}/external-proxy
DOCKER_DIR_CT=${DOCKER_DIR}/ct
BACKUP_ROOT=${TESTIFY_HOME}/backups-directory
DEFAULT_BACKUP_ROOT=${BACKUP_ROOT}

# Testify updater script path
UPDATER_DIR=${TESTIFY_HOME}/testify-updater
INSTALLATION_DOCKER_DIRECTORY=${UPDATER_DIR}/docker-installation
TESTIFY_IMAGE_DEFAULT_PATH=${UPDATER_DIR}/testifyImages.tar.gz

# Services
SERVICES_DIR=${UPDATER_DIR}/services
SYSTEM_D="/etc/systemd/system/"

# Testify Docker volume names
FILE_SERVER_VOLUME="testify-file-server"
LIBDOC_VOLUME="testify-libdoc"
JENKINS_EXTRA_LIB_INSTALLATION_DATA_VOLUME="jenkins-robot-extra-libraries-installation-data"
KEYCLOAK_DB_VOLUME="keycloak-database"
POSTGRES_DB_VOLUME="postgres-database"
TESTIFY_LIBRARY_PROPERTIES_VOLUME="springboot-testify-extra-librarie-properties-file"
TESTIFY_LICENSES_VOLUME="testify-licenses"
INTERNAL_PROXY_CERT="internal-proxy-cert"
JENKINS_CONFIG_VOLUME="jenkins-config"

TESTIFY_DOCKER_VOLUMES=(${LIBDOC_VOLUME} ${POSTGRES_DB_VOLUME} ${KEYCLOAK_DB_VOLUME} ${FILE_SERVER_VOLUME} ${TESTIFY_LIBRARY_PROPERTIES_VOLUME} ${JENKINS_EXTRA_LIB_INSTALLATION_DATA_VOLUME} ${TESTIFY_LICENSES_VOLUME} ${INTERNAL_PROXY_CERT} ${JENKINS_CONFIG_VOLUME})

BASE_MOUNT_POINT="/var/lib/docker/volumes"
DATA_MOUNT_POINT="_data"

# All Docker volume Mount Point on the host
MOUNT_POINT_FILE_SERVER=${BASE_MOUNT_POINT}/${FILE_SERVER_VOLUME}/${DATA_MOUNT_POINT}
MOUNT_POINT_LIBDOC=${BASE_MOUNT_POINT}/${LIBDOC_VOLUME}/${DATA_MOUNT_POINT}
MOUNT_POINT_JENKINS_EXTRA_LIB_INSTALLATION_DATA=${BASE_MOUNT_POINT}/${JENKINS_EXTRA_LIB_INSTALLATION_DATA_VOLUME}/${DATA_MOUNT_POINT}
MOUNT_POINT_KEYCLOAK_DB=${BASE_MOUNT_POINT}/${KEYCLOAK_DB_VOLUME}/${DATA_MOUNT_POINT}
MOUNT_POINT_POSTGRES_DB=${BASE_MOUNT_POINT}/${POSTGRES_DB_VOLUME}/${DATA_MOUNT_POINT}
MOUNT_POINT_LIBRARY_PROPERTIES_FILE=${BASE_MOUNT_POINT}/${TESTIFY_LIBRARY_PROPERTIES_VOLUME}/${DATA_MOUNT_POINT}
MOUNT_POINT_TESTIFY_LICENSES=${BASE_MOUNT_POINT}/${TESTIFY_LICENSES_VOLUME}/${DATA_MOUNT_POINT}
MOUNT_POINT_INTERNAL_PROXY_CERT=${BASE_MOUNT_POINT}/${INTERNAL_PROXY_CERT}/${DATA_MOUNT_POINT}
MOUNT_POINT_JENKINS_CONFIG=${BASE_MOUNT_POINT}/${JENKINS_CONFIG_VOLUME}/${DATA_MOUNT_POINT}

# Backup file name
BACKUP_POSTGRES_NAME="postgres.bin"
BACKUP_KEYCLOAK_NAME="keycloak.bckp.tar.gz"
BACKUP_FILE_SERVER_NAME="file-server.bckp.tar.gz"
BACKUP_LICENSES_NAME="licenses.bckp.tar.gz"
BACKUP_SSL_CERT_NAME="ssl-cert.bckp.tar.gz"
BACKUP_JENKINS_CONFIG_NAME="jenkins-config.bckp.tar.gz"

CONTAINER_NAME_INTERNAL_PROXY="ct-internal-proxy"

# Docker Images name identifier
TESTIFY_CT_IMAGES=("ct-springboot" "ct-jenkins" "ct-postgres" "ct-keycloak" ${CONTAINER_NAME_INTERNAL_PROXY} "ct-vault")

TESTIFY_TEST_URL=http://127.0.0.1/testify/
HTTP_RESPONSE="HTTP/1.1 200"
HTTP_RESPONSE="HTTP/1.1 200"

# General max wait count until task is considered to have failed
MAX_WAIT_COUNT=80

# Check if backup folder is mounted and if so add hostname for directory
# Space after variable is NOT a mistake
if grep -qs "${DEFAULT_BACKUP_ROOT} " /proc/mounts; then
  BACKUP_ROOT=${BACKUP_ROOT}/$(hostname)
fi

# Error method
err() {
  echo "$@" >&2
}

# Validate Return Code
validateReturnCode() {

  if [[ $? -ne 0 ]]; then
    echo "An unexpected error has occurred!"
    exit 1
  fi
}

# Wait for server to response, exit with error `code 1` if it could
# not access the server after 20 tries (approx 3 min)
waitForServer() {

  waitCount=0

  while true; do
    SERVER_RESPONSE=$(curl -Is ${TESTIFY_TEST_URL} | head -1 | xargs)

    if [[ "$SERVER_RESPONSE" == "$HTTP_RESPONSE" ]]; then
      break
    elif [[ ${waitCount} -gt ${MAX_WAIT_COUNT} ]]; then
      err "Server could not be accessed !"
      exit 1
    else
      echo "Server not ready, waiting..."
      waitCount=$((${waitCount} + 1))
      sleep 15
    fi
  done
}

# Iterate through the list of name (volumes name) in the defined array
# and deletes all of them.
deleteTestifyDockerVolumes() {

  echo
  echo "Removing Testify Docker volumes..."

  for volumeName in ${TESTIFY_DOCKER_VOLUMES[@]}; do
    docker volume rm ${volumeName} >/dev/null 2>&1 && echo "Deleted volume ${volumeName}" || echo "Volume ${volumeName} already deleted..."
  done
}

deleteTestifyImage() {

  echo "Looping to stop and remove Testify containers and images..."
  for imageName in ${TESTIFY_CT_IMAGES[@]}; do

    docker ps -a | grep ${imageName} | awk '{print $1}' | xargs docker stop >/dev/null 2>&1 && echo "Stopped every testify container" || echo "No Testify container found to stop..."

    docker ps -a | grep ${imageName} | awk '{print $1}' | xargs docker rm >/dev/null 2>&1 && echo "Removed every testify container" || echo "No Testify container found to remove..."

    docker images -a | grep ${imageName} | awk '{print $3}' | xargs docker rmi >/dev/null 2>&1 && echo "Removed every testify images" || echo "No Testify image found to remove..."
  done
}

# Stop and remove every container/images related to testify
deleteTestifyDockerRelatedData() {
  deleteTestifyImage
  deleteTestifyDockerVolumes
  docker system prune -a --volumes -f >/dev/null 2>&1
}
