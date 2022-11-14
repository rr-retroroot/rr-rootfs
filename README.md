# rr-rootfs

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
