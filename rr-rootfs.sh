#!/bin/bash

build() {
  local ARCH=
  local PLATFORM=$1

  # set platform arch
  if [ "${PLATFORM}" == "desktop" ]; then
    ARCH=x86_64
    RR_DOCKER_IMG="archlinux/archlinux:base-20220519.0.57040"
  else
    ARCH=aarch64
    RR_DOCKER_IMG="stephank/archlinux:aarch64-latest"
  fi

  docker pull ${RR_DOCKER_IMG}

  # install desired packages on docker image so caching is used in pacstrap
  source configs/common/packages
  source configs/${PLATFORM}/packages

  # build image with packages as argument
  docker build \
    --build-arg RR_DOCKER_IMG="${RR_DOCKER_IMG}" \
    --build-arg RR_PACKAGES="${RR_PACKAGES}" \
    -t retroroot-${PLATFORM}-${ARCH} \
    .

  # let's go !
  docker run --rm -v /dev:/dev:ro -v $(pwd)/output:/output --privileged=true \
    -e RR_ARCH=${ARCH} \
    -e RR_PLATFORM=${PLATFORM} \
    -e RR_PACKAGES="${RR_PACKAGES}" \
    retroroot-${PLATFORM}-${ARCH}
}

run() {
  if [ "$1" == "desktop" ]; then
    qemu-system-x86_64 -m 2G \
      -device virtio-vga-gl -display sdl,gl=on \
      -device e1000,netdev=net0 -netdev user,id=net0,hostfwd=tcp::5555-:22 \
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
  echo "usage: $(basename "$0") [-b desktop|rpi] [-r desktop|rpi]"
  echo "examples:"
  echo "       $(basename "$0") -b desktop      | build desktop image"
  echo "       $(basename "$0") -r desktop      | run desktop image"
}

main() {
  # parse args
  test $# -eq 0 && set -- "-h"
  while getopts "b:r:h" ARG; do
    case "$ARG" in
      b) build $OPTARG; return 0;;
      r) run $OPTARG; return 0;;
      *) show_usage; return 1;;
    esac
  done
  shift $(($OPTIND-1))
  test $# -eq 1 || { show_usage; return 1; }
}

main "$@"

