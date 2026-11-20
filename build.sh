#!/usr/bin/env bash
set -euo pipefail
[[ ${1:-x86_64} == x86_64 && $# -le 1 ]] || { echo 'usage: build.sh [x86_64]' >&2; exit 2; }
[[ $EUID -eq 0 ]] || { echo 'Run as root on Arch Linux' >&2; exit 1; }
command -v mkarchiso >/dev/null || { echo 'Install archiso first' >&2; exit 1; }
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
work=$(mktemp -d -p "${TMPDIR:-/var/tmp}" strawberry.XXXXXXXX)
trap 'rm -rf -- "$work"' EXIT
mkdir -p "$root/dist" "$work/profile"
cp -a /usr/share/archiso/configs/releng/. "$work/profile/"
cp -a "$root/iso/profile/." "$work/profile/"
cat /usr/share/archiso/configs/releng/packages.x86_64 "$root/iso/profile/packages.x86_64" | sort -u > "$work/profile/packages.x86_64"
cp -a "$root/rootfs/." "$work/profile/airootfs/"
install -d "$work/profile/airootfs/usr/share/strawberry/install-overlay"
cp -a "$root/rootfs/." "$work/profile/airootfs/usr/share/strawberry/install-overlay/"
# The stock releng profile supplies tested bootloader entries for BIOS and UEFI.
# Remove stock releng customizations that conflict with Strawberry's identity.
rm -f "$work/profile/airootfs/etc/motd"
for f in rm berryinstall str-; do
  chmod 0755 "$work/profile/airootfs/usr/local/bin/$f"
  bash -n "$work/profile/airootfs/usr/local/bin/$f"
done
chmod 0440 "$work/profile/airootfs/etc/sudoers.d/10-strawberry-path"
if [[ -f "$root/assets/strawberry-de.png" ]]; then
  install -Dm644 "$root/assets/strawberry-de.png" "$work/profile/airootfs/usr/share/strawberry/strawberry-de.png"
fi
mkarchiso -v -w "$work/build" -o "$root/dist" "$work/profile"
