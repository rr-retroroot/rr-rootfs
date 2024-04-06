#!/bin/bash

set -xe

# messages
function merror() {
  printf '\033[1;31mERROR:\033[0m %s\n' "$@" >&2 # bold red
}

function minfo() {
  printf '\033[1;36m> %s\033[0m\n' "$@" >&2 # bold cyan
}

# cleanup on exit
function cleanup {
  if [ $? -ne 0 ]; then
    merror 'something went wrong, exiting...'
  fi
  umount -lfR "${MOUNT_ROOT}" >/dev/null 2>&1 || :
  losetup -d "${LOOP_DEV}" >/dev/null 2>&1 || :
}

# set exit trap
trap cleanup EXIT

