#!/usr/bin/env bash

####################################################################
#                                                                  #
#     Script to run an installation/update on the server where     #
#                          it is executed                          #
#                                                                  #
####################################################################

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./config.sh
WORK_DIR=$(pwd)

PROGRAM=$(basename "$0")
BACKUP_DIR=${BACKUP_ROOT}/backup-$(date +'%Y_%m_%d_%H_%M_%S')

TESTIFY_IMAGE_PATH=${TESTIFY_IMAGE_DEFAULT_PATH}

FRESH=false
FORCE=false

# Ensure the presence of a docker folder to use for the installation
if [[ ! -d ${INSTALLATION_DOCKER_DIRECTORY} ]]; then
  echo
  echo "No docker folder for installation was found on server."
  echo "Please ensure the presence of the proper docker folder at ${INSTALLATION_DOCKER_DIRECTORY}"
  echo
  exit 1
fi

# Contains the usage documentation and exit with code 126
usage() {
  echo "Usage: ${PROGRAM} -t dockerTag [-i pathToImagesArchive] [--fresh] [--force] [--skipFileServerBackup]"
  echo "  -t, --tag dockerTag"
  echo "       Specify the docker tag to install (mandatory)"
  echo "  -i, --images [pathToImagesArchive]"
  echo "       Specify file to use to load testify images"
  echo "  --fresh"
  echo "       Specify if the installation should be from scratch (no backup)"
  echo "  --force"
  echo "       Forces the update, delete all testify images forcing a re-download"
  echo "  [--skipFileServerBackup]"
  echo "       To skip the file server backup"
  echo
  echo "Using ${PROGRAM} -h|--help will show this dialog"
  echo
  exit 1
}

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  usage
fi

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
    echo "Installing docker tag ${VERSION_TAG}"
    echo
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

    echo
    echo "Using archive ${TESTIFY_IMAGE_PATH} to load docker images"
    echo
    shift 2
    ;;
  --fresh)
    FRESH=true
    echo
    echo "No data will be saved from previous installation"
    echo
    echo
    shift
    ;;
  --nowarning)
    NO_WARNING=true
    shift
    ;;
  --rollback)
    # Flag used to inform user how this script was launched, not in usage, and should not be.
    FRESH=true
    echo
    echo "Updating in rollback mode with a different version, deleting previous docker instances before loading rollback."
    echo
    shift
    ;;
  --force)
    FORCE=true
    echo
    echo "Testify docker image will be deleted and fetched again..."
    echo
    shift
    ;;
  --skipFileServerBackup)
    SKIP_FILE_SERVER_BACKUP="$1"
    echo
    echo "File server backup ignored"
    echo
    shift
    ;;
  *)
    echo "Unexpected parameter"
    usage #Unexpected parameter was given, print usage.
    ;;
  esac

done

if [[ -z ${VERSION_TAG} ]]; then
  echo
  echo "No docker tag was specified"
  echo
  usage
fi

if [[ ${FRESH} == true ]] && [[ -z ${NO_WARNING} ]]; then
  read -p "This will DELETE ALL EXISTING DATA! Are you sure you want to continue? (y/n)" choice
  case "$choice" in
  y | Y) echo "Starting..." ;;
  n | N) exit 0 ;;
  *) exit 0 ;;
  esac
fi

###############################
#    QUICK RESTART SECTION    #
###############################
if [[ ${FRESH} == false ]]; then
  echo "Restarting docker instance to make sure no hanging threads are blocking the update..."

  docker-compose -f ${DOCKER_DIR_CT}/docker-compose-prod.yml stop
  docker-compose -f ${DOCKER_DIR_CT}/docker-compose-prod.yml start
  waitForServer

  echo "Restart complete continuing with update."
fi

########################
#    BACKUP SECTION    #
########################

if [[ ${FRESH} == false ]]; then
  echo "Stopping NGINX to be sure no one will launch an execution..."
  CURRENT_DIR=$(pwd)
  cd ${DOCKER_DIR_CT}
  docker-compose -f docker-compose-prod.yml stop nginx
  cd ${CURRENT_DIR}

  # CREATE BACKUP FOLDER
  echo
  echo "Creating Backup directory: ${BACKUP_DIR}"
  echo
  mkdir -p ${BACKUP_DIR}
  ./backup.sh -t ${VERSION_TAG} ${SKIP_FILE_SERVER_BACKUP} ${BACKUP_DIR}
fi

######################################
#    INSTALLATION/UPGRADE SECTION    #
######################################

# Try to stop all testify container and delete them if a docker directory can be found
if [[ -d ${DOCKER_DIR_CT} ]]; then
  echo
  echo "Trying to stop previous testify containers and delete them ..."
  echo
  cd ${DOCKER_DIR_CT}
  docker-compose -f docker-compose-prod.yml down || (err "Something went wrong when attempting to stop previous testify installation..." && exit 1)
fi

# If fresh, deletes everything from docker related to testify
if [[ ${FRESH} == true ]]; then
  echo
  echo "Deleting every data related to testify since fresh tag has been invoked..."
  echo
  deleteTestifyDockerRelatedData
elif [[ ${FORCE} == true ]]; then
  echo
  echo "Deleting every testify related images since force tag has been invoked..."
  echo
  deleteTestifyImage
fi

# TODO DELETE THIS WHEN ALL INSTANCES HAVE BEEN UPDATED TO 2.16.0
${WORK_DIR}/TEMP_remove_proxy_config_volume.sh
# TODO DELETE THIS WHEN ALL INSTANCES HAVE BEEN UPDATED TO 2.16.0

# Add volumes
echo
echo "Creating docker volumes if they don't already exist..."
echo
${UPDATER_DIR}/create-volume.sh

# Remove previous docker folder to backup section
echo
echo "Deleting previous docker directory..."
echo
rm -rf ${DOCKER_DIR}

# Copy the new docker folder
echo
echo "Copying new docker data to docker directory"
echo
cp -R ${INSTALLATION_DOCKER_DIRECTORY} ${DOCKER_DIR}

echo
echo "Setting configurations..."
echo
echo "About to change variable inside  ${DOCKER_DIR_CT}/.env"
echo
rm ${DOCKER_DIR_CT}/docker-compose.yml
sed -i "s#^\(TESTIFY_DOCKER_TAG\s*=\s*\).*\$#\1$VERSION_TAG#" ${DOCKER_DIR_CT}/.env

# If testify docker images archive is present, use it.
if [[ -f ${TESTIFY_IMAGE_PATH} ]]; then

  echo
  echo "Loading testify images from file..."
  echo
  docker load -i ${TESTIFY_IMAGE_PATH}
fi

cd ${DOCKER_DIR_CT}
# Restore Database Backup
echo
if [[ ${FRESH} == false ]]; then
  rm -rf ${MOUNT_POINT_POSTGRES_DB}/*
  echo "Starting PostgreSQL container..."
  docker-compose -f docker-compose-prod.yml up -d postgres
  sleep 20

  echo "Waiting PostgreSQL container..."
  echo
  ${UPDATER_DIR}/restore-database-dump.sh -f ${BACKUP_DIR}/backup/${BACKUP_POSTGRES_NAME} --do-not-restart-springboot

  # Restore Licenses
  if [[ -f ${BACKUP_DIR}/backup/${BACKUP_LICENSES_NAME} ]]; then
    rm -rf ${MOUNT_POINT_TESTIFY_LICENSES}/*
    echo "Restoring Licenses..."
    tar -xzf "${BACKUP_DIR}/backup/${BACKUP_LICENSES_NAME}" -C /
    validateReturnCode
    echo "Licenses restored!"
  fi
fi

echo
echo "Starting the docker container for Testify..."
echo
docker-compose -f docker-compose-prod.yml up -d
waitForServer

# Check if there are libraries to install
if [[ -d ${TESTIFY_LIBRARIES_DIRECTORY} ]]; then
  if [[ "$(ls -A ${TESTIFY_LIBRARIES_DIRECTORY})" ]]; then

    echo
    echo "Installing extra libraries on the jenkins container..."
    echo
    cd ${UPDATER_DIR}
    ./add-additional-libraries.sh ${TESTIFY_LIBRARIES_DIRECTORY}
    ./install-additional-libraries.sh

    echo
    echo "Restarting Docker containers..."
    echo
    cd ${DOCKER_DIR_CT}
    docker-compose -f docker-compose-prod.yml stop
    docker-compose -f docker-compose-prod.yml up -d

    waitForServer
  fi
fi

echo
echo "Testify installation or update has been completed."
echo
