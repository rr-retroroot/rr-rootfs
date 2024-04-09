#!/bin/bash

#set -xe

# messages
function merror() {
  printf '\033[1;31mERROR:\033[0m %s\n' "$@" >&2 # bold red
}

function minfo() {
  printf '\033[1;92m%s\033[0m\n' "$@" >&2 # bold cyan
}

# cleanup on exit
function cleanup {
  if [ $? -ne 0 ]; then
    merror 'something went wrong...'
  fi
  umount -lfR "${MOUNT_ROOT}" >/dev/null 2>&1 || :
  losetup -d "${LOOP_DEV}" >/dev/null 2>&1 || :
  rm -d "${MOUNT_ROOT}" >/dev/null 2>&1 || :
}

# set exit trap
trap cleanup EXIT

# mount_image
function mount_image() {
  minfo "mount_image: ${RR_OUTPUT_IMG}"
  
  if [ ! -f "${RR_OUTPUT_IMG}" ]; then
    merror "mount_image: image does not exist..."
    exit 1;
  fi
  
  LOOP_DEV=$(losetup --partscan --show --find "${RR_OUTPUT_IMG}")
  BOOT_DEV="$LOOP_DEV"p1
  ROOT_DEV="$LOOP_DEV"p2
  
  # set mount paths
  MOUNT_ROOT="${RR_ROOT_PATH}"/output/rootfs
  MOUNT_BOOT="${RR_ROOT_PATH}"/output/rootfs/boot
  MOUNT_RR="${RR_ROOT_PATH}"/output/rootfs/retroroot

  # mount partitions
  mkdir -p "${MOUNT_ROOT}"
  mount --make-private "${ROOT_DEV}" "${MOUNT_ROOT}"
  mkdir -p "${MOUNT_BOOT}"
  mount --make-private "${BOOT_DEV}" "${MOUNT_BOOT}"
  # mount retroroot build stuff
  mkdir -p "${MOUNT_RR}"
  mount --make-private --bind "${RR_ROOT_PATH}" "${MOUNT_RR}"
}

function umount_image() {
  minfo "umount_image: ${RR_OUTPUT_IMG} (mounted on ${LOOP_DEV})"
  umount -lfR "${MOUNT_ROOT}" >/dev/null 2>&1 || :
  losetup -d "${LOOP_DEV}" >/dev/null 2>&1 || :
}

# create_image
function create_image() {
  minfo "create_image: ${RR_OUTPUT_IMG}"

  if [ ! -f "${RR_OUTPUT_IMG}" ]; then
    if [ "${PLATFORM}" == "sysroot" ]; then
      # "sysroot" platform is used for cross compilation of packages, use a bigger image
      dd if=/dev/zero of="${RR_OUTPUT_IMG}" bs=1M count=4096
    else
      dd if=/dev/zero of="${RR_OUTPUT_IMG}" bs=1M count=3072
    fi
  fi
  
  # create "RR-BOOT" partition
  parted -a optimal -s "${RR_OUTPUT_IMG}" mklabel gpt
  # TODO: revert this for rg353v
  #parted -a optimal -s ${RR_OUTPUT_IMG} unit s mkpart uboot 16384 24575
  #parted -a optimal -s ${RR_OUTPUT_IMG} unit s mkpart resource 24576 32767
  parted -a optimal -s "${RR_OUTPUT_IMG}" mkpart primary fat32 0% 256MiB
  
  # create "RR-ROOT" partition
  if [ "${PLATFORM}" == "surfacert" ]; then
    # TODO: fix ext4 on surfacert
    parted -a optimal -s "${RR_OUTPUT_IMG}" mkpart primary ext3 256MiB 100%
  else
    parted -a optimal -s "${RR_OUTPUT_IMG}" mkpart primary ext4 256MiB 100%
  fi
  
  # mount image
  LOOP_DEV=$(losetup --partscan --show --find "${RR_OUTPUT_IMG}")
  BOOT_DEV="$LOOP_DEV"p1
  ROOT_DEV="$LOOP_DEV"p2

  # format "RR-BOOT" partition
  mkfs.fat -F32 -n RR-BOOT "${BOOT_DEV}"

  # format "RR-ROOT" partition
  if [ "${RR_PLATFORM}" == "surfacert" ]; then
    mke2fs -t ext3 -L RR-ROOT -F "${ROOT_DEV}"
  else
    mke2fs -t ext4 -L RR-ROOT -F "${ROOT_DEV}"
  fi
  
  # umount
  losetup -d "${LOOP_DEV}" >/dev/null 2>&1 || :
}

function install_package() {
  minfo "installing packages to $(basename -- ${RR_OUTPUT_IMG}): ${RR_PACKAGES}"
  mount_image
  arch-chroot ${MOUNT_ROOT} pacman -S --noconfirm --needed $1
  umount_image
}

