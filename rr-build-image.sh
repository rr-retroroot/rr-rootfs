#!/bin/bash

# get root privileges...
#[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"

# set default variables
RR_ARCH=""
RR_PLATFORM=""
RR_ROOT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
RR_OUTPUT_IMG=""
RR_DO_CHROOT=0

# source build scripts
source scripts/utility.sh

show_usage() {
  echo ""
  echo "usage: $(basename "$0") [-a x86_64|armv7h|aarch64] [-p desktop|rpi|rg353|surfacert|sysroot] [-i packages] [-c]"
  echo ""
  echo "examples:"
  echo "       $(basename "$0") -a x86_64 -p desktop                      | build x86_64 desktop image"
  echo "       $(basename "$0") -a armv7h -p surfacert                    | build armv7h surfacert image"
  echo "       $(basename "$0") -a x86_64 -p desktop -c                   | chroot desktop platform image"
  echo "       $(basename "$0") -a x86_64 -p desktop -i \"base-devel git\"  | install specified packages into image"
}

run() {
  if [ "$1" == "desktop" ]; then
    qemu-img resize -f raw "output/retroroot-x86_64-desktop.img" 4G
    qemu-system-x86_64 -m 2G -smp 4 \
      -serial stdio \
      -device virtio-vga-gl -display sdl,gl=on \
      -device e1000,netdev=net0 -netdev user,id=net0,hostfwd=tcp::5555-:22 \
      -usbdevice mouse \
      -drive format=raw,file="output/retroroot-x86_64-desktop.img"
  else
    echo "TODO"
  fi
}

main() {
  # parse args
  test $# -eq 0 && set -- "-h"
  while getopts "a:p:i:ch" ARG; do
    case "$ARG" in
    a) RR_ARCH=$OPTARG ;;
    p) RR_PLATFORM=$OPTARG ;;
    i) RR_PACKAGES=$OPTARG ;;
    c) RR_DO_CHROOT=1 ;;
    *)
      show_usage
      return 0
      ;;
    esac
  done
  shift $(($OPTIND - 1))

  if [ -z ${RR_PLATFORM+x} ]; then
    RR_PLATFORM="sysroot"
  fi

  # shellcheck disable=SC2086
  if [ "$RR_ARCH" != "x86_64" ] && [ "$RR_ARCH" != "armv7h" ] && [ $RR_ARCH != "aarch64" ]; then
    echo "error: supported arch: x86_64, armv7h, aarch64"
    return 1
  fi

  if [ $RR_PLATFORM != "desktop" ] && [ $RR_PLATFORM != "rpi" ] && [ $RR_PLATFORM != "rg353" ] && [ $RR_PLATFORM != "surfacert" ] && [ $RR_PLATFORM != "sysroot" ]; then
    echo "error: supported platform: sysroot, desktop, rpi, rg353, surfacert"
    return 1
  fi

  # setup
  mkdir -p "${RR_ROOT_PATH}"/output
  RR_OUTPUT_IMG="${RR_ROOT_PATH}"/output/retroroot-${RR_ARCH}-${RR_PLATFORM}.img

  minfo "arch: ${RR_ARCH}, platform: ${RR_PLATFORM}, image: ${RR_OUTPUT_IMG}"
  
  if [ ! -z ${RR_PACKAGES+x} ]; then
    install_package "${RR_PACKAGES}"
    exit 0
  fi

  if [ "${RR_DO_CHROOT}" == 1 ]; then
    # chroot image
    mount_image
    minfo "chroot ${MOUNT_ROOT}"
    sudo arch-chroot ${MOUNT_ROOT} /bin/bash
    umount_image
  else
    # create image and rootfs
    create_image
    mount_image
    create_rootfs
		umount_image
  fi
}

main "$@"

