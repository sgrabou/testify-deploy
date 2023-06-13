#!/usr/bin/env bash

####################################################################
#                                                                  #
#             Script to roll back to a previous backup             #
#       The backup does not need to be of the same version         #
#                                                                  #
####################################################################

WORK_DIR=$(pwd)

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./config.sh

PROGRAM=$(basename "$0")

usage() {
  echo "Usage: ${PROGRAM} -b backupPath"
  echo "  -b, --backup, -p, --path backupPath"
  echo "       Specify the path of the backup to rollback to (mandatory). Must be an absolute path"
  echo "  -i, --images [pathToImagesArchive]"
  echo "       Specify file to use to load testify images"
  echo
  exit 1
}

# Loop through parameter given to the script
while [[ -n "$1" ]]; do

  case "$1" in
  -b | --backup | -p | --path)
    if [[ -z "$2" ]] || [[ $2 == "-*" ]]; then
      echo
      echo "No backup path was given"
      echo
      usage
    fi
    BACKUP_TO_LOAD="$2"
    # Check if the path is absolute (start with a /)
    if [ "${BACKUP_TO_LOAD:0:1}" = "/" ]; then
      echo
      echo "Using ${BACKUP_TO_LOAD} to rollback"
      echo
    else
      echo "You must use an absolute path for the backup"
      exit 1
    fi
    shift 2
    ;;
  -i | --images)
    if [[ -z "$2" ]] || [[ $2 == "-*" ]]; then
      echo
      echo "No file specified for the testify images archive"
      echo
      usage
    fi
    TESTIFY_IMAGE_PATH="$2"

    if ! [[ -f ${TESTIFY_IMAGE_PATH} ]]; then
      echo
      echo "The image path did not point to a file, aborting..."
      echo
      exit 1
    fi

    shift 2
    ;;
  *)
    echo "Unexpected parameter"
    usage #Unexpected parameter was given, print usage.
    ;;
  esac

done

if [[ -z ${BACKUP_TO_LOAD} ]]; then
  echo
  echo "No backup was specified to use to rollback"
  echo
  usage
fi

# Retrieving current docker tag
if [[ -f ${DOCKER_DIR_CT}/.env ]]; then
  CURRENT_INSTALL_VERSION_TAG=$(sed -n '/TESTIFY_DOCKER_TAG/ s/.*\= *//p' ${DOCKER_DIR_CT}/.env)
  if [[ -z ${CURRENT_INSTALL_VERSION_TAG} ]]; then
    err "Unable to retrieve docker tag from ${DOCKER_DIR_CT}/.env, aborting..."
    err ""
    exit 1
  fi
else
  echo "No previous testify docker information were found, will install version from scratch and load backup."
  echo
fi

# Retrieving rollback version
if [[ -f ${BACKUP_TO_LOAD}/docker/ct/.env ]]; then
  ROLLBACK_INSTALL_VERSION_TAG=$(sed -n '/TESTIFY_DOCKER_TAG/ s/.*\= *//p' ${BACKUP_TO_LOAD}/docker/ct/.env)
  if [[ -z ${ROLLBACK_INSTALL_VERSION_TAG} ]]; then
    err "Unable to retrieve docker tag from ${BACKUP_TO_LOAD}/docker/.env, aborting..."
    err ""
    exit 1
  fi
else
  err "No rollback docker information were found, aborting..."
  err ""
  exit 1
fi

# Stop testify process
echo
echo "Trying to stop testify containers..."
echo
cd ${DOCKER_DIR_CT}
docker-compose -f docker-compose-prod.yml stop
cd ..

# Confirming if the current version of testify is correct, if not install the needed version
if [[ ${CURRENT_INSTALL_VERSION_TAG} != ${ROLLBACK_INSTALL_VERSION_TAG} ]]; then

  echo
  echo "Missmatch in rollback and current version of testify"
  echo "Upgrading/installing rollback version of testify."
  echo

  if [[ "${TESTIFY_IMAGE_PATH}" ]]; then
    ${UPDATER_DIR}/update.sh -t ${ROLLBACK_INSTALL_VERSION_TAG} -i ${TESTIFY_IMAGE_PATH} --rollback
  else
    ${UPDATER_DIR}/update.sh -t ${ROLLBACK_INSTALL_VERSION_TAG} --rollback
  fi

else

  echo
  echo "Current installed version and rollback version are the same."
  echo "No change will be made to the installed testify instance."
  echo

fi

# Restore PostgreSQL Database
if [[ -f ${BACKUP_TO_LOAD}/backup/${BACKUP_POSTGRES_NAME} ]]; then

  echo "Starting PostgreSQL container..."
  cd ${DOCKER_DIR_CT}
  docker-compose -f docker-compose-prod.yml up -d postgres
  echo "Waiting PostgreSQL container..."
  sleep 20

  echo
  ${UPDATER_DIR}/restore-database-dump.sh -f ${BACKUP_TO_LOAD}/backup/${BACKUP_POSTGRES_NAME} --do-not-restart-springboot
  docker-compose -f docker-compose-prod.yml stop postgres
fi

# Restore Keycloak Database
if [[ -f ${BACKUP_TO_LOAD}/backup/${BACKUP_KEYCLOAK_NAME} ]]; then
  rm -rf ${MOUNT_POINT_KEYCLOAK_DB}/*
  echo
  echo "Restoring Keycloak configuration..."
  tar -xzf "${BACKUP_TO_LOAD}/backup/${BACKUP_KEYCLOAK_NAME}" -C /
  validateReturnCode
  echo "Keycloak configuration restored!"
fi

# Restore File Server
if [[ -f ${BACKUP_TO_LOAD}/backup/${BACKUP_FILE_SERVER_NAME} ]]; then
  rm -rf ${MOUNT_POINT_FILE_SERVER}/*
  echo
  echo "Restoring File Server..."
  tar -xzf "${BACKUP_TO_LOAD}/backup/${BACKUP_FILE_SERVER_NAME}" -C /
  validateReturnCode
  echo "File Server restored!"
fi

# Restore Licenses
if [[ -f ${BACKUP_TO_LOAD}/backup/${BACKUP_LICENSES_NAME} ]]; then
  rm -rf ${MOUNT_POINT_TESTIFY_LICENSES}/*
  echo
  echo "Restoring Licenses..."
  tar -xzf "${BACKUP_TO_LOAD}/backup/${BACKUP_LICENSES_NAME}" -C /
  validateReturnCode
  echo "Licenses restored!"
fi

# Restore Ssl certificates
if [[ -f ${BACKUP_TO_LOAD}/backup/${BACKUP_SSL_CERT_NAME} ]]; then
  rm -rf ${MOUNT_POINT_INTERNAL_PROXY_CERT}/*
  echo
  echo "Restoring ssl certificate files..."
  tar -xzf "${BACKUP_TO_LOAD}/backup/${BACKUP_SSL_CERT_NAME}" -C /
  validateReturnCode
  echo "Ssl certificate files restored!"
fi

# Restore Jenkins config
if [[ -f ${BACKUP_TO_LOAD}/backup/${BACKUP_JENKINS_CONFIG_NAME} ]]; then
  rm -rf ${MOUNT_POINT_JENKINS_CONFIG}/*
  echo
  echo "Restoring Jenkins config files..."
  tar -xzf "${BACKUP_TO_LOAD}/backup/${BACKUP_JENKINS_CONFIG_NAME}" -C /
  validateReturnCode
  echo "Jenkins config files restored!"
fi

# Restarting testify container
echo
echo "Restart testify containers..."
echo
cd ${DOCKER_DIR_CT}
docker-compose -f docker-compose-prod.yml up -d

echo
waitForServer

echo
echo "Testify rollback has been completed."
echo
