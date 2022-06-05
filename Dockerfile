ARG RR_DOCKER_IMG="archlinux/archlinux:base"
FROM ${RR_DOCKER_IMG}
LABEL contributor="cpasjuste@gmail.com"

# update and install build requirements
RUN pacman -Syyu --noconfirm
RUN pacman -S --needed --noconfirm base arch-install-scripts \
  parted e2fsprogs dosfstools squashfs-tools

# add repo to build directory
ADD . /build

# set build environnement
ENV RR_OUTPUT_DIR /output
WORKDIR /build

# let's go !
ENTRYPOINT ["/build/dockerbuild.sh"]

