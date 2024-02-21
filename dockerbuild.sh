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
  losetup -d "$LOOP_DEV" > /dev/null 2>&1 || :
}

# set exit trap
trap cleanup EXIT

pack_sysroot() {
  OUTPUT_SYS="${RR_OUTPUT_DIR}/retroroot-sysroot-${RR_ARCH}/opt/retroroot/target/${RR_ARCH}"
  OUTPUT_TARBALL="${RR_OUTPUT_DIR}/retroroot-sysroot-${RR_ARCH}.tar.xz"

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

  # cleanup
  rm -f ${OUTPUT_SYS}/usr/bin/i686-pc-linux-gnu-pkg-config
  rm -f ${OUTPUT_SYS}/usr/bin/x86_64-pc-linux-gnu-pkg-config
  rm -f ${OUTPUT_SYS}/usr/bin/pkg-config
  rm -f ${OUTPUT_SYS}/usr/bin/alsoft-config
  rm -f ${OUTPUT_SYS}/usr/lib/terminfo
  rm -rf ${OUTPUT_SYS}/usr/lib/awk
  rm -rf ${OUTPUT_SYS}/usr/lib/bash
  rm -rf ${OUTPUT_SYS}/usr/lib/binfmt.d
  rm -rf ${OUTPUT_SYS}/usr/lib/depmod.d
  rm -rf ${OUTPUT_SYS}/usr/lib/dri
  rm -rf ${OUTPUT_SYS}/usr/lib/e2fsprogs
  rm -rf ${OUTPUT_SYS}/usr/lib/environment.d
  rm -rf ${OUTPUT_SYS}/usr/lib/firmware
  rm -rf ${OUTPUT_SYS}/usr/lib/gnupg
  rm -rf ${OUTPUT_SYS}/usr/lib/initcpio
  rm -rf ${OUTPUT_SYS}/usr/lib/kernel
  rm -rf ${OUTPUT_SYS}/usr/lib/modules
  rm -rf ${OUTPUT_SYS}/usr/lib/p11-kit
  rm -rf ${OUTPUT_SYS}/usr/lib/syslinux
  rm -rf ${OUTPUT_SYS}/usr/lib/systemd
  rm -rf ${OUTPUT_SYS}/usr/lib/tmpfiles.d
  rm -rf ${OUTPUT_SYS}/usr/lib/udev
  rm -rf ${OUTPUT_SYS}/usr/lib/xkbcommon

  # fix links
  rm -f ${OUTPUT_SYS}/usr/lib/libGLX_indirect.so.0
  ln -s libGLX_mesa.so.0 ${OUTPUT_SYS}/usr/lib/libGLX_indirect.so.0
  rm -f ${OUTPUT_SYS}/usr/lib/libkeyutils.so
  ln -s libkeyutils.so.1 ${OUTPUT_SYS}/usr/lib/libkeyutils.so
  rm -f ${OUTPUT_SYS}/usr/lib/liblua5.4.so
  ln -s liblua.so.5.4.4 ${OUTPUT_SYS}/usr/lib/liblua5.4.so

  # fix /usr/bin paths
  find ${OUTPUT_SYS}/usr/bin -type f -print0 | xargs -0 sed -i \
    "s|/usr|/opt/retroroot/target/${RR_ARCH}/usr|g"

  # pack sysroot
  tar -c -I 'xz -5 -T0' -f "${OUTPUT_TARBALL}" --directory="${RR_OUTPUT_DIR}/retroroot-sysroot-${RR_ARCH}" .
  rm -rf "${RR_OUTPUT_DIR}/retroroot-sysroot-${RR_ARCH}"
}

main() {
  # let's go...
  minfo "rr: platform: ${RR_PLATFORM}"
  minfo "rr: arch: ${RR_ARCH}"

  # ...
  chmod -R 777 ${RR_OUTPUT_DIR}

  # set output image path
  OUTPUT_IMG=${RR_OUTPUT_DIR}/retroroot-${RR_PLATFORM}-${RR_ARCH}.img

  # create output image
  dd if=/dev/zero of=${OUTPUT_IMG} bs=1M count=2048

  # create "RR-BOOT" partition
  parted -a optimal -s ${OUTPUT_IMG} mklabel gpt
  parted -a optimal -s ${OUTPUT_IMG} unit s mkpart uboot 16384 24575
  parted -a optimal -s ${OUTPUT_IMG} unit s mkpart resource 24576 32767
  parted -a optimal -s ${OUTPUT_IMG} mkpart primary fat32 1% 1024MiB

  # format "RR-BOOT" partition
  chmod 777 ${OUTPUT_IMG}
  LOOP_DEV=$(losetup --partscan --show --find "${OUTPUT_IMG}")
  BOOT_DEV="$LOOP_DEV"p3
  mkfs.fat -F32 -n RR-BOOT "$BOOT_DEV"

  # set mount paths
  MOUNT_ROOT=/tmp/rootfs
  MOUNT_BOOT=/tmp/rootfs/boot
  rm -rf ${MOUNT_ROOT}

  # mount partitions
  mkdir -p ${MOUNT_BOOT}
  mount --make-private ${BOOT_DEV} ${MOUNT_BOOT}
  
  minfo "rr: running pacstrap with packages:"
  minfo "${RR_PACKAGES}"

  pacstrap -C configs/pacman-${RR_ARCH}.conf -c ${MOUNT_ROOT} ${RR_PACKAGES}

  # copy config and bootstrap files
  cp -r bootstrap ${MOUNT_ROOT}
  cp -r configs ${MOUNT_ROOT}

  # process retroroot installation and configuration
  arch-chroot ${MOUNT_ROOT} run-parts --exit-on-error -a ${RR_PLATFORM} -a ${RR_ARCH} /bootstrap

  # generate squashfs
  mksquashfs ${MOUNT_ROOT} ${MOUNT_BOOT}/rootfs.sqsh -noappend -e boot

  # TODO: add rr-rootfs.sh toolchain build argument
  # package toolchain
  #pack_sysroot
}

main "$@"

