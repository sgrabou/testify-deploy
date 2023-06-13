#!/usr/bin/env bash

###################################################
#
# THIS SCRIPT CAN BE USED RESTORE DATABASE DUMP
#
###################################################

# PARAMETERS ######################################
#
# $1 = database file (source)
#
###################################################

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./config.sh

WORK_DIR=$(pwd)

TESTIFY_DB_DUMP="testify-db.dump"
RESTART_SPRING_BOOT=true
RESTORE_ONLY_SCHEMA=false
RESTORE_ONLY_SCHEMA_NAME=""

# Contains the usage documentation and exit with code 126
usage() {
  echo
  echo "Usage: -f Database file (source)"
  echo "  -f, --file Database file (source)"
  echo "       Specify the database file to restore (mandatory)"
  echo "  -d, --do-not-restart-springboot"
  echo "       Do not restart Springboot container (optional)"
  echo "  -s, --schema-to-restore (name)"
  echo "       Only restore the given schema (optional)"
  echo "Using ${PROGRAM} -h | --help will show this dialog"
  echo
  echo "Example: sudo ./restore-database-dump.sh -f ./testify-db.dump"
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
  -d | --do-not-restart-springboot)
    RESTART_SPRING_BOOT=false
    echo
    echo "RESTART_SPRING_BOOT set to false"
    echo
    shift
    ;;
  -s | --schema-to-restore)
    if [[ -z "$2" ]] || [[ $2 == "-*" ]]; then
      echo
      echo "No schema name given, see usage:"
      echo
      usage
    fi
    RESTORE_ONLY_SCHEMA=true
    RESTORE_ONLY_SCHEMA_NAME="$2"
    echo
    echo "RESTORE_ONLY_SCHEMA set to true (name:${RESTORE_ONLY_SCHEMA_NAME})"
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

# RESTORE DATABASE WITH DUMP
cd ${DOCKER_DIR_CT}
echo
echo "Stopping Sprinboot container to close all database connections..."
docker-compose -f docker-compose-prod.yml stop springboot
validateReturnCode

# If we restore every thing, we need to drop and re-create the db first
if [[ ${RESTORE_ONLY_SCHEMA} == false ]]; then
  echo
  echo "Dropping Testify database..."

  n=0
  until [ "$n" -ge 15 ]; do
    docker exec ct-postgres dropdb -f -h localhost -U testify --if-exists testify && break
    n=$((n + 1))
    echo "Unable to drop Testify database, trying again..."
    sleep 10
  done

  validateReturnCode

  echo
  echo "Creating Testify database..."
  docker exec ct-postgres createdb -h localhost -U testify testify
  validateReturnCode
fi

echo
echo "Copying the file to the container..."
cd ${WORK_DIR}
docker cp ${FILE_PATH} ct-postgres:/${TESTIFY_DB_DUMP}
validateReturnCode

# We need to drop and re-create the public schema to avoid any possible errors when restoring the db.
echo
echo "Dropping and creating public schema..."
sudo docker exec ct-postgres psql -h localhost -U testify -d testify -c "drop schema if exists public cascade"
sudo docker exec ct-postgres psql -h localhost -U testify -d testify -c "create schema if not exists public"

echo "Restoring database..."
if [[ ${RESTORE_ONLY_SCHEMA} == false ]]; then
  docker exec ct-postgres pg_restore --host=localhost --username=testify --format=custom --clean --if-exists --exit-on-error --dbname=testify ./${TESTIFY_DB_DUMP}
else
  RESTORE_CMD="docker exec ct-postgres pg_restore --host=localhost --username=testify --format=custom --clean --if-exists --exit-on-error --dbname=testify --schema=${RESTORE_ONLY_SCHEMA_NAME} ./${TESTIFY_DB_DUMP}"
  echo ${RESTORE_CMD}
  eval "${RESTORE_CMD}"
fi
validateReturnCode

docker exec ct-postgres rm /${TESTIFY_DB_DUMP}
validateReturnCode
echo

if [[ ${RESTART_SPRING_BOOT} == true ]]; then

  echo "Restarting springboot containers..."
  cd ${DOCKER_DIR_CT}
  docker-compose -f docker-compose-prod.yml up -d springboot
  validateReturnCode
  waitForServer
fi

# Going back to where script was launched
cd ${WORK_DIR}

echo
echo "Database restore has been completed!"
echo
