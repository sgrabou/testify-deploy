#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./config.sh

PROGRAM=$(basename "$0")

WORK_DIR=$(pwd)

CONFIRM_MSG="All unused containers, images, and volumes will be deleted. Are you sure you want to continue (y/n)?"

echo
read -p "${CONFIRM_MSG}" choice
echo
case "$choice" in
y | Y) echo "Reclaiming space..." ;;
n | N) exit 0 ;;
*) exit 0 ;;
esac

docker system prune -a --volumes -f
validateReturnCode

echo
echo "Operation completed successfully!"
echo
