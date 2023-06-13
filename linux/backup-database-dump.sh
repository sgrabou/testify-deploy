#!/usr/bin/env bash

###################################################
#
# THIS SCRIPT CAN BE USED BACKUP A DATABASE DUMP
#
###################################################

# PARAMETERS ######################################
#
# $1 = database file (destination)
#
###################################################

source ./config.sh

# Contains the usage documentation and exit with code 126
usage() {
  echo
  echo "Usage: "
  echo "  -o, --output Database file (destination)"
  echo "       Specify the database output file (mandatory)"
  echo "Using ${PROGRAM} -h | --help will show this dialog"
  echo
  echo "Example: sudo ./backup-database-dump.sh -o ./testify-db.dump"
  echo
  exit 1
}

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  usage
fi

# Loop through parameter given to the script
while [[ -n "$1" ]]; do

  case "$1" in
  -o | --output)
    if [[ -z "$2" ]] || [[ $2 == "-*" ]]; then
      echo
      echo "No database file given, see usage:"
      echo
      usage
    fi
    FILE_PATH="$2"
    echo
    echo "Backuping database with the following file: ${FILE_PATH}"
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
  echo "No database destination file specified, see usage:"
  echo
  usage
fi

if [[ -f ${FILE_PATH} ]]; then
  echo
  echo "Database destination file already exists, use another name: ${FILE_PATH}"
  echo
  exit 1
fi

# BACKUP DATABASE
echo
echo "Backing up Database..."
docker exec ct-postgres pg_dump --host=localhost --username=testify --format=custom --compress=7 --dbname=testify >${FILE_PATH}
validateReturnCode
echo
echo "Database backup has been completed, the following file as been created: ${FILE_PATH}"
echo
