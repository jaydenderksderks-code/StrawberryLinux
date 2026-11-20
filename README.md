# Strawberry Linux

```text
       .  .  .
      .\ | /.
       \|/
     .-^-.
    /     \
   |  . .  |
   | . . . |
    \ . . /
     \___/
 STRAWBERRY LINUX
```

Strawberry Linux is an experimental, TTY-first Linux distribution project inspired by Linux From Scratch. The repository currently builds a minimal BusyBox-based live environment with a pinned Linux kernel, initramfs, GRUB BIOS/UEFI boot media, and automated QEMU boot smoke tests. It is an early live-system prototype, not yet a complete LFS installation or general-purpose operating system.

## Architecture and scope

- **CPUs:** x86_64 (default), i686 (32-bit x86).
- **Interface:** pure Linux virtual terminal (`tty`) by default, optional `graphics` kernel configuration for future window managers and desktop environments.
- **Memory:** 128 MiB RAM is a *design target*, not a measured or guaranteed boot requirement. Memory usage will depend on the eventual init system, userspace, kernel and hardware.
- **Security:** HTTPS source retrieval, an isolated GPG keyring with a pinned kernel signing fingerprint, SHA-256 artifact checksums, restricted root-level recursive deletion, and unprivileged builds. These measures do not constitute a complete security audit, secure boot chain, or a sandbox.

## Repository

```text
.github/workflows/ci.yml             GitHub Actions checks
.gitignore                           Generated artifact exclusions
build.sh                             Verified kernel download and build
kernel/configure.sh                  Kernel configuration and validation
locks/linux.version                  Pinned Linux version
locks/linux-signer.fingerprint       Pinned kernel signer
rootfs/etc/profile                   Shell environment
rootfs/etc/profile.d/strawberry.bash TTY welcome, prompt and colors
rootfs/etc/sudoers.d/10-strawberry-path  sudo PATH policy
rootfs/usr/local/bin/rm              Recursive deletion guard
rootfs/usr/share/strawberry/logo.txt ASCII logo
tests/test-rm.py                     PTY-based regression tests
```

## Build

Use a non-root Linux build account on an ext4, xfs, btrfs, or f2fs filesystem. Install `bash`, `curl`, `gnupg`, `tar`, `xz`, `make`, `gcc`, `bc`, `flex`, `bison`, `openssl`, ELF development libraries, and the other kernel build dependencies. For i686 builds, a working 32-bit cross-compiler or multilib-capable toolchain may be required. Ensure enough disk space and memory for compiling the kernel: the 128 MiB target is for the eventual installed runtime, **not** the build host.

```sh
chmod +x build.sh kernel/configure.sh rootfs/usr/local/bin/rm tests/test-rm.py
./build.sh x86_64 tty
./build.sh i686 tty
./build.sh x86_64 graphics
python3 tests/test-rm.py

# Build the x86_64 live TTY ISO (requires the ISO build dependencies)
./iso/build-iso.sh x86_64
```

`STRAWBERRY_WORK` overrides the default `work/` directory. Build output is written to `kernel/artifacts/<cpu>/<ui>/` and contains the kernel image, kernel `.config`, source tarball SHA-256 digest, and `SHA256SUMS` for produced artifacts.

The build fetches the kernel.org compressed tarball and detached signature and verifies the uncompressed tar stream against the exact pinned signer fingerprint. Keep the fingerprint lock under code review. The pinned version `6.12` is the base 6.12 release, not the latest 6.12.y maintenance update; do not assume it contains subsequent security fixes.

## Root filesystem behavior

When deployed into a compatible userspace, `/etc/profile` sets a predictable PATH and Bash interactive TTY sessions can display fastfetch, a red prompt and optional live installer hint. `berryinstall` is not yet provided. `fastfetch` and `sudo` are optional userspace dependencies, not built by this repository.

`/usr/local/bin/rm` delegates to `/bin/rm`, but requires five consecutive `y` answers on a controlling terminal before recursively removing `/` or a direct child of `/`. It rejects `--no-preserve-root` and unknown options. The guard is **not** a system-wide deletion policy: absolute `/bin/rm`, other deletion utilities, scripts and privileged operations can bypass it. Use filesystem permissions and backups as primary safeguards. Do not run the regression suite against the real deletion command; tests replace it with `/bin/echo` in a temporary copy.

## Current boundaries

Implemented: verified kernel source acquisition, deterministic kernel build metadata, configuration validation, rootfs overlay files, a protected command wrapper, and CI checks. Not implemented: full LFS toolchain and userspace, init, service management, device population, package manager, installer, bootloader, initramfs, live environment, ISO/image builder, graphical session, hardware qualification, and 128 MiB boot testing.

A kernel image alone is not a bootable Strawberry Linux distribution. Future milestones must integrate and test those components before production use.

## License and upstream

Linux kernel sources are separately licensed by their upstream authors. Review licenses for every eventual userspace package before distribution.
