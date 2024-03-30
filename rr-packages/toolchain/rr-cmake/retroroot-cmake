#!/usr/bin/env bash
set -e

source /opt/retroroot/rr-env @TRIPLE@

exec cmake -DCMAKE_TOOLCHAIN_FILE=${RETROROOT_SYSROOT}/usr/lib/cmake/rr-toolchain.cmake "$@"

