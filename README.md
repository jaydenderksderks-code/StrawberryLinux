# Strawberry Linux
```
     .-.
   .'   '.
  /  .-.  \
  | (   ) |
  \  '-'  /
   '.___.'
 STRAWBERRY LINUX
```

Strawberry Linux is an Arch Linux-based x86_64 live distribution with a red TTY theme, a protected rm wrapper, and a Strawberry-specific package interface. It uses Arch's stock linux kernel, not the former 6.12-strawberry source-built kernel.

## Build
On an Arch Linux host, install archiso and run `sudo bash build.sh x86_64`. The script starts from the official releng archiso profile, adds Strawberry's packages and overlay, and writes the ISO into `dist/`. A build requires network access, free disk space and root privileges. The ISO uses SquashFS, supports BIOS and UEFI, and logs root in automatically on tty1. The live-session marker is `/run/strawberry/live`.

## Commands
- `berryinstall`: interactive disk installer, Arch base via pacstrap, optional desktop selection and default zram. It erases the selected target disk after explicit confirmation. Read its disk safety prompts carefully.
- `str- I package`: install official package with pacman.
- `str- R package`: remove package.
- `str- U`: upgrade.
- `str- S query`: search.
- `str- Q`: list installed packages.
- `str- C https://aur.archlinux.org/name.git`: review and build AUR package without root.
- `str- help`: usage.

## Security and resources
The custom rm wrapper requests five consecutive y confirmations for recursive removal of / or a direct child, refuses --no-preserve-root and unknown flags, and normalizes paths with realpath. The sudo secure_path prioritizes /usr/local/bin. These protections are not substitutes for backups or filesystem permissions.

The no-desktop TTY profile minimizes graphical overhead. 128 MiB is an aspiration rather than a tested minimum: a modern Arch kernel, systemd and the live image may require significantly more RAM. Graphical environments need substantially more memory.

The installer uses a clean pacstrap target, copies only Strawberry-owned configuration, configures zram, users and GRUB, and removes live root autologin. Optional desktop branding is applied when a desktop is selected and the optional image exists.

## Tests
GitHub Actions runs Bash syntax checks and the non-destructive `tests/test-rm.py` regression suite on each push.
