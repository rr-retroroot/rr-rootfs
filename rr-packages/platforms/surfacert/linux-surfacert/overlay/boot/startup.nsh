fs0:
zImage initrd=initramfs-linux.img dtb=tegra30-microsoft-surface-rt-efi.dtb root=LABEL=RR-BOOT console=tty0 cpuidle.off=1
reset -s

# TODO: add "splash" option, switch tty0
