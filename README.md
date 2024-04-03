# rr-rootfs

**<ins>Building on arch linux</ins>**

- Install build dependencies:
  ```
  sudo pacman -S --needed git base-devel arch-install-scripts parted dosfstools e2fsprogs qemu-user-static qemu-user-static-binfmt
  ```

- Fix sudo permissions for systemd-nspawn (optional, if chroot needed)
  ```
  sudo cp /usr/lib/binfmt.d/qemu-arm-static.conf /etc/binfmt.d/
  sudo cp /usr/lib/binfmt.d/qemu-aarch64-static.conf /etc/binfmt.d/
  sudo sed -i 's/:FP/:FPC/g' /etc/binfmt.d/qemu-arm-static.conf
  sudo sed -i 's/:FP/:FPC/g' /etc/binfmt.d/qemu-aarch64-static.conf
   sudo systemctl restart systemd-binfmt.service
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
