FROM archlinux/archlinux:base-20220519.0.57040
LABEL contributor="cpasjuste@gmail.com"

# get desired packages arguments
ARG RR_PACKAGES

# update and install build requirements
RUN pacman -Syu --noconfirm
RUN pacman -S --needed --noconfirm $RR_PACKAGES

# add repo to build directory
ADD . /build

# set build environnement
ENV RR_OUTPUT_DIR /output
WORKDIR /build

# let's go !
ENTRYPOINT ["/build/dockerbuild.sh"]

