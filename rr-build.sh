#!/bin/bash

# get root privileges
[ "$UID" -eq 0 ] || exec sudo bash "$0" "$@"

source scripts/utility.sh
source scripts/build-image.sh

run() {
  if [ "$1" == "desktop" ]; then
    qemu-img resize -f raw "output/retroroot-desktop-x86_64.img" 10G
    qemu-system-x86_64 -m 2G -smp 4 \
      -serial stdio \
      -device virtio-vga-gl -display sdl,gl=on \
      -device e1000,netdev=net0 -netdev user,id=net0,hostfwd=tcp::5555-:22 \
      -usbdevice mouse \
      -drive format=raw,file="output/retroroot-desktop-x86_64.img"
  else
    # TODO
    qemu-system-aarch64 -m 1G -M raspi3b \
      -serial stdio \
      -drive if=sd,format=raw,file="output/retroroot-rpi-aarch64.img"
    #-kernel output/kernel8.img \
  fi
}

show_usage() {
  echo "usage: $(basename "$0") [-a x86_64|armv7h|aarch64] [-p desktop|rpi|rg353|surfacert|none] -c"
  echo ""
  echo "examples:"
  echo "       $(basename "$0") -a x86_64 -p desktop     | build x86_64 arch for desktop platform"
  echo "       $(basename "$0") -a x86_64 -p desktop -c  | chroot desktop platform image"
  echo "       $(basename "$0") -r desktop               | run desktop platform image (qemu)"
}

main() {
  # parse args
  test $# -eq 0 && set -- "-h"
  while getopts "a:p:r:ch" ARG; do
    case "$ARG" in
    a) arch=$OPTARG ;;
    p) platform=$OPTARG ;;
    c) chroot=1 ;;
    r)
      run $OPTARG
      return 0
      ;;
    *)
      show_usage
      return 1
      ;;
    esac
  done
  shift $(($OPTIND - 1))

  if [ -z ${platform+x} ]; then
    platform="none"
  fi

  # shellcheck disable=SC2086
  if [ "$arch" != "x86_64" ] && [ "$arch" != "armv7h" ] && [ $arch != "aarch64" ]; then
    echo "error: supported arch: x86_64, armv7h, aarch64"
    return 1
  fi

  if [ $platform != "desktop" ] &&
    [ $platform != "rpi" ] &&
    [ $platform != "rg353" ] &&
    [ $platform != "surfacert" ] &&
    [ $platform != "none" ]; then
    echo "error: supported platform: desktop, rpi, rg353, surfacert, none"
    return 1
  fi

  ROOT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)
  build_image "$arch" "$platform" "${ROOT_DIR}" "${chroot}"
}

main "$@"
