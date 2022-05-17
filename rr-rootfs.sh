#!/bin/bash

docker build . -t retroroot
docker run --rm -v /dev:/dev:ro -v $(pwd)/output:/output --privileged=true \
  -e RR_PLATFORM=desktop \
  -e RR_ARCH=x86_64 \
  retroroot

