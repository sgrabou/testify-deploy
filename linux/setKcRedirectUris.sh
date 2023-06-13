#!/usr/bin/env bash

####################################################################
#                                                                  #
#     Script to update the list of redirect uris accepted by the   #
#     "testify-ui" Keycloak client.                                 #
#     Setting a real redirect uri instead of just *, prevent       #
#     some security issues like "Cross site scripting" and         #
#     "Open redirection".                                          #
#     Usually, the uri to set is the external url use to access    #
#     Testify with a wild card at the end. i.e:                  #
#     http://www.testifyct.com/*                                    #
#                                                                  #
####################################################################

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./config.sh
PROGRAM=$(basename "$0")

# Contains the usage documentation and exit with code 1
usage() {
  echo "Usage: ${PROGRAM} [comma separated list of redirect uris]. Use * to accept redirection from anywhere (not secure))"
  echo "i.e: >./setKcRedirectUris.sh http://testifyct.com/*"
  echo "You can also just use * as the value to accept redirection from anywhere. But this is not recommanded since it opens some security issues."
  echo "Note: if you want to set * as the uri, you will need to place it between single quote"
  echo
  exit 1
}

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  usage
fi

if [[ -z "$1" ]]; then
  usage
fi

# Get the username and password from the vault
VAULT_TOKEN=$(docker exec -it ct-keycloak /bin/bash -c 'curl -s --request POST --data '\''{"role_id": "a727d5c1-0389-4538-a747-d5b1e43ac1f8", "secret_id": "a47aab76-f207-69f9-6361-5026d733a568"}'\'' http://ct-vault:8200/v1/auth/approle/login | jq -r '\''.auth.client_token'\''')
# Remove next line character at the end
VAULT_TOKEN=${VAULT_TOKEN::-1}
KEYCLOAK_USERNAME=$(docker exec -it ct-keycloak /bin/bash -c 'curl -s --header "X-Vault-Token: '${VAULT_TOKEN}'" http://ct-vault:8200/v1/secret/testify-web | jq -r '\''.data."keycloakadmin.masterUsername"'\''')
# Remove next line character at the end
KEYCLOAK_USERNAME=${KEYCLOAK_USERNAME::-1}
KEYCLOAK_PASSWORD=$(docker exec -it ct-keycloak /bin/bash -c 'curl -s --header "X-Vault-Token: '${VAULT_TOKEN}'" http://ct-vault:8200/v1/secret/testify-web | jq -r '\''.data."keycloakadmin.masterPassword"'\''')
# Remove next line character at the end
KEYCLOAK_PASSWORD=${KEYCLOAK_PASSWORD::-1}

clientId=$(docker exec -it ct-keycloak /bin/bash -c '/keycloak/bin/kcadm.sh get http://localhost:8280/auth/admin/realms/testify/clients --fields id,clientId,redirectUris --no-config --server http://localhost:8280/auth --realm master --user '${KEYCLOAK_USERNAME}' --password '${KEYCLOAK_PASSWORD}' | jq -r '\''.[] | select(.clientId == "testify-ui") | .id  '\''')
clientId="${clientId##*$'\n'}"
clientId="${clientId%?}"
echo "The clientId is: ${clientId}"
echo "Set redirect uris to: [$1]"

# Update the client with the new value
docker exec -it ct-keycloak /bin/bash -c '/keycloak/bin/kcadm.sh update http://localhost:8280/auth/admin/realms/testify/clients/'${clientId}' -s '\''redirectUris=["'$1'"]'\'' --no-config --server http://localhost:8280/auth --realm master --user '${KEYCLOAK_USERNAME}' --password '${KEYCLOAK_PASSWORD}'' >/dev/nul

echo
echo "Update completed"
