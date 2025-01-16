#!/bin/bash

set -e

# set default variables
RR_ARCH=""
RR_PLATFORM=""
RR_ROOT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
RR_OUTPUT_IMG=""
RR_DO_CHROOT=0

# source helper script
source rr-build-helper.sh

show_usage() {
  echo ""
  echo "usage: $(basename "$0") [-a x86_64|armv7h|aarch64|riscv64] [-p desktop|rpi|rg353|surfacert|retropico|sysroot] [-i packages] [-c]"
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
    qemu-system-x86_64 -enable-kvm -m 1G -smp 4 \
      -serial stdio \
      -device e1000,netdev=net0 -netdev user,id=net0,hostfwd=tcp::2222-:22 \
      -usbdevice mouse \
      -drive format=raw,file="output/retroroot-x86_64-desktop.img"
    #-device virtio-vga-gl -display sdl,gl=on \
  else
    echo "TODO"
  fi
}

main() {
  # parse args
  test $# -eq 0 && set -- "-h"
  while getopts "a:p:i:crh" ARG; do
    case "$ARG" in
    a) RR_ARCH=$OPTARG ;;
    p) RR_PLATFORM=$OPTARG ;;
    i) RR_PACKAGES=$OPTARG ;;
    c) RR_DO_CHROOT=1 ;;
    r)
      run $RR_PLATFORM
      return 0
      ;;
    *)
      show_usage
      return 0
      ;;
    esac
  done
  shift $(($OPTIND - 1))

  if [ -z $RR_PLATFORM ]; then
    RR_PLATFORM="sysroot"
  fi

  # shellcheck disable=SC2086
  if [ "$RR_ARCH" != "x86_64" ] && [ "$RR_ARCH" != "armv7h" ] && [ $RR_ARCH != "aarch64" ] && [ $RR_ARCH != "riscv64" ]; then
    echo "error: supported arch: x86_64, armv7h, aarch64, riscv64"
    return 1
  fi

  # check if platform exists
  if [ ! -d "packages/platforms/$RR_PLATFORM" ]; then
    echo "error: platform not found: packages/platforms/$RR_PLATFORM"
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

