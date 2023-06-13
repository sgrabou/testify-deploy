#!/usr/bin/env bash

####################################################################
#                                                                  #
#                Clean Up All executions                           #
#                                                                  #
####################################################################

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./config.sh

PROGRAM=$(basename "$0")

WORK_DIR=$(pwd)
FILE_SERVER_PATH=/var/lib/docker/volumes/testify-file-server/_data/
SQL_FILENAME=clean-up-executions.sql

echo
echo "------------------- WARNING --------------------"
echo " This script will clean the following items:"
echo "     - Jenkins Workspace"
echo "     - Log Files on the server"
echo "     - Execution Page in Testify"
echo "     - Dashboard Page in Testify"
echo "------------------- WARNING --------------------"
echo
echo

# Contains the usage documentation and exit with code 126
usage() {
  echo
  echo "Usage: "
  echo "  -d, --days Number of days"
  echo "       Specify the number of days to keep the data. Default is none"
  echo "  -t, --tenant tenant Id"
  echo "       Specify the id of the tenant to cleanup the execution. Default is cleaning the public schema."
  echo "Using ${PROGRAM} -h | --help will show this dialog"
  echo
  echo "Example: sudo ./${PROGRAM} -d 30"
  echo
  exit 1
}

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  usage
fi

# Loop through parameter given to the script
while [[ -n "$1" ]]; do

  case "$1" in
  -d | --days)
    if [[ -z "$2" ]] || [[ $2 == "-*" ]]; then
      echo
      echo "No number of days given, see usage:"
      echo
      usage
    fi
    DAYS="$2"
    echo
    echo "Cleanup the execution but keeping the last ${DAYS} days"
    echo
    shift 2
    ;;
  -t | --tenant)
    if [[ -z "$2" ]] || [[ $2 == "-*" ]]; then
      echo
      echo "No tenant id given, see usage:"
      echo
      usage
    fi
    TENANT_ID="$2"
    echo
    echo "Cleanup the execution for the tenant id ${TENANT_ID}"
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

echo "Don't forget to do a backup before proceeding to the cleanup..."

if [[ -z ${TENANT_ID} ]]; then
  CONFIRM_MSG="All execution data will be deleted only for the public schema. Are you sure you want to continue (y/n)?"
  CONFIRM_DAYS_MSG="All execution data will be deleted only for the public schema, except for the last ${DAYS} days. Are you sure you want to continue (y/n)?"
else
  CONFIRM_MSG="All execution data will be deleted for tenant ${TENANT_ID}. Are you sure you want to continue (y/n)?"
  CONFIRM_DAYS_MSG="All execution data will be deleted for tenant ${TENANT_ID}, except for the last ${DAYS} days. Are you sure you want to continue (y/n)?"
fi

if [[ -z ${DAYS} ]]; then
  read -p "${CONFIRM_MSG}" choice
  case "$choice" in
  y | Y) echo "Starting..." ;;
  n | N) exit 0 ;;
  *) exit 0 ;;
  esac
else
  read -p "${CONFIRM_DAYS_MSG}" choice
  case "$choice" in
  y | Y) echo "Starting..." ;;
  n | N) exit 0 ;;
  *) exit 0 ;;
  esac
fi

echo
echo "Stopping and Deleting Jenkins Container..."
cd ${DOCKER_DIR_CT}
docker-compose -f docker-compose-prod.yml stop jenkins
validateReturnCode
docker container prune --force
validateReturnCode

echo
echo "Stopping Springboot Container..."
docker-compose -f docker-compose-prod.yml stop springboot
validateReturnCode

# Cleanup the log files
echo
echo "cd ${FILE_SERVER_PATH}"
cd ${FILE_SERVER_PATH}

if [[ -z ${DAYS} ]]; then
  echo "Deleting all log files on the Server..."
  if [[ -z ${TENANT_ID} ]]; then
    rm -rf ./execution-files
    rm -rf ./manual-execution-files
    rm -rf ./manual-hybrid-files
  else
    rm -rf Tenant_${TENANT_ID}
  fi
else
  echo "Deleting all log files older than ${DAYS} days on the Server..."

  # Go to the right directory depending if it is for a tenant or not
  if [[ -z ${TENANT_ID} ]]; then
    if [[ -d "execution-files" ]]; then
      cd execution-files
    else
      echo "execution-files is empty or not a directory"
    fi
  else
    if [[ -d "Tenant_${TENANT_ID}/execution-files" ]]; then
      cd Tenant_${TENANT_ID}/execution-files
    else
      echo "Tenant_${TENANT_ID}/execution-files is empty or not a directory"
    fi
  fi

  # Delete directories older then the given number of days in the execution-files directory
  find -maxdepth 1 -type d -mtime +${DAYS} -exec rm -r {} \;
  cd ..

  # If the manual-execution-files and/or manual-hybrid-files directory exist,
  # go into them and delete directories older then the given number of days
  if [[ -d "manual-execution-files" ]]; then
    cd manual-execution-files
    find -maxdepth 1 -type d -mtime +${DAYS} -exec rm -r {} \;
    cd ..
  fi
  if [[ -d "manual-hybrid-files" ]]; then
    cd manual-hybrid-files
    find -maxdepth 1 -type d -mtime +${DAYS} -exec rm -r {} \;
    cd ..
  fi

fi
validateReturnCode

# Cleanup the db

# Set the schema to use for the db cleanup
if [[ -z ${TENANT_ID} ]]; then
  SCHEMA=public
else
  SCHEMA=Tenant_${TENANT_ID}
fi

echo
echo "Creating SQL File using schema ${SCHEMA}..."
cd ${WORK_DIR}
if [[ -z ${DAYS} ]]; then
  cat <<EOF >${SQL_FILENAME}
delete from "${SCHEMA}".job;
delete from "${SCHEMA}".manual_step_result;
delete from "${SCHEMA}".manual_scenario_result;
delete from "${SCHEMA}".manual_functionality_result;
delete from "${SCHEMA}".manual_test_plan_result;
delete from "${SCHEMA}".reportelement;
delete from "${SCHEMA}".reportelementparam;
EOF
else
  cat <<EOF >${SQL_FILENAME}
delete from "${SCHEMA}".job where created_date < current_date - interval '${DAYS} day';
delete from "${SCHEMA}".manual_step_result where created_date < current_date - interval '${DAYS} day';
delete from "${SCHEMA}".manual_scenario_result where created_date < current_date - interval '${DAYS} day';
delete from "${SCHEMA}".manual_functionality_result where created_date < current_date - interval '${DAYS} day';
delete from "${SCHEMA}".manual_test_plan_result where created_date < current_date - interval '${DAYS} day';
delete from "${SCHEMA}".reportelementparam where reportelementid in (SELECT id from reportelement where timestarted < current_date - interval '${DAYS} day');
delete from "${SCHEMA}".reportelement where timestarted < current_date - interval '${DAYS} day';
EOF
fi
validateReturnCode

echo
echo "Executing SQL Script..."
docker cp ${SQL_FILENAME} ct-postgres:/
validateReturnCode
docker exec ct-postgres psql -h localhost -U testify -d testify -f /${SQL_FILENAME}
validateReturnCode
docker exec ct-postgres rm /${SQL_FILENAME}
validateReturnCode
rm ${SQL_FILENAME}
validateReturnCode

echo
echo "Restarting Containers..."
cd ${DOCKER_DIR_CT}
docker-compose -f docker-compose-prod.yml up -d jenkins
validateReturnCode
# We start the springboot container by setting a configuration directly on the command line (to prevent updating the libs for the tenants)
# We need to us the "up" command to update the config.
INITIALIZE_TENANT_DATABASE=false INITIALIZE_DEFAULT_DATABASE=false docker-compose -f docker-compose-prod.yml up -d springboot
validateReturnCode
docker-compose -f docker-compose-prod.yml restart nginx
validateReturnCode

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
echo "Reclaiming space..."
docker system prune -a --volumes -f
validateReturnCode

echo
echo
echo "Clean Up Executions has been completed successfully!"
echo
