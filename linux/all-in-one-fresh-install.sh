#!/usr/bin/env bash

WORK_DIR=$(pwd)
# Move to the testify-updater folder to be able to launch the script everywhere
cd /opt/testify/testify-updater

source ./config.sh

###################################################
#
# All In one Fresh Install Script
#
###################################################

# PARAMETERS ######################################
#
# $1 = Tag, example (mandatory):
#       PROD: 2.10.2
#       DEV:  develop
#
###################################################

PET_CLINIC_DOCKER_COMPOSE_FILE="docker-compose.yml"
TRIAL_DIR=/opt/testify/trial
PET_CLINIC_DIR=/opt/petclinic

PROGRAM=$(basename "$0")

# CHECK IF THE USER IS ROOT / SUDO
if [[ $EUID -ne 0 ]]; then
  echo
  echo "This script must be run as root or with sudo."
  echo
  exit
fi

# Contains the usage documentation and exit with code 1
usage() {
  echo
  echo "Usage: "
  echo "  -t, --tag"
  echo "       Docker Tag Name (mandatory)"
  echo "Using ${PROGRAM} -h | --help will show this dialog"
  echo
  echo "PROD Example: sudo ./${PROGRAM} -t 2.10.2"
  echo "DEV Example: sudo ./${PROGRAM} -t develop"
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
      usage
    fi
    TAG_NAME="$2"
    shift 2
    ;;
  --force)
    FORCE="true"
    shift 1
    ;;
  *)
    echo "Unexpected parameter"
    usage #Unexpected parameter was given, print usage.
    ;;
  esac

done

if [[ -z ${TAG_NAME} ]]; then
  echo
  echo "The docker tag name has not been specified, see usage:"
  echo
  usage
fi

if [[ -z ${FORCE} ]]; then
  echo "Must validate..."
  read -p "This will DELETE ALL THE DATA ON THE SERVER.... Are you sure you want to continue? (y/n)" choice
  case "$choice" in
  y | Y) echo "Starting..." ;;
  n | N) exit 0 ;;
  *) exit 0 ;;
  esac
else
  echo "Bypass the warning..."
fi

echo
echo "Retrieving Testify Updater files..."
cd ${TESTIFY_HOME}
curl https://artifactory.testify.com/artifactory/testify-ct-docker-images/maintenance-scripts/${TAG_NAME}/testify-updater-linux.tar.gz --output ./testify-updater-linux.tar.gz
rm -rf ${UPDATER_DIR}
mkdir -p ${UPDATER_DIR}
tar -xf testify-updater-linux.tar.gz -C ${UPDATER_DIR} --strip-components=1
rm -rf ./testify-updater-linux.tar.gz
echo
echo "Testify Updater files have been extracted into: ${UPDATER_DIR}/"
echo

echo
echo "Launching Testify installation file..."
echo
cd ${UPDATER_DIR}
./update.sh -t ${TAG_NAME} --fresh --nowarning

# Download Trial file if PetClinic is present
if [[ -f "${PET_CLINIC_DIR}/${PET_CLINIC_DOCKER_COMPOSE_FILE}" ]]; then

  echo "Starting Pet Clinic..."
  echo
  cd ${PET_CLINIC_DIR}
  docker-compose -f docker-compose.yml up --build -d

  echo "Retrieving Trial files from GIT..."
  echo
  mkdir -p ${TRIAL_DIR}
  cd ${TRIAL_DIR}

  # Getting Branch name from Tag
  if [[ ${TAG_NAME} =~ ^[0-9]+\.[0-9]+ ]]; then
    BRANCH=master
  else
    BRANCH=${TAG_NAME}
  fi

  curl --request GET --header "PRIVATE-TOKEN: Jsbm8NYL5CYFbxx5FjYS" "https://git.testify.com/api/v4/projects/106/repository/files/utility%2Ftrial%2Ftrial.sh/raw?ref=${BRANCH}" --output trial.sh
  curl --request GET --header "PRIVATE-TOKEN: Jsbm8NYL5CYFbxx5FjYS" "https://git.testify.com/api/v4/projects/106/repository/files/utility%2Ftrial%2Ftrial-data.sql/raw?ref=${BRANCH}" --output trial-data.sql
  curl --request GET --header "PRIVATE-TOKEN: Jsbm8NYL5CYFbxx5FjYS" "https://git.testify.com/api/v4/projects/106/repository/files/utility%2Ftrial%2Ftestify-db.dump/raw?ref=${BRANCH}" --output testify-db.dump

  echo
  echo "Replacing the default Database with the Trial Database..."
  echo
  chmod +x trial.sh

  ./trial.sh

  waitForServer
fi

echo
echo Installing Services...
cd ${SERVICES_DIR}
./install-testify-service.sh

# Go back to initial directory
cd ${WORK_DIR}
echo
echo
echo "Testify installation has been completed."
echo
echo
