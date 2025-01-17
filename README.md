# RetroRoot

RetroRoot is an ArchLinux based image with retro gaming capabilities

### Building

- Install build dependencies (ubuntu 24.04):
  ```
  sudo apt install -y build-essential cmake autoconf libtool git parted dosfstools e2fsprogs qemu-user-static libarchive-tools pacman-package-manager arch-install-scripts makepkg
  sudo pacman-key --init
  ```

- Install build dependencies (arch linux):
  ```
  sudo pacman -S --needed wget git base-devel cmake arch-install-scripts parted dosfstools e2fsprogs qemu-user-static qemu-user-static-binfmt
  ```
  - If dns resolution is not working and you are using systemd-resolved on your host:
     ```
     sudo rm -f /etc/resolv.conf
     sudo ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
     ```

- Get retroroot sources
  ```
  git clone https://github.com/rr-retroroot/rr-rootfs.git
  cd rr-rootfs
  ```

- Create the aarch64 image for rpi platform
  ```
  ./rr-build-image.sh -a aarch64 -p rpi
  ```

- Chroot the aarch64 image for rpi (if needed...)
  ```
  ./rr-build-image.sh -a aarch64 -p rpi -c
  ```

- Install some packages to the aarch64 image for rpi (if needed...)
  ```
  ./rr-build-image.sh -a aarch64 -p rpi -i "base-devel git"
  ```

- Cross compile specific aarch64 packages for rpi (if needed...). Note: sysroot build is only required once...
  ```
  ./rr-build-image.sh -a aarch64 -p sysroot
  ./rr-build-packages.sh -a aarch64 -p packages/platforms/rpi
  ```

- Cross compilation with CLion IDE:
  - File | Settings | Build, Execution, Deployment | CMake | CMake options:
    ```
    -DCMAKE_TOOLCHAIN_FILE=/CHANGE_ME/rr-rootfs/toolchain/bin/rr-toolchain.cmake
    ```
  - File | Settings | Build, Execution, Deployment | CMake | Environment:
    ```
    CARCH=aarch64;RETROROOT_HOME=/CHANGE_ME/rr-rootfs
    ```

### Project structure

```md
rr-rootfs
├── output
│   ├── pacman_cache            > cache for downloaded pacman packages
│   ├── retroroot-*-sysroot     > sysroot for retroroot packages cross compilation
|   ├── toolchains              > toolchains for retroroot packages cross compilation
│   └── retroroot-*-*.img       > image to flash on target platform
├── packages
│   ├── cores                   > libretro cores packages
│   ├── platforms               > platforms (devices) specific packages
│   └── system                  > retroroot base packages
├── toolchain
│   └── bin                     > cross compilation scripts and environment
│── rr-build-helper.sh          > a few bash functions for "rr-build-image.sh" and "rr-build-packages.sh"
│── rr-build-image.sh           > script to build images
└── rr-build-packages.sh        > script to build custom packages
```