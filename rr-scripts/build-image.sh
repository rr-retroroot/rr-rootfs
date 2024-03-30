#!/bin/bash

set -xe

# messages
function merror() {
  printf '\033[1;31mERROR:\033[0m %s\n' "$@" >&2 # bold red
}

function minfo() {
  printf '\033[1;36m> %s\033[0m\n' "$@" >&2 # bold cyan
}

# cleanup on exit
function cleanup {
  if [ $? -ne 0 ]; then
    merror 'something went wrong, exiting...'
  fi
  umount -lfR "${MOUNT_ROOT}" >/dev/null 2>&1 || :
  losetup -d "${LOOP_DEV}" >/dev/null 2>&1 || :
}

# set exit trap
trap cleanup EXIT

function build_image() {
  RR_ARCH=$1
  RR_PLATFORM=$2
  RR_ROOT_PATH=$3
  RR_DO_CHROOT=$4

  # let's go...
  minfo "rr: platform: ${RR_PLATFORM}"
  minfo "rr: arch: ${RR_ARCH}"

  # ...
  #chmod -R 777 ${ROOT_DIR}

  # set output image path
  OUTPUT_IMG="${RR_ROOT_PATH}"/output/retroroot-${RR_PLATFORM}-${RR_ARCH}.img
  minfo "rr: output image: ${OUTPUT_IMG}"

  # create output image
  if [ ! -f "${OUTPUT_IMG}" ]; then
    dd if=/dev/zero of="${OUTPUT_IMG}" bs=1M count=4096
  fi

  if [ ! "${RR_DO_CHROOT}" ]; then
    # create "RR-BOOT" partition
    parted -a optimal -s "${OUTPUT_IMG}" mklabel gpt
    # TODO: revert this for rg353v ?
    #parted -a optimal -s ${OUTPUT_IMG} unit s mkpart uboot 16384 24575
    #parted -a optimal -s ${OUTPUT_IMG} unit s mkpart resource 24576 32767
    parted -a optimal -s "${OUTPUT_IMG}" mkpart primary fat32 0% 256MiB
    # create "RR-ROOT" partition
    if [ "${RR_PLATFORM}" == "surfacert" ]; then
      parted -a optimal -s "${OUTPUT_IMG}" mkpart primary ext3 256MiB 100%
    else
      parted -a optimal -s "${OUTPUT_IMG}" mkpart primary ext4 256MiB 100%
    fi
  fi

  # mount image
  LOOP_DEV=$(losetup --partscan --show --find "${OUTPUT_IMG}")
  BOOT_DEV="$LOOP_DEV"p1
  ROOT_DEV="$LOOP_DEV"p2

  if [ ! "${RR_DO_CHROOT}" ]; then
    # format "RR-BOOT" partition
    mkfs.fat -F32 -n RR-BOOT "${BOOT_DEV}"
    # format "RR-ROOT" partition
    if [ "${RR_PLATFORM}" == "surfacert" ]; then
      mke2fs -t ext3 -L RR-ROOT -F "${ROOT_DEV}"
    else
      mke2fs -t ext4 -L RR-ROOT -F "${ROOT_DEV}"
    fi
  fi

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

  # extract rootfs
  if [ ! "${RR_DO_CHROOT}" ]; then
    if [ ! -f "${RR_ROOT_PATH}"/output/archlinux-bootstrap-"${RR_ARCH}".tar.gz ]; then
      minfo "rr: downloading arch bootstrap tarball..."
      wget http://retroroot.mydedibox.fr/misc/archlinux-bootstrap-"${RR_ARCH}".tar.gz \
        -O "${RR_ROOT_PATH}"/output/archlinux-bootstrap-"${RR_ARCH}".tar.gz
    fi
    minfo "rr: extracting arch bootstrap tarball..."
    tar zxf "${RR_ROOT_PATH}"/output/archlinux-bootstrap-"${RR_ARCH}".tar.gz --numeric-owner -C "${MOUNT_ROOT}" >/dev/null 2>&1 || :
    # copy custom config
    cp -f "${RR_ROOT_PATH}"/configs/pacman-"${RR_ARCH}".conf "${MOUNT_ROOT}"/etc/pacman.conf
    rm -f "${MOUNT_ROOT}"/etc/resolv.conf
    cp -f /etc/resolv.conf "${MOUNT_ROOT}"/etc/resolv.conf
  fi

  minfo "rr: running container with packages:"
  minfo "${RR_PACKAGES}"

  if [ "${RR_DO_CHROOT}" ]; then
    if [ "${RR_ARCH}" == "armv7h" ]; then
      systemd-nspawn --bind "$(which qemu-arm-static)" -b -D "${MOUNT_ROOT}"
    elif [ "${RR_ARCH}" == "aarch64" ]; then
      systemd-nspawn --bind "$(which qemu-aarch64-static)" -b -D "${MOUNT_ROOT}"
    else
      systemd-nspawn -b -D "${MOUNT_ROOT}"
    fi
  else
    if [ "${RR_ARCH}" == "armv7h" ]; then
      systemd-nspawn --bind "$(which qemu-arm-static)" -D "${MOUNT_ROOT}" \
        -E RR_PLATFORM="${RR_PLATFORM}" -E RR_ARCH="${RR_ARCH}" \
        /bin/bash -c /retroroot/bootstrap/00-system
    elif [ "${RR_ARCH}" == "aarch64" ]; then
      systemd-nspawn --bind "$(which qemu-aarch64-static)" -D "${MOUNT_ROOT}" \
        -E RR_PLATFORM="${RR_PLATFORM}" -E RR_ARCH="${RR_ARCH}" \
        /bin/bash -c /retroroot/bootstrap/00-system
    else
      systemd-nspawn -D "${MOUNT_ROOT}" \
        -E RR_PLATFORM="${RR_PLATFORM}" -E RR_ARCH="${RR_ARCH}" \
        /bin/bash -c /retroroot/bootstrap/00-system
    fi
  fi
}
