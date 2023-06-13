#!/usr/bin/env bash

source ./config.sh
PROGRAM=$(basename "$0")

usage() {
  echo
  echo "Usage: "
  echo "  -m, --maintenance-script"
  echo "       Maintenane Script Name (mandatory)"
  echo "Using ${PROGRAM} -h | --help will show this dialog"
  echo
  echo "PROD Example: sudo ./${PROGRAM} -m 2.9.2-master"
  echo "DEV Example: sudo ./${PROGRAM} -m 2.9.2-develop"
  echo
  exit 1
}

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  usage
fi

# Loop through parameter given to the script
while [[ -n "$1" ]]; do

  case "$1" in
  -m | --maintenance-script)
    if [[ -z "$2" ]] || [[ $2 == "-*" ]]; then
      usage
    fi
    MAINTENANCE_SCRIPT="$2"
    shift 2
    ;;
  *)
    echo "Unexpected parameter"
    usage #Unexpected parameter was given, print usage.
    ;;
  esac

done

if [[ -z ${MAINTENANCE_SCRIPT} ]]; then
  echo
  echo "The maintenance script has not been specified, see usage:"
  echo
  usage
fi

# Retrieving testify updater files
echo
echo "Retrieving testify updater files..."
cd /opt/testify
curl https://artifactory.testify.com/artifactory/testify-ct-docker-images/maintenance-scripts/${MAINTENANCE_SCRIPT}/testify-updater-linux.tar.gz --output ./testify-updater-linux.tar.gz
rm -rf /opt/testify/testify-updater/*
tar -xf testify-updater-linux.tar.gz -C /opt/testify/testify-updater --strip-components=1
rm -rf ./testify-updater-linux.tar.gz
echo
echo "Testify updater files have been extracted into /opt/testify/testify-updater."
echo
