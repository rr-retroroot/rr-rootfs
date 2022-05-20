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
  chmod -R 777 ${RR_OUTPUT_DIR}
  umount -lf ${MOUNT_BOOT} > /dev/null 2>&1 || :
  umount -lf ${MOUNT_ROOT} > /dev/null 2>&1 || :
  losetup -d "$LOOP_DEV" > /dev/null 2>&1 || :
}

# set exit trap
trap cleanup EXIT

pack_sysroot() {
  OUTPUT_SYS="${RR_OUTPUT_DIR}/retroroot-sysroot-${RR_PLATFORM}-${RR_ARCH}/opt/pacbrew/retroroot/target/${RR_ARCH}"
  OUTPUT_TARBALL="${RR_OUTPUT_DIR}/retroroot-sysroot-${RR_PLATFORM}-${RR_ARCH}.tar.xz"
  
  minfo "rr: generating sysroot taball: ${OUTPUT_TARBALL}"

  rm -rf "${OUTPUT_TARBALL}"
  rm -rf "${OUTPUT_SYS}"

  # create target directories
  mkdir -p ${OUTPUT_SYS}/usr/bin
  mkdir -p ${OUTPUT_SYS}/usr/share

  # copy sysroot files
  cp -r ${MOUNT_ROOT}/usr/lib ${OUTPUT_SYS}/usr
  cp -r ${MOUNT_ROOT}/usr/include ${OUTPUT_SYS}/usr
  cp -r ${MOUNT_ROOT}/usr/bin/*-config ${OUTPUT_SYS}/usr/bin/
  cp -r ${MOUNT_ROOT}/usr/share/pkgconfig ${OUTPUT_SYS}/usr/share
  cp -r ${MOUNT_ROOT}/usr/share/cmake ${OUTPUT_SYS}/usr/share

  # remove unwanted files
  rm -f ${OUTPUT_SYS}/usr/bin/i686-pc-linux-gnu-pkg-config
  rm -f ${OUTPUT_SYS}/usr/bin/x86_64-pc-linux-gnu-pkg-config
  rm -f ${OUTPUT_SYS}/usr/bin/pkg-config
  rm -f ${OUTPUT_SYS}/usr/bin/alsoft-config

  # fix paths
  find ${OUTPUT_SYS}/usr/bin -type f -print0 | xargs -0 sed -i \
    "s|/usr|/opt/pacbrew/retroroot/target/${RR_ARCH}/usr|g"
  find ${OUTPUT_SYS}/usr/lib/cmake -type f -print0 | xargs -0 sed -i \
    "s|/usr|/opt/pacbrew/retroroot/target/${RR_ARCH}/usr|g"
  find ${OUTPUT_SYS}/usr/share/cmake -type f -print0 | xargs -0 sed -i \
    "s|/usr|/opt/pacbrew/retroroot/target/${RR_ARCH}/usr|g"

  # pack sysroot
  tar cfJ "${OUTPUT_TARBALL}" --directory="${RR_OUTPUT_DIR}/retroroot-sysroot-${RR_PLATFORM}-${RR_ARCH}" .
  rm -rf "${OUTPUT_SYS}"
}

main() {
  # let's go...
  minfo "rr: platform: ${RR_PLATFORM}"
  minfo "rr: arch: ${RR_ARCH}"

  # ...
  chmod -R 777 ${RR_OUTPUT_DIR}

  # set output image path
  OUTPUT_IMG=${RR_OUTPUT_DIR}/retroroot-${RR_PLATFORM}-${RR_ARCH}.img

  # create image and partitions
  dd if=/dev/zero of=${OUTPUT_IMG} bs=1M count=4096
  parted ${OUTPUT_IMG} -- \
    mklabel msdos \
    mkpart primary fat32 1 256 \
    mkpart primary ext2 256 -1s \
    unit B

  # format partitions
  chmod 777 ${OUTPUT_IMG}
  LOOP_DEV=$(losetup --partscan --show --find "${OUTPUT_IMG}")
  BOOT_DEV="$LOOP_DEV"p1
  ROOT_DEV="$LOOP_DEV"p2
  mkfs.fat -F32 -n RR-BOOT "$BOOT_DEV"
  mkfs.ext4 -L RR-ROOT "$ROOT_DEV"

  # set mount paths
  MOUNT_ROOT=/tmp/rootfs
  MOUNT_BOOT=/tmp/rootfs/boot
  rm -rf ${MOUNT_BOOT}

  # mount partitions
  mkdir -p ${MOUNT_ROOT}
  mount --make-private ${ROOT_DEV} ${MOUNT_ROOT}
  mkdir -p ${MOUNT_BOOT}
  mount --make-private ${BOOT_DEV} ${MOUNT_BOOT}

  pacstrap -c ${MOUNT_ROOT} ${RR_PACKAGES}

  # copy platform config and bootstrap files
  cp -r bootstrap ${MOUNT_ROOT}
  cp -r configs ${MOUNT_ROOT}
  cp -r overlays ${MOUNT_ROOT}

  # process retroroot installation and configuration
  arch-chroot ${MOUNT_ROOT} run-parts --exit-on-error -a ${RR_PLATFORM} -a ${RR_ARCH} /bootstrap/
  
  # package toolchain
  pack_sysroot
}

main "$@"

