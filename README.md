# RetroRoot

RetroRoot is an ArchLinux based image with retrogaming capabilities (retroarch)

**<ins>Building on arch linux / ubuntu</ins>**

- Install build dependencies (arch linux):
  ```
  sudo pacman -S --needed wget git base-devel cmake arch-install-scripts parted dosfstools e2fsprogs qemu-user-static qemu-user-static-binfmt
  ```
  - If dns resolution is not working and you are using systemd-resolved on your host:
     ```
     sudo rm -f /etc/resolv.conf
     sudo ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
     ```

- Install build dependencies (ubuntu 24.04):
  ```
  sudo apt install -y build-essential cmake autoconf libtool git parted dosfstools e2fsprogs qemu-user-static libarchive-tools pacman-package-manager arch-install-scripts makepkg
  sudo pacman-key --init
  ```
- Install build dependencies (ubuntu 22.04):
  ```
  sudo apt install -y build-essential cmake autoconf libtool git parted dosfstools e2fsprogs qemu-user-static libarchive-tools
  wget http://launchpadlibrarian.net/635385442/arch-install-scripts_28-1_all.deb
  wget http://launchpadlibrarian.net/635298936/libalpm13_13.0.2-3_amd64.deb
  wget http://launchpadlibrarian.net/635298938/pacman-package-manager_6.0.2-3_amd64.deb
  wget http://launchpadlibrarian.net/635298937/makepkg_6.0.2-3_amd64.deb
  sudo dpkg -i arch-install-scripts_28-1_all.deb libalpm13_13.0.2-3_amd64.deb pacman-package-manager_6.0.2-3_amd64.deb makepkg_6.0.2-3_amd64.deb
  sudo apt-get -y -f install
  sudo pacman-key --init
  ```
- Tips:
  ```
  sudo nano /etc/makepkg.conf
  ```
  ```
  #MAKEFLAGS="-j2" => MAKEFLAGS="-j16"
  ```

- Get retroroot sources
  ```
  git clone https://github.com/rr-retroroot/rr-rootfs.git
  cd rr-rootfs
  ```

- Create the armv7h image for surface rt
  ```
  ./rr-build-image.sh -a armv7h -p surfacert
  ```

- Chroot to the armv7h image for surface rt (if needed...)
  ```
  ./rr-build-image.sh -a armv7h -p surfacert -c
  ```
  
- Install some packages to the armv7h image for surface rt (if needed...)
  ```
  ./rr-build-image.sh -a armv7h -p surfacert -i "base-devel git"
  ```

- Cross compile specific armv7h packages for surface rt (if needed...). Note: sysroot build is only required once...
  ```
  ./rr-build-image.sh -a armv7h -p sysroot
  ./rr-build-packages.sh -p packages/platforms/surfacert
  ```

- Use with CLion IDE:
 - Mount sysroot image
  ```
  ./rr-build-image.sh -a aarch64 -p sysroot -m
  ```
 - File | Settings | Build, Execution, Deployment | CMake | CMake options:
  ```
  -DCMAKE_TOOLCHAIN_FILE=/CHANGE_ME/rr-rootfs/toolchain/bin/rr-toolchain.cmake
  ```
 - File | Settings | Build, Execution, Deployment | CMake | Environment:
  ```
  CARCH=aarch64;RETROROOT_HOME=/CHANGE_ME/rr-rootfs/toolchain;RETROROOT_HOST=/CHANGE_ME/rr-rootfs/output/toolchains/aarch64;RETROROOT_SYSROOT=/CHANGE_ME/rr-rootfs/output/rootfs
  ```
