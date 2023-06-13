#!/usr/bin/env bash

if [[ $EUID -ne 0 ]]; then
  echo
  echo "This script must be run as root or with sudo."
  echo
  exit 1
fi

echo
echo Updaging Docker CE to the lastest version...
echo

apt-get remove docker docker-engine docker.io containerd runc

apt-get update

apt-get -y install \
  apt-transport-https \
  ca-certificates \
  curl \
  gnupg-agent \
  software-properties-common

curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -

add-apt-repository \
  "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
   $(lsb_release -cs) \
   stable"

apt-get update
apt-get -y install docker-ce docker-ce-cli containerd.io

apt-cache madison docker-ce

echo
echo Docker CE updated!
echo

echo Updating Docker Compose to 2.17.4...
echo

apt-get remove docker-compose >/dev/null 2>&1
rm /usr/local/bin/docker-compose >/dev/null 2>&1
rm /usr/bin/docker-compose >/dev/null 2>&1
pip uninstall docker-compose >/dev/null 2>&1
pip3 uninstall docker-compose >/dev/null 2>&1

# The latest version is not compatible with Ubuntu 16, so the 1.27.4 will be installed.
#VERSION=$(curl --silent https://api.github.com/repos/docker/compose/releases/latest | jq .name -r)

DESTINATION=/usr/local/bin/docker-compose
curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-$(uname -s)-$(uname -m)" -o ${DESTINATION}

chmod +x ${DESTINATION}
ln -s /usr/local/bin/docker-compose /usr/bin/docker-compose

echo
echo Docker Compose Updated!
