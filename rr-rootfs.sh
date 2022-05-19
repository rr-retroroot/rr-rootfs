#!/bin/bash

build() {
  local ARCH=
  if [ "$1" == "desktop" ]; then
    ARCH=x86_64
  else
    ARCH=aarch64
  fi
  
  docker build . -t retroroot
  docker run --rm -v /dev:/dev:ro -v $(pwd)/output:/output --privileged=true \
    -e RR_PLATFORM=$1 \
    -e RR_ARCH=$ARCH \
    retroroot
}

run() {
  local ARCH=
  if [ "$1" == "desktop" ]; then
    ARCH=x86_64
  else
    ARCH=aarch64
  fi
  
  qemu-system-x86_64 -m 2048 -device virtio-vga-gl -display sdl,gl=on \
    -drive format=raw,file="output/retroroot-$1-$ARCH.img"
}

show_usage() {
  echo "usage: $(basename "$0") [-b desktop|rpi] [-r desktop|rpi]"
  echo "examples:"
  echo "       $(basename "$0") -b desktop: build desktop image"
  echo "       $(basename "$0") -r desktop: run desktop image"
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

