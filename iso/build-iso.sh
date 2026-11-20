#!/usr/bin/env bash
set -euo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
cpu=${1:-x86_64}
[[ "$cpu" == x86_64 ]] || { echo 'Initial ISO builder supports x86_64 only' >&2; exit 2; }
for cmd in cpio gzip grub-mkrescue xorriso install sha256sum file; do
  command -v "$cmd" >/dev/null || { echo "Missing: $cmd" >&2; exit 1; }
done
version=$(cat "$root/locks/linux.version")
release="${version}-strawberry"
[[ "$version" =~ ^[0-9]+\.[0-9]+$ ]] && release="${version}.0-strawberry"
kernel="$root/kernel/artifacts/$cpu/tty/vmlinuz-$release"
[[ -s "$kernel" ]] || { echo "Kernel not found: $kernel. Run ./build.sh x86_64 tty first." >&2; exit 1; }
busybox=$(command -v busybox || true)
[[ -n "$busybox" ]] || { echo 'Install busybox-static' >&2; exit 1; }
file "$busybox" | grep -q 'statically linked' || { echo 'BusyBox must be statically linked' >&2; exit 1; }
[[ "$(uname -m)" == x86_64 ]] || { echo 'Build on an x86_64 Linux runner' >&2; exit 1; }
mkdir -p "$root/work" "$root/dist"
tmp=$(mktemp -d "$root/work/iso.XXXXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/root"/{bin,sbin,etc,dev,proc,sys,run,tmp,root,usr/bin,usr/sbin} "$tmp/iso/boot/grub"
install -m 0755 "$busybox" "$tmp/root/bin/busybox"
# BusyBox applet links provide the complete minimal live userspace.
for applet in sh ash mount umount mkdir ls cat echo printf uname dmesg hostname sleep reboot poweroff halt id pwd ps clear stty setsid cttyhack; do
  ln -s busybox "$tmp/root/bin/$applet"
done
install -m 0755 "$root/iso/init" "$tmp/root/init"
# Do not install the host's rm guard: it depends on GNU realpath -z,
# which this minimal BusyBox image does not provide.
mkdir -p "$tmp/root/usr/share/strawberry"
install -m 0644 "$root/rootfs/usr/share/strawberry/logo.txt" "$tmp/root/usr/share/strawberry/logo.txt"
printf 'root:x:0:0:root:/root:/bin/sh\n' > "$tmp/root/etc/passwd"
printf 'root:x:0:\n' > "$tmp/root/etc/group"
printf 'strawberry\n' > "$tmp/root/etc/hostname"
(cd "$tmp/root" && find . -print0 | LC_ALL=C sort -z | cpio --null -o -H newc --quiet | gzip -n -9) > "$tmp/iso/boot/initramfs.gz"
install -m 0644 "$kernel" "$tmp/iso/boot/vmlinuz"
cat > "$tmp/iso/boot/grub/grub.cfg" <<'GRUB'
set timeout=3
set default=0
menuentry 'Strawberry Linux (live TTY)' {
    linux /boot/vmlinuz init=/init console=tty0 loglevel=7 ignore_loglevel
    initrd /boot/initramfs.gz
}
GRUB
iso="$root/dist/strawberry-linux-$(cat "$root/locks/linux.version")-$cpu-tty.iso"
grub-mkrescue -o "$iso" "$tmp/iso"
(cd "$root/dist" && sha256sum "$(basename "$iso")" > SHA256SUMS)
printf 'ISO ready: %s\n' "$iso"
