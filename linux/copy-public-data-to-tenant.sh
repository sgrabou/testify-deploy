#!/usr/bin/env bash

####################################################################
#                                                                  #
#      Script copy the data from the public schema to the
#      given tenant_id schema.                                     #
#                                                                  #
####################################################################

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./config.sh
PROGRAM=$(basename "$0")

# Contains the usage documentation and exit with code 126
usage() {
  echo "Usage: ${PROGRAM} tenant_id"
  echo
  exit 1
}

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  usage
fi

if [[ -z "$1" ]]; then
  usage
fi

TENANT_ID=$1

echo "Copy the data of public schema to the schema of the ${TENANT_ID} tenant"
./copy-schema-data.sh public Tenant_${TENANT_ID}
