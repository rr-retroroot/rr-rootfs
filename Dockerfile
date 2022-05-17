FROM ubuntu:focal
LABEL contributor="cpasjuste@gmail.com"

# update and install build requirements
RUN apt-get update && apt-get install -y \
  parted e2fsprogs dosfstools udev wget curl \
  zstd xz-utils qemu-user-static binfmt-support

# add repo to build directory
ADD . /build

# set build environnement
ENV RR_OUTPUT_DIR /output
WORKDIR /build

ENTRYPOINT ["/build/dockerbuild.sh"]

