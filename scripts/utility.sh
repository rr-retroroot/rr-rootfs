#!/bin/bash

set -e

# messages
function merror() {
  printf '\033[1;31mERROR:\033[0m %s\n' "$@" >&2 # bold red
}

function minfo() {
  printf '\033[1;92m%s\033[0m\n' "$@" >&2 # bold cyan
}

# cleanup on exit
function image_cleanup {
  if [ "${RR_DO_MOUNT}" == 1 ]; then
    return 0
  fi

  if [ $? -ne 0 ]; then
    merror 'something went wrong...'
  fi
  sudo umount -lfR "${MOUNT_ROOT}" >/dev/null 2>&1 || :
  sudo losetup -d "${LOOP_DEV}" >/dev/null 2>&1 || :
  rm -d "${MOUNT_ROOT}" >/dev/null 2>&1 || :
}

# set exit trap
trap image_cleanup EXIT

# mount_image
function mount_image() {
  minfo "mount_image: ${RR_OUTPUT_IMG}"
  
  if [ ! -f "${RR_OUTPUT_IMG}" ]; then
    merror "mount_image: image does not exist..."
    exit 1;
  fi
  
  LOOP_DEV=$(sudo losetup --partscan --show --find "${RR_OUTPUT_IMG}")
  BOOT_DEV="$LOOP_DEV"p1
  ROOT_DEV="$LOOP_DEV"p2
  
  # set mount paths
  MOUNT_ROOT="${RR_ROOT_PATH}"/output/rootfs
  MOUNT_BOOT="${RR_ROOT_PATH}"/output/rootfs/boot
  MOUNT_RR="${RR_ROOT_PATH}"/output/rootfs/retroroot

  # mount partitions
  mkdir -p "${MOUNT_ROOT}"
  sudo mount --make-private "${ROOT_DEV}" "${MOUNT_ROOT}"
  sudo mkdir -p "${MOUNT_BOOT}"
  sudo mount --make-private "${BOOT_DEV}" "${MOUNT_BOOT}"
  # mount retroroot build stuff
  sudo mkdir -p "${MOUNT_RR}"
  sudo mount --make-private --bind "${RR_ROOT_PATH}" "${MOUNT_RR}"
}

function umount_image() {
  minfo "umount_image: ${RR_OUTPUT_IMG} (mounted on ${LOOP_DEV})"
  sudo umount -lfR "${MOUNT_ROOT}" >/dev/null 2>&1 || :
  sudo losetup -d "${LOOP_DEV}" >/dev/null 2>&1 || :
}

# create_image
function create_image() {
  minfo "create_image: ${RR_OUTPUT_IMG}"
  
  if [ "${RR_PLATFORM}" == "desktop" ]; then
    # so we can (re)create rootfs overlay partition from initramfs
    # even after expending the image for testing
    rm -f "${RR_OUTPUT_IMG}"
  fi

  if [ ! -f "${RR_OUTPUT_IMG}" ]; then
    minfo "create_image: creating image with dd (${RR_OUTPUT_IMG})"
    if [ "${RR_PLATFORM}" == "sysroot" ]; then
      # "sysroot" platform is used for cross compilation of packages, use a bigger image
      dd if=/dev/zero of="${RR_OUTPUT_IMG}" bs=1M count=4096 >/dev/null 2>&1 || :
    else
      dd if=/dev/zero of="${RR_OUTPUT_IMG}" bs=1M count=2048 >/dev/null 2>&1 || :
    fi
  fi
  
  # create "RR-BOOT" partition
  if [ "${RR_PLATFORM}" == "surfacert" ]; then
    parted -a optimal -s "${RR_OUTPUT_IMG}" mklabel gpt
  else
    parted -a optimal -s "${RR_OUTPUT_IMG}" mklabel msdos
  fi
  parted -a optimal -s "${RR_OUTPUT_IMG}" mkpart primary fat32 0% 256MiB
  parted -a optimal -s "${RR_OUTPUT_IMG}" set 1 boot on

  # create "RR-ROOT" partition
  if [ "${RR_PLATFORM}" == "surfacert" ]; then
    # TODO: fix ext4 on surfacert
    parted -a optimal -s "${RR_OUTPUT_IMG}" mkpart primary ext3 256MiB 100%
  else
    parted -a optimal -s "${RR_OUTPUT_IMG}" mkpart primary ext4 256MiB 100%
  fi
  
  # mount image
  LOOP_DEV=$(sudo losetup --partscan --show --find "${RR_OUTPUT_IMG}")
  BOOT_DEV="$LOOP_DEV"p1
  ROOT_DEV="$LOOP_DEV"p2

  # format "RR-BOOT" partition
  minfo "create_image: formating boot partiton (${BOOT_DEV})"
  sudo mkfs.fat -F32 -n RR-BOOT "${BOOT_DEV}" >/dev/null 2>&1 || :

  # format "RR-ROOT" partition
  minfo "create_image: formating root partiton (${ROOT_DEV})"
  if [ "${RR_PLATFORM}" == "surfacert" ]; then
    sudo mke2fs -t ext3 -L RR-ROOT -F "${ROOT_DEV}" >/dev/null 2>&1 || :
  else
    sudo mke2fs -t ext4 -L RR-ROOT -F "${ROOT_DEV}" >/dev/null 2>&1 || :
  fi
  
  # umount
  sudo losetup -d "${LOOP_DEV}" >/dev/null 2>&1 || :
}

function create_rootfs() {
  # create minimal rootfs with pacstrap and specifed packages
  minfo "create_rootfs: running pacstrap"
  sudo pacstrap -c -K -M -G -C "${RR_ROOT_PATH}"/packages/system/rr-base/overlay/etc/pacman-"${RR_ARCH}".conf ${MOUNT_ROOT} rr-base-${RR_PLATFORM}
  # TODO: https://gitlab.archlinux.org/archlinux/arch-install-scripts/-/issues/56
  sudo killall gpg-agent
}

function install_package() {
  minfo "install_package: installing packages to $(basename -- ${RR_OUTPUT_IMG}): ${RR_PACKAGES}"
  mount_image
  minfo "install_package: chroot..."
  sudo arch-chroot ${MOUNT_ROOT} pacman -S --noconfirm --needed $1
  umount_image
}

