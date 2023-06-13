#!/usr/bin/env bash

####################################################################
#                                                                  #
#      Script copy the data from a source to a target schema.      #
#                                                                  #
# The script start to dump the data of the source schema and       #
# exclude the tables based on the pattern list set in the          #
# EXCLUDE_TABLE_PATTERN_LIST constant.                             #
# The dump is a plain text sql file.                               #
# The name of the source schema is replaced by the target one      #
# using sed in the dump file.                                      #
# And finally restore the data in the target schema.               #
#                                                                  #
####################################################################

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./config.sh
PROGRAM=$(basename "$0")

DUMP_FILE_NAME=public_schema-dump.sql

# List of pattern (see: https://www.postgresql.org/docs/current/app-pgdump.html and https://www.postgresql.org/docs/current/app-psql.html#APP-PSQL-PATTERNS) for table exclusion
EXCLUDE_TABLE_PATTERN_LIST="reportelement*, *_type, flyway*, job, audit"

EXCLUDE_PARAMS=""

createExcludeTableParams() {
  # This command is used to be able to trim the strings
  shopt -s extglob
  IFS=,
  for val in $EXCLUDE_TABLE_PATTERN_LIST; do
    # Trim leading and trailling whitespace
    TRIM_VAL="${val##*( )}"
    TRIM_VAL="${TRIM_VAL%%*( )}"
    EXCLUDE_PARAMS="${EXCLUDE_PARAMS}--exclude-table-data='${TRIM_VAL}' "
  done
  # Put trimming mode off
  shopt -u extglob
}

# Contains the usage documentation and exit with code 126
usage() {
  echo "Usage: ${PROGRAM} schema_source_name schema_target_name"
  echo
  exit 1
}

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  usage
fi

if [[ -z "$1" ]] || [[ -z "$2" ]]; then
  usage
fi

createExcludeTableParams
echo
echo "Copy the source schema $1 data to the schema $2"
echo
# EXECUTE SQL SCRIPT
echo "Dump to the file ${DUMP_FILE_NAME}"
DUMP_CMD="docker exec ct-postgres pg_dump --host=localhost --username=testify --format=plain --dbname=testify --schema=$1 --column-inserts --data-only --quote-all-identifiers ${EXCLUDE_PARAMS} > ${DUMP_FILE_NAME}"
echo ${DUMP_CMD}
eval "${DUMP_CMD}"

echo
echo "Replace the $1 schema name by $2 in the dump sql file (${DUMP_FILE_NAME})"
sed -i "s#\"$1\"#\"$2\"#" ${DUMP_FILE_NAME}

# Cleanup of the target db
echo "Cleaning the target schema $2"
# Create a copy of the cleanup sql file
cp cleanup_schema.sql cleanup_schema_copy.sql
# Replace the schema name in the sql file
sed -i "s#SCHEMA_NAME#$2#" cleanup_schema_copy.sql
# Execute the sql file
docker cp cleanup_schema_copy.sql ct-postgres:/
docker exec ct-postgres psql -h localhost -U testify -d testify -f /cleanup_schema_copy.sql
docker exec ct-postgres rm /cleanup_schema_copy.sql
rm cleanup_schema_copy.sql

# Get secured information from the Vault
vault_token=$(docker exec ct-vault vault write -field=token auth/approle/login role_id="a727d5c1-0389-4538-a747-d5b1e43ac1f8" secret_id="a47aab76-f207-69f9-6361-5026d733a568")
docker exec ct-vault vault login ${vault_token}
jenkins_user=$(docker exec ct-vault vault kv get -field=appconfig.jenkinsApiUser secret/testify-web)
jenkins_token=$(docker exec ct-vault vault kv get -field=appconfig.jenkinsApiToken secret/testify-web)

# We also need to cleanup the jenkins executions
curl -X POST http://${jenkins_user}:${jenkins_token}@localhost:7070/jenkins/job/Testify_RemoveAllButRunning/build

echo
echo "Restore the data using psql in the Postgres container"
echo "Copy the file to the container..."
docker cp ./${DUMP_FILE_NAME} ct-postgres:/
echo "Execute the sql file..."
docker exec ct-postgres psql -v ON_ERROR_STOP=1 -U testify testify -f /${DUMP_FILE_NAME}
echo "Remove the dump file at both place..."
docker exec ct-postgres rm /${DUMP_FILE_NAME}
rm ${DUMP_FILE_NAME}

echo
echo "Schema data copy completed!"
echo
