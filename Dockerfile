ARG RR_DOCKER_IMG="archlinux/archlinux:base"
FROM ${RR_DOCKER_IMG}
LABEL contributor="cpasjuste@gmail.com"

# add repo to build directory
ADD . /build

# set build environnement
ENV RR_OUTPUT_DIR /output
WORKDIR /build

# let's go !
ENTRYPOINT ["/build/dockerbuild.sh"]

