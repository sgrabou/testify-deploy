#!/usr/bin/env bash

###################################################
#
# THIS SCRIPT CAN BE USED RESTORE DATABASE DUMP
# It will only restore the public schema. All
# other schema will not be touched
#
###################################################

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./config.sh

# Contains the usage documentation and exit with code 126
usage() {
  echo
  echo "Usage: -f Database file (source)"
  echo "  -f, --file Database file (source)"
  echo "       Specify the database file to restore (mandatory)"
  echo "Example: sudo ./restore-database-public-only.sh -f ./testify-db.dump"
  echo
  exit 1
}

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  usage
fi

# Loop through parameter given to the script
while [[ -n "$1" ]]; do

  case "$1" in
  -f | --file)
    if [[ -z "$2" ]] || [[ $2 == "-*" ]]; then
      echo
      echo "No database file given, see usage:"
      echo
      usage
    fi
    FILE_PATH="$2"
    echo
    echo "Restoring database with the following file: ${FILE_PATH}"
    echo
    shift 2
    ;;
  *)
    echo
    echo "Unexpected parameter, see usage:"
    usage #Unexpected parameter was given, print usage.
    ;;
  esac

done

if [[ -z ${FILE_PATH} ]]; then
  echo
  echo "No database file specified, see usage:"
  echo
  usage
fi

if [[ ! -f ${FILE_PATH} ]]; then
  echo
  echo "Database file not found: ${FILE_PATH}"
  echo
  exit 1
fi

./restore-database-dump.sh -f ${FILE_PATH} -s public
