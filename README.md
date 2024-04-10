# rr-rootfs

**<ins>Building on arch linux / ubuntu</ins>**

- Install build dependencies (arch linux):
  ```
  sudo pacman -S --needed wget git base-devel arch-install-scripts parted dosfstools e2fsprogs qemu-user-static qemu-user-static-binfmt
  ```
  - If dns resolution is not working and you are using systemd-resolved on your host:
     ```
     sudo rm -f /etc/resolv.conf
     sudo ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf
     ```

- Install build dependencies (ubuntu):
  ```
  sudo pacman -S --needed git base-devel arch-install-scripts parted dosfstools e2fsprogs qemu-user-static qemu-user-static-binfmt
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

## OLD

**<ins>Building on ubuntu</ins>**

- Install build dependencies:
    ```
    sudo apt -yq update
    sudo apt -yq install docker.io
    ```
- Fix docker permissions (reboot for changes to take effect):
    ```
    sudo groupadd docker
    sudo usermod -aG docker ${USER}
    ```
- Build x86_64 desktop image:
    ```
    ./rr-rootfs.sh -a x86_64 -p desktop
    ```
- Run x86_64 desktop image:
    ```
    ./rr-rootfs.sh -r desktop
    ```
