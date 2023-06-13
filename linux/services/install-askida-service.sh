#!/usr/bin/env bash

##############################################################################
#                                                                            #
#  Install Testify Services                                                   #
#                                                                            #
##############################################################################

source ../config.sh

TESTIFY_CT_SERVICE="testify-ct.service"
TESTIFY_CT_PET_CLINIC_SERVICE="testify-ct-petclinic.service"

PET_CLINIC_DOCKER_COMPOSE_FILE="/opt/petclinic/docker-compose.yml"

echo
echo "Installing Testify Services..."
cp ${SERVICES_DIR}/${TESTIFY_CT_SERVICE} ${SYSTEM_D}
systemctl enable ${TESTIFY_CT_SERVICE}

if [[ -f "${PET_CLINIC_DOCKER_COMPOSE_FILE}" ]]; then
  echo
  echo "Installing Testify Pet Clinic Service..."
  cp ${SERVICES_DIR}/${TESTIFY_CT_PET_CLINIC_SERVICE} ${SYSTEM_D}
  systemctl enable ${TESTIFY_CT_PET_CLINIC_SERVICE}
fi

systemctl daemon-reload
echo
