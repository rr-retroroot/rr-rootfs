#!/bin/bash

build() {
  local ARCH=$1
  local PLATFORM=$2

  # set platform arch
  if [ "${ARCH}" == "x86_64" ]; then
    RR_DOCKER_IMG="archlinux/archlinux:base"
  elif [ "$ARCH" == "aarch64" ]; then
    RR_DOCKER_IMG="lopsided/archlinux-arm64v8:latest"
  else
    RR_DOCKER_IMG="lopsided/archlinux-arm32v7:latest"
  fi

  echo "[build] arch: $ARCH, platform: $PLATFORM, docker image: $RR_DOCKER_IMG"

  docker pull ${RR_DOCKER_IMG}

  # install target packages in docker image for pacstrap package caching
  # this also populate RR_PACKAGES variable
  source configs/packages
  source configs/packages-${PLATFORM}

  # build image with packages as argument
  docker build \
    --build-arg RR_DOCKER_IMG="${RR_DOCKER_IMG}" \
    -t retroroot-${PLATFORM}-${ARCH} \
    .

  # let's go !
  docker run --rm --privileged=true \
    -v /dev:/dev:ro \
    -v $(pwd)/output:/output \
    -e RR_ARCH=${ARCH} \
    -e RR_PLATFORM=${PLATFORM} \
    -e RR_PACKAGES="${RR_PACKAGES}" \
    retroroot-${PLATFORM}-${ARCH}
}

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
  echo "usage: $(basename "$0") [-a x86_64|armv7h|aarch64] [-p desktop|rpi|rg353|surfacert|none]"
  echo ""
  echo "examples:"
  echo "       $(basename "$0") -a x86_64 -p desktop  | build x86_64 arch for desktop platform"
  echo "       $(basename "$0") -r desktop            | run desktop platform image"
}

main() {
  # parse args
  test $# -eq 0 && set -- "-h"
  while getopts "a:p:r:h" ARG; do
    case "$ARG" in
      a) a=$OPTARG;;
      p) b=$OPTARG;;
      r) run $OPTARG; return 0;;
      *) show_usage; return 1;;
    esac
  done
  shift $(($OPTIND-1))

  if [ -z ${b+x} ]; then
    b="none";
  fi

  if [ $a != "x86_64" ] && [ $a != "armv7h" ] && [ $a != "aarch64" ]; then
    echo "error: supported arch: x86_64, armv7h, aarch64"
    return 1;
  fi

  if [ $b != "desktop" ] && [ $b != "rpi" ] && [ $b != "rg353" ] && [ $b != "surfacert" ] && [ $b != "none" ]; then
    echo "error: supported platform: desktop, rpi, rg353, surfacert, none"
    return 1;
  fi

  build $a $b
}

main "$@"

