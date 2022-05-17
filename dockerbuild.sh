#!/bin/bash

set -xe

# messages
merror() {
  printf '\033[1;31mERROR:\033[0m %s\n' "$@" >&2  # bold red
}

minfo() {
  printf '\n\033[1;36m> %s\033[0m\n' "$@" >&2  # bold cyan
}

# cleanup on exit
function cleanup {
  if [ $? -ne 0 ]; then
    merror 'something went wrong, exiting...'
  fi
  umount -lf ${MOUNT_ROOT}/dev/pts
  umount -lf ${MOUNT_ROOT}/dev
  umount -lf ${MOUNT_ROOT}/sys
  umount -lf ${MOUNT_ROOT}/proc
  umount -lf ${MOUNT_BOOT}
  umount -lf ${MOUNT_ROOT}
  losetup -d "$LOOP_DEV"
}

# set exit trap
trap cleanup EXIT

# let's go...
minfo "rr: platform: ${RR_PLATFORM}"
minfo "rr: arch: ${RR_ARCH}"

# first build base rootfs, will be used for later builds
RR_BOOTFS_TARBALL="${RR_OUTPUT_DIR}/arch-bootfs-${RR_PLATFORM}-${RR_ARCH}.tgz"
RR_ROOTFS_TARBALL="${RR_OUTPUT_DIR}/arch-rootfs-${RR_PLATFORM}-${RR_ARCH}.tgz"

if [[ ! -f "${RR_ROOTFS_TARBALL}" ]]; then
  ./arch-rootfs/arch-bootstrap.sh \
    -a ${RR_ARCH} "${RR_OUTPUT_DIR}/arch-rootfs-${RR_PLATFORM}-${RR_ARCH}"
  # create bootfs and rootfs tarball
  tar czf "${RR_BOOTFS_TARBALL}" \
    --directory="${RR_OUTPUT_DIR}/arch-rootfs-${RR_PLATFORM}-${RR_ARCH}/boot" .
  # cleanup rootfs
  rm -rf "${RR_OUTPUT_DIR}/arch-rootfs-${RR_PLATFORM}-${RR_ARCH}/boot"
  rm -rf "${RR_OUTPUT_DIR}/arch-rootfs-${RR_PLATFORM}-${RR_ARCH}/var/cache/pacman/pkg"
  tar czf "${RR_ROOTFS_TARBALL}" \
    --directory="${RR_OUTPUT_DIR}/arch-rootfs-${RR_PLATFORM}-${RR_ARCH}" .
  chmod 777 ${RR_BOOTFS_TARBALL} ${RR_ROOTFS_TARBALL}
fi

exit 1

# set output image path
OUTPUT_IMG=${RR_OUTPUT_DIR}/retroroot-${RR_PLATFORM}-${RR_ARCH}.img

# set mount paths
MOUNT_ROOT=${RR_OUTPUT_DIR}/rootfs
MOUNT_BOOT=${MOUNT_ROOT}/boot

# create image and partitions
dd if=/dev/zero of=$OUTPUT_IMG bs=1M count=2048
parted ${OUTPUT_IMG} -- \
  mklabel msdos \
  mkpart primary fat32 1 256 \
  mkpart primary ext2 256 -1s \
  unit B

# format partitions
LOOP_DEV=$(losetup --partscan --show --find "${OUTPUT_IMG}")
BOOT_DEV="$LOOP_DEV"p1
ROOT_DEV="$LOOP_DEV"p2
mkfs.fat -F32 -n RR-BOOT "$BOOT_DEV"
mkfs.ext4 -L RR-ROOT "$ROOT_DEV"

# mount partitions
mkdir -p ${MOUNT_ROOT}
mount --make-private ${ROOT_DEV} ${MOUNT_ROOT}
mkdir -p ${MOUNT_BOOT}
mount --make-private ${BOOT_DEV} ${MOUNT_BOOT}

# mount binding
mkdir -p ${MOUNT_ROOT}/proc ${MOUNT_ROOT}/sys
mount --bind /proc ${MOUNT_ROOT}/proc
mount --bind /sys ${MOUNT_ROOT}/sys

# extract base rootfs
tar zxf "${RR_ROOTFS_TARBALL}" -C ${MOUNT_ROOT}
tar zxf "${RR_ROOTFS_TARBALL}" -C ${MOUNT_ROOT}/boot

# copy platform config and bootstrap files
cp -r configs ${MOUNT_ROOT}
cp -r overlays ${MOUNT_ROOT}
cp -r bootstrap ${MOUNT_ROOT}

# chroot
mount --bind /dev ${MOUNT_ROOT}/dev
mount --bind /dev/pts ${MOUNT_ROOT}/dev/pts
chroot ${MOUNT_ROOT} run-parts --exit-on-error -a ${RR_PLATFORM} -a ${RR_ARCH} /bootstrap/
