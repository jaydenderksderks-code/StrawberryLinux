#!/usr/bin/env bash
set -euo pipefail
if (( $# > 2 )); then echo 'usage: build.sh [x86_64|i686] [tty|graphics]' >&2; exit 2; fi
cpu=${1:-x86_64}; ui=${2:-tty}
case "$cpu" in x86_64|i686);; *) echo 'Invalid CPU' >&2; exit 2;; esac
case "$ui" in tty|graphics);; *) echo 'Invalid UI' >&2; exit 2;; esac
(( EUID != 0 )) || { echo 'Refusing to build as root' >&2; exit 1; }
export LC_ALL=C TZ=UTC MAKEFLAGS="${MAKEFLAGS:--j1}" KBUILD_BUILD_USER=strawberry KBUILD_BUILD_HOST=builder KBUILD_BUILD_VERSION=1 SOURCE_DATE_EPOCH=1731801600 KBUILD_BUILD_TIMESTAMP='Sun Nov 17 00:00:00 UTC 2024'
unset LOCALVERSION || true
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
for cmd in curl gpg tar make sha256sum findmnt realpath mktemp gcc bc flex bison openssl; do command -v "$cmd" >/dev/null || { echo "Missing dependency: $cmd" >&2; exit 1; }; done
work=${STRAWBERRY_WORK:-$root/work}; mkdir -p -- "$work"; work=$(cd -- "$work" && pwd -P)
fs=$(findmnt -n -T "$work" -o FSTYPE)
case "$fs" in ext4|xfs|btrfs|f2fs);; *) echo "Unsupported work filesystem: $fs" >&2; exit 1;; esac
version=$(<"$root/locks/linux.version"); fingerprint=$(<"$root/locks/linux-signer.fingerprint")
[[ "$version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || { echo 'Invalid pinned version' >&2; exit 1; }
[[ "$fingerprint" =~ ^[A-F0-9]{40}$ ]] || { echo 'Invalid signing fingerprint' >&2; exit 1; }
release="${version}-strawberry"
# Kernel.org publishes release signatures over the uncompressed tar stream.
major=${version%%.*}; base="https://cdn.kernel.org/pub/linux/kernel/v${major}.x/linux-${version}.tar"
keyurl="https://git.kernel.org/pub/scm/docs/kernel/pgpkeys.git/plain/keys/${fingerprint: -16}.asc"
tmp=$(mktemp -d "$work/.strawberry.XXXXXXXX")
cleanup() { rm -rf -- "$tmp"; }
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
mkdir -m 700 "$tmp/gnupg"
export GNUPGHOME="$tmp/gnupg"
fetch() {
  printf 'Downloading: %s\n' "$1"
  curl --fail --location --show-error --silent --retry 3 \
    --proto '=https' --proto-redir '=https' \
    --output "$2" "$1"
}
fetch "${base}.xz" "$tmp/linux.tar.xz"
fetch "${base}.sign" "$tmp/linux.tar.sign"
fetch "$keyurl" "$tmp/signer.asc"
gpg --batch --import "$tmp/signer.asc" >/dev/null 2>&1
# Require the exact pinned key, not merely a successfully imported key.
gpg --batch --with-colons --fingerprint "$fingerprint" | grep -Fqx "fpr:::::::::${fingerprint}:" || { echo 'Pinned key not imported' >&2; exit 1; }
xz -dc "$tmp/linux.tar.xz" > "$tmp/linux.tar"
gpg --batch --status-fd 1 --verify "$tmp/linux.tar.sign" "$tmp/linux.tar" > "$tmp/gpg.status" 2> "$tmp/gpg.stderr" || { cat "$tmp/gpg.stderr" >&2; exit 1; }
awk -v fp="$fingerprint" '$1=="[GNUPG:]" && $2=="VALIDSIG" && $3==fp {ok=1} END {exit !ok}' "$tmp/gpg.status" || { echo 'Unexpected kernel signing key' >&2; exit 1; }
sha256sum "$tmp/linux.tar.xz" | awk '{print $1 "  linux-'"$version"'.tar.xz"}' > "$tmp/source-tar.sha256"
mkdir "$tmp/src"
tar -xf "$tmp/linux.tar" -C "$tmp/src" --strip-components=1
"$root/kernel/configure.sh" "$tmp/src" "$tmp/out" "$cpu" "$ui"
make -C "$tmp/src" O="$tmp/out" ARCH=x86 bzImage
actual=$(make -s -C "$tmp/src" O="$tmp/out" ARCH=x86 kernelrelease)
[[ "$actual" == "$release" ]] || { echo "Unexpected kernel release: $actual" >&2; exit 1; }
dest="$root/kernel/artifacts/$cpu/$ui"; mkdir -p "$dest"
install -m 0644 "$tmp/out/arch/x86/boot/bzImage" "$dest/vmlinuz-$release"
install -m 0644 "$tmp/out/.config" "$dest/.config"
install -m 0644 "$tmp/source-tar.sha256" "$dest/source-tar.sha256"
(cd "$dest" && sha256sum "vmlinuz-$release" .config source-tar.sha256 > SHA256SUMS)
printf 'Kernel built: %s\n' "$dest/vmlinuz-$release"
