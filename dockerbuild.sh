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
  OUTPUT_SYS=${RR_OUTPUT_DIR}/retroroot-sysroot-${RR_PLATFORM}-${RR_ARCH}.tgz
  
  rm -rf /opt/pacbrew/retroroot/target/${RR_ARCH}

  # create target directories
  mkdir -p /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/bin
  mkdir -p /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/share

  # copy sysroot files
  cp -r /media/cpasjuste/RR-ROOT/usr/lib /opt/pacbrew/retroroot/target/${RR_ARCH}/usr
  cp -r /media/cpasjuste/RR-ROOT/usr/include /opt/pacbrew/retroroot/target/${RR_ARCH}/usr
  cp -r /media/cpasjuste/RR-ROOT/usr/bin/*-config /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/bin/
  cp -r /media/cpasjuste/RR-ROOT/usr/share/pkgconfig /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/share
  cp -r /media/cpasjuste/RR-ROOT/usr/share/cmake /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/share

  # remove unwanted files
  rm -f /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/bin/i686-pc-linux-gnu-pkg-config
  rm -f /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/bin/x86_64-pc-linux-gnu-pkg-config
  rm -f /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/bin/pkg-config
  rm -f /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/bin/alsoft-config

  # fix paths
  sudo find /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/bin -type f -print0 | sudo xargs -0 sed -i \
    "s|/usr|/opt/pacbrew/retroroot/target/${RR_ARCH}/usr|g"
  sudo find /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/lib/cmake -type f -print0 | sudo xargs -0 sed -i \
    "s|/usr|/opt/pacbrew/retroroot/target/${RR_ARCH}/usr|g"
  sudo find /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/share/cmake -type f -print0 | sudo xargs -0 sed -i \
    "s|/usr|/opt/pacbrew/retroroot/target/${RR_ARCH}/usr|g"
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

