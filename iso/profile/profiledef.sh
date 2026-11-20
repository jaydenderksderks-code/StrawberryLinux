#!/usr/bin/env bash
iso_name="strawberry-linux"
iso_label="STRAWBERRY_$(date +%Y%m)"
iso_publisher="Strawberry Linux"
iso_application="Strawberry Linux Arch-based live environment"
iso_version="$(date +%Y.%m.%d)"
install_dir="arch"
buildmodes=('iso')
bootmodes=('bios.syslinux.mbr' 'bios.syslinux.eltorito' 'uefi-x64.systemd-boot.esp' 'uefi-x64.systemd-boot.eltorito')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'zstd' '-Xcompression-level' '6')
file_permissions=( ['/usr/local/bin/rm']='0:0:755' ['/usr/local/bin/berryinstall']='0:0:755' ['/usr/local/bin/str-']='0:0:755' ['/etc/sudoers.d/10-strawberry-path']='0:0:440' )
