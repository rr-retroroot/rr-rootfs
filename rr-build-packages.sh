#!/bin/bash

set -e

# base stuff
RR_SSH_HOST="mydedibox.fr"
RR_TEMP_DB="${RR_ROOT_PATH}/retroroot_db"
RR_ROOT_PATH=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)

# toolchains
RR_TOOLCHAIN_LINK_ARMV7H="https://snapshots.linaro.org/gnu-toolchain/12.3-2023.06-1/arm-linux-gnueabihf/gcc-linaro-12.3.1-2023.06-x86_64_arm-linux-gnueabihf.tar.xz"
RR_TOOLCHAIN_LINK_AARCH64="https://snapshots.linaro.org/gnu-toolchain/12.3-2023.06-1/aarch64-linux-gnu/gcc-linaro-12.3.1-2023.06-x86_64_aarch64-linux-gnu.tar.xz"
RR_TOOLCHAIN_LINK_RISCV64="https://pacman.mydedibox.fr/retroroot/toolchains/gcc-archlinux-14.2.0-x86_64_riscv64-linux-gnu.tar.xz"

COL_R='\033[0;31m'
COL_G='\033[0;32m'
COL_Y='\033[0;33m'
COL_N='\033[0m'

# source build scripts
source scripts/utility.sh

# cleanup on exit
function cleanup_repo {
  if [ $? -ne 0 ]; then
    echo "${COL_R}something went wrong...\n${COL_N}"
  fi
  image_cleanup
  sudo rm -rf "${RR_TEMP_DB}"
}

# set exit trap
trap cleanup_repo EXIT

function die() {
  printf "${COL_R}ERR: %s\n${COL_N}" "$@" 1>&2
	exit $retval
}

function pacman_sync() {
  echo -e "${COL_G}pacman_sync:${COL_N} synching repositories..."
  sudo pacman --config "${RR_ROOT_PATH}/packages/pacman.conf" --dbpath ${RR_TEMP_DB} -Syy || die "pacman_sync: repo sync failed"
  # get remote package list
  RR_REMOTE_PACKAGES=$(pacman --config "${RR_ROOT_PATH}/packages/pacman.conf" --dbpath "${RR_TEMP_DB}" -Sl)
  echo -e "${COL_G}pacman_sync:${COL_N} ok"
}

# upload_pkg PKGPATH PKGNAME ARCH
function upload_pkg() {
  local pkgpath=$1
  local pkgname=$2
  local pkgarch=$3
  local pkgfile=$(find $pkgpath/$pkgname-*-$pkgarch.pkg.tar.xz  -printf "%f\n")
  echo -e "${COL_G}upload_pkg:${COL_N} uploading ${COL_G}$pkgname${COL_N} ($pkgarch) to retroroot repo"
  scp "$pkgpath/$pkgfile" "$RR_SSH_USER@$RR_SSH_HOST:/home/pacman/retroroot/packages/$pkgarch" || die "upload_pkg: scp to $RR_SSH_HOST failed"
  echo -e "${COL_G}upload_pkg:${COL_N} adding ${COL_G}$pkgname${COL_N} ($pkgarch) to retroroot repo"
  ssh "$RR_SSH_USER@$RR_SSH_HOST" repo-add \
    /home/pacman/retroroot/packages/$pkgarch/retroroot-$pkgarch.db.tar.gz \
    /home/pacman/retroroot/packages/$pkgarch/$pkgfile \
    || die "upload_pkg: repo-add failed"
}

# get_local_srcinfo PKGPATH
function get_local_srcinfo() {
  pushd "$1" &> /dev/null || die "build_package: pushd $1 failed"
  echo "$(makepkg --printsrcinfo)"
  popd &> /dev/null || die "build_package: popd failed"
}

# get_local_pkg_name SRCINFO
function get_local_pkg_name() {
  echo "$1" | grep pkgbase | cut -d' ' -f 3
}

# get_local_pkg_version SRCINFO
function get_local_pkg_ver() {
  local v=$(echo "$1" | grep pkgver | cut -d' ' -f 3)
  local r=$(echo "$1" | grep pkgrel | cut -d' ' -f 3)
  echo "$v-$r"
}

# get_local_pkg_arch SRCINFO
function get_local_pkg_arch() {
  # TODO: use SRCINFO
  local arch=`cat "$1" | grep "arch=" | sed -n "s/^.*(\(.*\)).*$/\1/ p"`
  echo "$arch"
}

# get_remote_pkg_version ARCH PKGNAME
function get_remote_pkg_ver() {
  local remote_pkgverrel=$(echo "$RR_REMOTE_PACKAGES" | grep "retroroot-$1" | grep -E "$2( |$)" | awk '{print $3}' | head -1)
  if [ -z "$remote_pkgverrel" ]; then
    remote_pkgverrel="n/a"
  fi
  echo "$remote_pkgverrel"
}

# build_package PKGPATH ARCH INSTALL
function build_package() {
  pushd "$1" &> /dev/null || die "build_package: pushd $1 failed"
  rm -rf *-$2.pkg.tar.* &> /dev/null
  
  # setup variables
  export CARCH="$2"
  export RR_ARCH="$2"
  export RR_PLATFORM="sysroot"
  export RETROROOT_HOME="${RR_ROOT_PATH}/toolchain"
  export RETROROOT_HOST="${RR_ROOT_PATH}/output/toolchains/${RR_ARCH}"
  export RETROROOT_SYSROOT="${RR_ROOT_PATH}/output/retroroot-${RR_ARCH}-${RR_PLATFORM}"
  if [ ! -d "${RETROROOT_SYSROOT}" ]; then
    die "build_package: sysroot doesn't exist... (${RETROROOT_SYSROOT})"
  fi

  # get package build depds
  local deps=""
  local makedepends=$(echo "${SRCINFO}" | grep makedepends)
  for dep in "${makedepends}"; do
    deps="$deps $(echo "$dep" | cut -d' ' -f 3)"
  done
  
  # install build dependencies to  sysroot image if needed
  if [ ! -z "${deps}" ]; then
    install_package "${deps}" || die "build_package: package deps installation failed"
  fi

  # let's go...
  PKGEXT='.pkg.tar.xz' makepkg -Cfd || die "build_package: makepkg failed"

  popd &> /dev/null || die "build_package: popd failed"
}

# check_install_toolchain ARCH
function check_install_toolchain() {
  local ARCH="$1"
  local URL="$2"

  if [ ! -f "${RR_ROOT_PATH}/output/toolchains/${ARCH}/bin/${ARCH}-linux-gnu-gcc" ]; then
    echo -e "${COL_G}rr_build${COL_N}: ${ARCH} toolchain not found, installing..."
    mkdir -p "${RR_ROOT_PATH}/output/toolchains/${ARCH}"
    if [ ! -f "${RR_ROOT_PATH}/output/toolchains/gcc-${ARCH}.tar.xz" ]; then
      wget "${URL}" -O "${RR_ROOT_PATH}/output/toolchains/gcc-${ARCH}.tar.xz"
    fi
    tar xJf "${RR_ROOT_PATH}/output/toolchains/gcc-${ARCH}.tar.xz" --strip-components=1 -C "${RR_ROOT_PATH}/output/toolchains/${ARCH}"
    # create symlinks for conveniance (arm-linux-gnueabihf > armv7h-linux-gnu)
    if [ ! -f "${RR_ROOT_PATH}/output/toolchains/${ARCH}/bin/${ARCH}-linux-gnu-gcc" ]; then
      pushd "${RR_ROOT_PATH}/output/toolchains/${ARCH}/bin" &> /dev/null
      files="$(find . -type f)"
      for i in $files; do
        link="${i/arm/"${ARCH}"}"
        link="${link/gnueabihf/"gnu"}"
        ln -sf "$i" "$link"
      done
      popd &> /dev/null
    fi
    rm -f "${RR_ROOT_PATH}/output/toolchains/gcc-${ARCH}.tar.xz"
  else
    echo -e "${COL_G}rr_build${COL_N}: ${ARCH} toolchain already installed..."
  fi
}

function build_packages() {
  # create temp repo
  sudo mkdir -p "${RR_TEMP_DB}"
  
  # set packages path
  RR_PACKAGES_PATH="${RR_ROOT_PATH}/packages"

  # parse args
  while test $# -gt 0
  do
    case "$1" in
      -a) shift && RR_BUILD_ARCH="$1"
          echo -e "${COL_G}rr_build${COL_N}: forced arch (${COL_Y}$RR_BUILD_ARCH${COL_N})"
        ;;
      -f) echo -e "${COL_G}rr_build${COL_N}: force rebuild all packages enabled"
          RR_BUILD_ALL=true
        ;;
      -h) RR_UPLOAD=true
          shift && RR_SSH_HOST="$1"
          echo -e "${COL_G}rr_build${COL_N}: uploading packages to retroroot repos with specified host ($RR_SSH_HOST)"
        ;;
      -i) echo -e "${COL_G}rr_build${COL_N}: install built packages"
          RR_INSTALL=true
        ;;
      -p) shift && RR_PACKAGES_PATH="$1/"
          echo -e "${COL_G}rr_build${COL_N}: building packages in specified path: ${RR_PACKAGES_PATH}"
        ;;
      -u) RR_UPLOAD=true
          shift && RR_SSH_USER="$1"
          echo -e "${COL_G}rr_build${COL_N}: uploading packages to retroroot repos with specified user ($RR_SSH_USER)"
        ;;
    esac
    shift
  done
  
  # check for toolchains installation
  check_install_toolchain armv7h ${RR_TOOLCHAIN_LINK_ARMV7H}
  check_install_toolchain aarch64 ${RR_TOOLCHAIN_LINK_AARCH64}
  check_install_toolchain riscv64 ${RR_TOOLCHAIN_LINK_RISCV64}
  
  # sync pacman packages
  pacman_sync

  # loop through packages, ignore "pkg" and "src"
  pkgs=$(find "${RR_PACKAGES_PATH}" \( -path "*/pkg" -o -path "*/src" \) -prune -o -name PKGBUILD -print)
  for pkg in $pkgs; do
    # get pkgbuild basename
    local pkgpath=$(dirname "$pkg")
    
    # get pkg "srcinfo"
    echo -e "${COL_G}rr_build:${COL_N} getting ${COL_G}$pkgpath${COL_N} information..."
    SRCINFO=$(get_local_srcinfo "$pkgpath")
    
    # get local package name and version
    local pkgname=$(get_local_pkg_name "$SRCINFO")
    local local_pkgver=$(get_local_pkg_ver "$SRCINFO")
    #echo "pkg: $pkg, path: $pkgpath, name: $pkgname, ver: $local_pkgver"

    # build a "target" package
    if [ -z ${RR_BUILD_ARCH+x} ]; then
      ARCHS="x86_64 armv7h aarch64 riscv64"
    else
      ARCHS="$RR_BUILD_ARCH"
    fi
    for ARCH in ${ARCHS}; do
      # skip package if it's not for current arch
      local pkgarch=$(get_local_pkg_arch "$pkg")
      if [[ "$pkgarch" != *"$ARCH"* ]] && [[ "$pkgarch" != *"any"* ]]; then
        echo -e "${COL_G}rr_build:${COL_N} ${COL_G}$pkgname${COL_N} (${COL_Y}${ARCH}${COL_N}) was skipped (pkg arch: ${COL_Y}$pkgarch${COL_N})"
        continue
      fi
      
      # only build packages if force requested (-f) or local/remote pkg versions differ
      local remote_pkgver=$(get_remote_pkg_ver "${ARCH}" "$pkgname")
      if [ $RR_BUILD_ALL ] || [ "$local_pkgver" != "$remote_pkgver" ]; then
        echo -e "${COL_G}rr_build:${COL_N} new package: ${COL_G}$pkgname${COL_N} (${COL_Y}${ARCH}${COL_N}) ($remote_pkgver => $local_pkgver)"
        echo -e "${COL_G}rr_build:${COL_N} building ${COL_G}$pkgname${COL_N} (${COL_Y}${ARCH}${COL_N}) ($local_pkgver)"
        build_package "$pkgpath" "${ARCH}" $RR_INSTALL
        if [ $RR_UPLOAD ]; then
          upload_pkg "$pkgpath" "$pkgname" "${ARCH}"
        fi
        echo -e "${COL_G}rr_build:${COL_N} build sucess for ${COL_G}$pkgpath/$pkgname-$local_pkgver-$ARCH.pkg.tar.xz${COL_N}"
      else
        # package is up to date
        echo -e "${COL_G}rr_build: $pkgname${COL_N} (${COL_Y}${ARCH}${COL_N}) is up to date ($remote_pkgver => $local_pkgver)..."
      fi
    done
  done

  echo -e "${COL_G}rr_build:${COL_N} all done !"
}

build_packages "$@"

