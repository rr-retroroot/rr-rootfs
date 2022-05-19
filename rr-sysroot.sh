#!/bin/bash

set -xe

RR_ARCH=x86_64

sudo rm -rf /opt/pacbrew/retroroot/target/${RR_ARCH}

# create target directories
sudo mkdir -p /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/bin
sudo mkdir -p /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/share

# copy sysroot files
sudo cp -r /media/cpasjuste/RR-ROOT/usr/lib /opt/pacbrew/retroroot/target/${RR_ARCH}/usr
sudo cp -r /media/cpasjuste/RR-ROOT/usr/include /opt/pacbrew/retroroot/target/${RR_ARCH}/usr
sudo cp -r /media/cpasjuste/RR-ROOT/usr/bin/*-config /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/bin/
sudo cp -r /media/cpasjuste/RR-ROOT/usr/share/pkgconfig /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/share
sudo cp -r /media/cpasjuste/RR-ROOT/usr/share/cmake /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/share

# remove unwanted files
sudo rm -f /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/bin/i686-pc-linux-gnu-pkg-config
sudo rm -f /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/bin/x86_64-pc-linux-gnu-pkg-config
sudo rm -f /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/bin/pkg-config
sudo rm -f /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/bin/alsoft-config

# fix paths
sudo find /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/bin -type f -print0 | sudo xargs -0 sed -i \
  "s|/usr|/opt/pacbrew/retroroot/target/${RR_ARCH}/usr|g"
sudo find /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/lib/cmake -type f -print0 | sudo xargs -0 sed -i \
  "s|/usr|/opt/pacbrew/retroroot/target/${RR_ARCH}/usr|g"
sudo find /opt/pacbrew/retroroot/target/${RR_ARCH}/usr/share/cmake -type f -print0 | sudo xargs -0 sed -i \
  "s|/usr|/opt/pacbrew/retroroot/target/${RR_ARCH}/usr|g"

