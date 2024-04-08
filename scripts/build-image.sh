#!/bin/bash

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
  mkdir -p "${RR_ROOT_PATH}"/output

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
  
  if [ ! "${RR_DO_CHROOT}" ]; then
		minfo "rr: running pacstrap with packages:"
		minfo "${RR_PACKAGES}"
		source "${RR_ROOT_PATH}"/configs/packages
		pacstrap -c -K -M -C "${RR_ROOT_PATH}"/configs/pacman-"${RR_ARCH}".conf ${MOUNT_ROOT} ${RR_PACKAGES}
		cp -f "${RR_ROOT_PATH}"/configs/pacman-"${RR_ARCH}".conf "${MOUNT_ROOT}"/etc/pacman.conf
  fi

  minfo "rr: running container with packages:"
  minfo "${RR_PACKAGES}"

  # chroot requested, proceed
  if [ "${RR_DO_CHROOT}" ]; then
    if [ "${RR_ARCH}" == "armv7h" ]; then
      systemd-nspawn --bind "$(which qemu-arm-static)" \
        --bind="${LOOP_DEV}" --bind="${BOOT_DEV}" --bind="${ROOT_DEV}" \
        -b -D "${MOUNT_ROOT}"
    elif [ "${RR_ARCH}" == "aarch64" ]; then
      systemd-nspawn --bind "$(which qemu-aarch64-static)" \
        --bind="${LOOP_DEV}" --bind="${BOOT_DEV}" --bind="${ROOT_DEV}" \
        -b -D "${MOUNT_ROOT}"
    else
      systemd-nspawn --bind="${LOOP_DEV}" --bind="${BOOT_DEV}" --bind="${ROOT_DEV}" \
        -b -D "${MOUNT_ROOT}"
    fi
  else
    if [ "${RR_ARCH}" == "armv7h" ]; then
      cp -f "$(which qemu-arm-static)" ${MOUNT_ROOT}/usr/bin/
    elif [ "${RR_ARCH}" == "aarch64" ]; then
      cp -f "$(which qemu-aarch64-static)" ${MOUNT_ROOT}/usr/bin/
    fi
    arch-chroot ${MOUNT_ROOT} run-parts --exit-on-error -a "${RR_PLATFORM}" -a "${RR_ARCH}" /retroroot/bootstrap
    rm -f ${MOUNT_ROOT}/usr/bin/qemu-arm-static
    rm -f ${MOUNT_ROOT}/usr/bin/qemu-aarch64-static
  fi
}

