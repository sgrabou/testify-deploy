#!/usr/bin/env bash

##############################################################################
#                                                                            #
#  Setup external proxy                                                      #
#                                                                            #
##############################################################################

cd "$(dirname "${BASH_SOURCE[0]}")"
source ../config.sh

PROGRAM=$(basename "$0")

CERTIFICATE_FILE=ct-cert.crt
PRIVATE_KEY_FILE=ct-private.key
CERTIFICATE_TEMP_FILE=ct-cert-temp.crt
INTERMEDIATE_CERTIFICATE_FILE=ct-intermediate-cert.crt

EXTERNAL_PROXY_CONTAINER=ct-external-proxy
CERT_FOLDER=/etc/nginx/ssl/cert
CONF_FOLDER=/etc/nginx/conf.d
CONFIG_DISABLED=testify-ct.conf.disable
CONFIG_ACTIVATED=testify-ct.conf

TESTIFY_CT_EXTERNAL_PROXY_SERVICE="testify-ct-external-proxy.service"

# Contains the usage documentation and exit with code 1
usage() {
  echo
  echo "Usage: "
  echo "  -c, --certificate-folder"
  echo "       Certificates Folder (mandatory), it must contains:"
  echo "         1. certificate:              ct-cert.crt"
  echo "         2. intermediate certificate: ct-intermediate-cert.key (optional)"
  echo "         3. private key:              ct-private.key"
  echo "  -e, --external-name"
  echo "       External Name when using Proxy / SSL (mandatory)"
  echo "  -i, --internal-name"
  echo "       Internal host name to proxy the request"
  echo "  -s, --standalone"
  echo "       Standalone parameter is used to indicate whether you are installing the External Proxy"
  echo "       on a different server than Testify (possible value: y/n)."
  echo "Using ${PROGRAM} -h | --help will show this dialog"
  echo
  echo "Example: sudo ./${PROGRAM} -c /home/user/cert/ -e ct-422.testify.com -i ct-prod-test2.testify.lan -s y"
  echo
  exit 1
}

if [[ "$1" == "-h" ]] || [[ "$1" == "--help" ]]; then
  usage
fi

# Loop through parameter given to the script
while [[ -n "$1" ]]; do

  case "$1" in
  -c | --certificate-folder)
    if [[ -z "$2" ]] || [[ $2 == "-*" ]]; then
      usage
    fi
    CERTIFICATE_FOLDER="$2"
    shift 2
    ;;
  -e | --external-name)
    if [[ -z "$2" ]] || [[ $2 == "-*" ]]; then
      usage
    fi
    EXTERNAL_NAME="$2"
    shift 2
    ;;
  -i | --internal-name)
    if [[ -z "$2" ]] || [[ $2 == "-*" ]]; then
      usage
    fi
    INTERNAL_NAME="$2"
    shift 2
    ;;
  -s | --standalone)
    if [[ -z "$2" ]] || [[ $2 == "-*" ]]; then
      usage
    fi
    STAND_ALONE="$2"
    shift 2
    ;;
  *)
    echo "Unexpected parameter"
    usage #Unexpected parameter was given, print usage.
    ;;
  esac

done

if [[ -z ${CERTIFICATE_FOLDER} ]]; then
  echo
  echo "The certificate folder has not been specified, see usage:"
  echo
  usage
fi

if [[ -z ${EXTERNAL_NAME} ]]; then
  echo
  echo "The external name has not been specified, see usage:"
  echo
  usage
fi

if [[ -z ${INTERNAL_NAME} ]]; then
  echo
  echo "The internal name has not been specified, see usage:"
  echo
  usage
fi

if [[ -z ${STAND_ALONE} ]]; then
  echo
  echo "The Standalone parameter has not been specified, see usage:"
  echo
  usage
else
  if [[ "${STAND_ALONE}" != "y" ]] && [[ "${STAND_ALONE}" != "n" ]]; then
    echo
    echo "Invalid value for the parameter Standalone, must be y/n, see usage:"
    echo
    usage
  fi
fi

if [[ ! -f "${CERTIFICATE_FOLDER}/$CERTIFICATE_FILE" ]]; then
  echo Certificate File not found: "${CERTIFICATE_FOLDER}/$CERTIFICATE_FILE"
  echo
  exit 1
fi

if [[ ! -f "${CERTIFICATE_FOLDER}/$PRIVATE_KEY_FILE" ]]; then
  echo Certificate File not found: "${CERTIFICATE_FOLDER}/$PRIVATE_KEY_FILE"
  echo
  exit 1
fi

echo
echo "Create the docker directory if not exist"
mkdir -p ${DOCKER_DIR}

echo "Copy docker compose files into the docker dir"
cp -R ${INSTALLATION_DOCKER_DIRECTORY}/external-proxy/ ${DOCKER_DIR}

echo
echo "Create the volumes..."
docker volume create --name external-proxy-config
docker volume create --name external-proxy-cert

echo
echo "Trying to stop External Proxy Container..."
cd ${DOCKER_DIR_EXTERNAL_PROXY}
docker-compose -f docker-compose.yml stop

if [[ "${STAND_ALONE}" == "n" ]]; then
  echo "Removing port 80 in the docker compose file to avoid conflicts with Testify ..."
  sed -i "/80:80/d" ./docker-compose.yml
  echo
fi

echo
echo "Starting External Proxy Container..."
docker-compose -f docker-compose.yml up -d
sleep 10

echo
echo "Copying certificate files to the container..."
if [[ ! -f "${CERTIFICATE_FOLDER}/${INTERMEDIATE_CERTIFICATE_FILE}" ]]; then
  docker cp "${CERTIFICATE_FOLDER}/${CERTIFICATE_FILE}" ${EXTERNAL_PROXY_CONTAINER}:${CERT_FOLDER}/${CERTIFICATE_FILE}
else
  echo "Intermediate certificate present. For Nginx, we need to merge the certificate and the intermediate certificate..."
  echo "Creating temporary file..."
  cp "${CERTIFICATE_FOLDER}/${CERTIFICATE_FILE}" "${CERTIFICATE_FOLDER}/${CERTIFICATE_TEMP_FILE}"

  echo
  echo "Adding blank line at the end if the certificate..."
  echo "" >>"${CERTIFICATE_FOLDER}/${CERTIFICATE_TEMP_FILE}"

  echo
  echo "Merging certificate with the intermediate..."
  cat "${CERTIFICATE_FOLDER}/${INTERMEDIATE_CERTIFICATE_FILE}" >>"${CERTIFICATE_FOLDER}/${CERTIFICATE_TEMP_FILE}"

  echo
  echo "Copying the merge certificate file to the container..."
  docker cp "${CERTIFICATE_FOLDER}/${CERTIFICATE_TEMP_FILE}" ${EXTERNAL_PROXY_CONTAINER}:${CERT_FOLDER}/${CERTIFICATE_FILE}

  echo
  echo "Deleting the temporary file..."
  rm "${CERTIFICATE_FOLDER}/${CERTIFICATE_TEMP_FILE}"
fi

docker cp "${CERTIFICATE_FOLDER}/${PRIVATE_KEY_FILE}" ${EXTERNAL_PROXY_CONTAINER}:${CERT_FOLDER}/${PRIVATE_KEY_FILE}

echo
echo "Check if Testify configuration is disabled..."
set +e
docker exec ${EXTERNAL_PROXY_CONTAINER} test -f "${CONF_FOLDER}/${CONFIG_DISABLED}"

if [[ $? -eq 0 ]]; then
  echo
  echo "Enabling Testify configuration..."
  docker exec ${EXTERNAL_PROXY_CONTAINER} mv ${CONF_FOLDER}/${CONFIG_DISABLED} ${CONF_FOLDER}/${CONFIG_ACTIVATED}

else
  echo
  echo "Testify configuration is already enabled"
fi
set -e

echo
echo "Replacing the INTERNAL_NAME tag in the configuration by: ${INTERNAL_NAME}..."
docker exec ${EXTERNAL_PROXY_CONTAINER} sed -i "s/INTERNAL_NAME/${INTERNAL_NAME}/g" ${CONF_FOLDER}/${CONFIG_ACTIVATED}

echo
echo "Replacing the EXTERNAL_NAME tag in the configuration by: ${EXTERNAL_NAME}..."
docker exec ${EXTERNAL_PROXY_CONTAINER} sed -i "s/EXTERNAL_NAME/${EXTERNAL_NAME}/g" ${CONF_FOLDER}/${CONFIG_ACTIVATED}

echo
echo "Restarting External Proxy Service..."
docker exec ${EXTERNAL_PROXY_CONTAINER} nginx -s reload

echo
echo "Installing Testify External Proxy services..."
cp ${SERVICES_DIR}/${TESTIFY_CT_EXTERNAL_PROXY_SERVICE} ${SYSTEM_D}
systemctl enable ${TESTIFY_CT_EXTERNAL_PROXY_SERVICE}

systemctl daemon-reload

echo
echo
echo "External Proxy Configuration completed!"
echo
