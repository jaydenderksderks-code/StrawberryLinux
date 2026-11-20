#!/usr/bin/env bash
set -euo pipefail
if (( $# != 4 )); then echo 'usage: configure.sh <src> <out> <x86_64|i686> <tty|graphics>' >&2; exit 2; fi
src=$(realpath "$1"); mkdir -p "$2"; out=$(realpath "$2"); cpu=$3; ui=$4
case "$cpu" in x86_64) def=x86_64_defconfig;; i686) def=i386_defconfig;; *) exit 2;; esac
case "$ui" in tty|graphics);; *) exit 2;; esac
[[ -x "$src/scripts/config" ]] || { echo 'Missing Linux scripts/config' >&2; exit 1; }
make -C "$src" O="$out" ARCH=x86 "$def"
cfg="$src/scripts/config"
set_y() { "$cfg" --file "$out/.config" -e "$1"; }
set_n() { "$cfg" --file "$out/.config" -d "$1"; }
"$cfg" --file "$out/.config" --set-str LOCALVERSION '-strawberry' --set-str SYSTEM_TRUSTED_KEYS '' --set-str SYSTEM_REVOCATION_KEYS ''
for s in LOCALVERSION_AUTO DEBUG_INFO_BTF DEBUG_KERNEL; do set_n "$s"; done
required=(BLK_DEV_INITRD RD_GZIP DEVTMPFS DEVTMPFS_MOUNT TMPFS PROC_FS SYSFS BINFMT_ELF BINFMT_SCRIPT TTY VT VT_CONSOLE UNIX98_PTYS SERIAL_8250 SERIAL_8250_CONSOLE BLOCK PCI SCSI BLK_DEV_SD BLK_DEV_SR ATA ATA_PIIX SATA_AHCI BLK_DEV_NVME VIRTIO_PCI VIRTIO_BLK VIRTIO_NET USB_SUPPORT USB USB_XHCI_HCD USB_EHCI_HCD USB_STORAGE HID HID_GENERIC USB_HID EXT4_FS F2FS_FS ISO9660_FS SQUASHFS SQUASHFS_ZLIB OVERLAY_FS BLK_DEV_LOOP MSDOS_PARTITION EFI_PARTITION FAT_FS VFAT_FS NLS_CODEPAGE_437 NLS_ISO8859_1 SWAP ZSMALLOC ZRAM)
for s in "${required[@]}"; do set_y "$s"; done
if [[ "$cpu" == i686 ]]; then
  # Disable alternative x86 CPU family selectors before selecting M686.
  while IFS= read -r sym; do
    [[ "$sym" == M686 ]] || set_n "$sym"
  done < <(sed -n 's/^config \(M[A-Z0-9_]*\)$/\1/p' "$src/arch/x86/Kconfig.cpu")
  set_y M686
fi
if [[ "$ui" == graphics ]]; then
  graphics_required=(DRM DRM_KMS_HELPER DRM_VIRTIO_GPU FB DRM_FBDEV_EMULATION FRAMEBUFFER_CONSOLE DRM_I915 DRM_AMDGPU)
  for s in "${graphics_required[@]}"; do set_y "$s"; done
else
  for s in DRM FB SOUND MEDIA_SUPPORT; do set_n "$s"; done
fi
make -C "$src" O="$out" ARCH=x86 olddefconfig
for s in "${required[@]}"; do
  grep -qx "CONFIG_${s}=y" "$out/.config" || { echo "Required kernel option not built in: $s" >&2; exit 1; }
done
if [[ "$cpu" == i686 ]]; then
  grep -qx 'CONFIG_M686=y' "$out/.config" || { echo 'M686 not selected' >&2; exit 1; }
  while IFS= read -r sym; do
    [[ "$sym" == M686 ]] || ! grep -qx "CONFIG_${sym}=y" "$out/.config" || { echo "Conflicting CPU: $sym" >&2; exit 1; }
  done < <(sed -n 's/^config \(M[A-Z0-9_]*\)$/\1/p' "$src/arch/x86/Kconfig.cpu")
fi
if [[ "$ui" == graphics ]]; then
  for s in "${graphics_required[@]}"; do
    grep -qx "CONFIG_${s}=y" "$out/.config" || { echo "Required graphics option not built in: $s" >&2; exit 1; }
  done
else
  for s in DRM FB SOUND MEDIA_SUPPORT; do
    ! grep -Eq "^CONFIG_${s}=[ym]$" "$out/.config" || { echo "Forbidden TTY option enabled: $s" >&2; exit 1; }
  done
fi
printf 'Configured %s / %s in %s\n' "$cpu" "$ui" "$out"
