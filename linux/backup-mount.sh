#!/usr/bin/env bash

cd "$(dirname "${BASH_SOURCE[0]}")"
source ./config.sh

PROGRAM=$(basename "$0")

REBOOT_MOUNT_FILE="/etc/fstab"
REBOOT_MOUNT_FILE_OLD="/etc/fstab.old"

usage() {
  echo "Usage: ${PROGRAM} [-e|-d] nfshare"
  echo "  -e, --enable"
  echo "        Enable a mounted drive for the backups, default behavior"
  echo "         Cannot be used at the same time as '-d'"
  echo "  -d, --disable"
  echo "        Disable the mounted drive for the backups"
  echo "         Cannot be used at the same time as '-e'"
  echo "  nfshare"
  echo "        The address of the nfs share to be used to mount to"
  echo "        the backup directory. No impact when disabling..."
  echo
  echo "Example: sudo ./backup-mount.sh iw-freenas.testify.lan:/mnt/iw-zfs/testify_product/ct_backup"
  echo
  exit 1
}

while [[ -n "$1" ]]; do

  case "$1" in
  -e | --enable)
    if ! [[ -z ${DISABLE} ]]; then
      echo
      echo "Cannot enable and disable mounted drive..."
      exit 1
    fi

    # Default behavior
    echo
    echo "Enabling mount of backup drive..."
    ENABLE="true"
    shift
    ;;
  -d | --disable)
    if ! [[ -z ${ENABLE} ]]; then
      echo
      echo "Cannot disable and enable mounted drive..."
      exit 1
    fi

    echo
    echo "Disabling mount of backup drive..."
    DISABLE="true"
    shift
    ;;
  *)
    if [[ -n "$2" ]]; then
      err ""
      err "Unexpected parameter..."
      usage
    fi
    NFS_SHARE=${1}
    echo
    echo "Binding ${NFS_SHARE} to backup directory..."
    shift
    ;;
  esac

done

if [[ -z ${NFS_SHARE} ]] && [[ -z ${DISABLE} ]]; then
  err ""
  err "Must specify a share to mount !"
  err ""
  usage
fi

if [[ -z ${DEFAULT_BACKUP_ROOT} ]]; then
  err ""
  err "Backup directory was undefined."
  err "Scripts might have been corrupted !"
  err "  Aborting..."-
  err ""
  exit 2
fi

cp ${REBOOT_MOUNT_FILE} ${REBOOT_MOUNT_FILE_OLD}

if [[ -z ${DISABLE} ]]; then

  if grep -qs "${DEFAULT_BACKUP_ROOT} " /proc/mounts; then
    echo
    echo "Backup directory is already mounted !"
    exit 1
  fi

  echo "${NFS_SHARE} ${DEFAULT_BACKUP_ROOT}    nfs      rsize=8192,wsize=8192,timeo=14,intr,bg" >>${REBOOT_MOUNT_FILE}
  mount ${NFS_SHARE} ${DEFAULT_BACKUP_ROOT}

  echo "Binding successful"
  echo
else
  sed -i "\&${DEFAULT_BACKUP_ROOT}&d" ${REBOOT_MOUNT_FILE}
  umount ${DEFAULT_BACKUP_ROOT}

  echo "Unbinding successful"
  echo
fi
