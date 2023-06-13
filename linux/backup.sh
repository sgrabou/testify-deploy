#!/usr/bin/env bash

########################################################################
#                                                                      #
#                     Script that creates a backup                     #
#                                                                      #
########################################################################

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./config.sh

PROGRAM=$(basename "$0")

BACKUP_DIR=${BACKUP_ROOT}/backup-$(date +'%Y_%m_%d_%H_%M_%S')

SKIP_FILE_SERVER_BACKUP=false

# Usage documentation
usage() {
  echo "Usage: ${PROGRAM} -t dockerTag [--skipFileServerBackup] [pathOfBackup]"
  echo "  -t|--tag dockerTag   Specify the version/tag to install"
  echo "  [--skipFileServerBackup] To skip the file server backup"
  echo "  [pathOfBackup] Optional directory for storing backup"
  echo
  exit 1
}

# Loop through parameter given to the script
while [[ -n "$1" ]]; do

  case "$1" in
  -t | --tag)
    if [[ -z "$2" ]] || [[ $2 == "-*" ]]; then
      echo
      echo "No docker tag was given"
      echo
      usage
    fi
    VERSION_TAG="$2"
    echo
    echo "Using tag : ${VERSION_TAG}"
    echo
    shift 2
    ;;
  --skipFileServerBackup)
    SKIP_FILE_SERVER_BACKUP=true
    echo
    echo "File server backup ignored"
    echo
    shift
    ;;
  *)
    if [[ -n "$2" ]]; then
      usage
    fi
    BACKUP_DIR="$1"
    shift
    ;;
  esac

done

if [[ -z ${VERSION_TAG} ]]; then
  echo
  echo "No docker tag was specified"
  echo "Trying to retrieve docker tag from potential docker directory"
  echo

  if [[ -f "${DOCKER_DIR_CT}/.env" ]]; then
    CURRENT_INSTALL_VERSION_TAG=$(sed -n '/TESTIFY_DOCKER_TAG/ s/.*\= *//p' ${DOCKER_DIR_CT}/.env)
    if [[ -z ${CURRENT_INSTALL_VERSION_TAG} ]]; then
      echo "Unable to retrieve docker tag from ${DOCKER_DIR_CT}/.env, aborting..."
      echo
      exit 1
    fi
    VERSION_TAG="${CURRENT_INSTALL_VERSION_TAG}"
  else
    err "No previous testify docker information were found, aborting..."
    err ""
    exit 1
  fi
fi

# If the backup folder does not already exist, create it.
if ! [[ -d ${BACKUP_DIR} ]]; then
  # CREATE BACKUP FOLDER
  echo
  echo "Creating Backup directory: ${BACKUP_DIR}"
  echo
  mkdir -p ${BACKUP_DIR}
fi

FULL_BACKUP_DIRECTORY=${BACKUP_DIR}/backup

echo
echo "Create sub folder: ${FULL_BACKUP_DIRECTORY}"
echo
mkdir -p ${FULL_BACKUP_DIRECTORY}

# Bundling Postgres
if [[ "$(ls -A ${MOUNT_POINT_POSTGRES_DB})" ]]; then
  echo
  echo "Creating backup for PostgreSQL database..."
  docker exec ct-postgres pg_dump --host=localhost --username=testify --format=custom --compress=7 --dbname=testify >"${FULL_BACKUP_DIRECTORY}/${BACKUP_POSTGRES_NAME}"
  validateReturnCode
  echo "Created archive with PostgreSQL data"
  echo "Size of archive : $(stat -c%s "${FULL_BACKUP_DIRECTORY}/${BACKUP_POSTGRES_NAME}")"
fi

# Bundling Keycloak
if [[ "$(ls -A ${MOUNT_POINT_KEYCLOAK_DB})" ]]; then
  echo
  echo "Creating backup for keycloak database..."
  tar -czf "${FULL_BACKUP_DIRECTORY}/${BACKUP_KEYCLOAK_NAME}" ${MOUNT_POINT_KEYCLOAK_DB}/*
  validateReturnCode
  echo "Created archive with keycloak data"
  echo "Size of tarball : $(stat -c%s "${FULL_BACKUP_DIRECTORY}/${BACKUP_KEYCLOAK_NAME}")"
fi

# Bundling FileServer
if [[ ${SKIP_FILE_SERVER_BACKUP} == false ]]; then

  if [[ "$(ls -A ${MOUNT_POINT_FILE_SERVER})" ]]; then
    echo
    echo "Creating backup for the file server..."
    tar -czf "${FULL_BACKUP_DIRECTORY}/${BACKUP_FILE_SERVER_NAME}" "${MOUNT_POINT_FILE_SERVER}"/*
    validateReturnCode
    echo "Created archive with file server data"
    echo "Size of tarball : $(stat -c%s "${FULL_BACKUP_DIRECTORY}/${BACKUP_FILE_SERVER_NAME}")"
  fi

fi

# Bundling Licenses
if [[ "$(ls -A ${MOUNT_POINT_TESTIFY_LICENSES})" ]]; then
  echo
  echo "Creating backup for licenses..."
  tar -czf "${FULL_BACKUP_DIRECTORY}/${BACKUP_LICENSES_NAME}" "${MOUNT_POINT_TESTIFY_LICENSES}"/*
  validateReturnCode
  echo "Created archive with licenses data"
  echo "Size of tarball : $(stat -c%s "${FULL_BACKUP_DIRECTORY}/${BACKUP_LICENSES_NAME}")"
fi

# Bundling Internal Proxy ssl certificate files
if [[ "$(ls -A ${MOUNT_POINT_INTERNAL_PROXY_CERT})" ]]; then
  echo
  echo "Creating backup for ssl certificate files..."
  tar -czf "${FULL_BACKUP_DIRECTORY}/${BACKUP_SSL_CERT_NAME}" "${MOUNT_POINT_INTERNAL_PROXY_CERT}"/*
  validateReturnCode
  echo "Created archive with ssl certificate files"
  echo "Size of tarball : $(stat -c%s "${FULL_BACKUP_DIRECTORY}/${BACKUP_SSL_CERT_NAME}")"
fi

# Bundling Jenkins config files
if [[ "$(ls -A ${MOUNT_POINT_JENKINS_CONFIG})" ]]; then
  echo
  echo "Creating backup for Jenkins config files..."
  tar -czf "${FULL_BACKUP_DIRECTORY}/${BACKUP_JENKINS_CONFIG_NAME}" "${MOUNT_POINT_JENKINS_CONFIG}"/*
  validateReturnCode
  echo "Created archive with Jenkins config files"
  echo "Size of tarball : $(stat -c%s "${FULL_BACKUP_DIRECTORY}/${BACKUP_JENKINS_CONFIG_NAME}")"
fi

# Make sure backup was retrieved
if [[ -d "${FULL_BACKUP_DIRECTORY}" ]]; then
  if ! [[ "$(ls -A ${FULL_BACKUP_DIRECTORY})" ]]; then

    err ""
    err "No backup has been created, aborting !"
    err ""
    exit 1
  fi
fi

# Make a backup of the docker folder
echo
echo "Copying current docker directory"
echo
cp -r ${DOCKER_DIR} ${BACKUP_DIR}

echo
echo "Backup have been retrieved and can be found at ${BACKUP_DIR}"
echo
