#!/usr/bin/env bash
set -euo pipefail

BASEDIR=$(realpath "$(dirname "$0")")
cd "$BASEDIR"

echo "→ Cleaning old mounts and loop devices…"
umount -l /mnt/img-root/boot   2>/dev/null || true
umount -l /mnt/img-root        2>/dev/null || true

losetup -a | grep "pi5-nixos-8G.img" | awk -F: '{print \$1}' \
  | xargs -r -n1 losetup -d || true

rm -rf /mnt/img-root

echo "→ Creating blank 8 GiB image file…"
rm -f pi5-nixos-8G.img pi5-nixos-8G.img.zst
truncate -s 8G pi5-nixos-8G.img

echo "→ Attaching to loop device…"
export LOOPDEV=$(losetup --show -fP ./pi5-nixos-8G.img)
echo "   → ${LOOPDEV}"
lsblk "$LOOPDEV"

echo "→ Partitioning $LOOPDEV…"
nix shell nixpkgs#parted -- parted -s "$LOOPDEV" mklabel gpt
nix shell nixpkgs#parted -- \
  parted -s "$LOOPDEV" mkpart ESP fat32 1MiB 513MiB
nix shell nixpkgs#parted -- \
  parted -s "$LOOPDEV" mkpart NIXOS ext4 513MiB 100%
nix shell nixpkgs#parted -- parted -s "$LOOPDEV" set 1 boot on

echo "→ Formatting partitions…"
nix shell nixpkgs#dosfstools -- mkfs.fat -F32 -n BOOT "${LOOPDEV}p1"
nix shell nixpkgs#e2fsprogs -- mkfs.ext4 -L NIXOS "${LOOPDEV}p2"

echo "→ Mounting partitions…"
mkdir -p /mnt/img-root /mnt/img-root/boot
mount "${LOOPDEV}p2" /mnt/img-root
mount "${LOOPDEV}p1" /mnt/img-root/boot

echo "→ Bind‐mount /dev, /proc, /sys, /run…"
mkdir -p /mnt/img-root/dev
mkdir -p /mnt/img-root/proc
mkdir -p /mnt/img-root/sys
mkdir -p /mnt/img-root/run
mount --rbind /dev  /mnt-img-root/dev
mount --rbind /proc /mnt-img-root/proc
mount --rbind /sys  /mnt-img-root/sys
mount --rbind /run  /mnt-img-root/run

echo "→ Copying configs into the image…"
mkdir -p /mnt/img-root/etc/nixos
cp configuration.nix            /mnt/img-root/etc/nixos/configuration.nix
cp hardware-configuration.nix   /mnt/img-root/etc/nixos/hardware-configuration.nix
cp configuration.image.nix      /mnt-img-root/etc/nixos/configuration.image.nix

echo "→ Installing NixOS into the image…"
chroot /mnt/img-root /run/current-system/sw/bin/nixos-install \
  --no-root-passwd \
  --config /etc/nixos/configuration.image.nix

echo "→ Cleaning up mounts and detaching…"
sync
umount -l /mnt/img-root/boot  2>/dev/null || true
umount -l /mnt/img-root/run   2>/dev/null || true
umount -l /mnt/img-root/sys   2>/dev/null || true
umount -l /mnt/img-root/proc  2>/dev/null || true
umount -l /mnt/img-root/dev   2>/dev/null || true
umount -l /mnt/img-root       2>/dev/null || true

losetup -a | grep "pi5-nixos-8G.img" | awk -F: '{print \$1}' \
  | xargs -r losetup -d

echo "→ Compressing final image…"
zstd --ultra -22 -v pi5-nixos-8G.img -o pi5-nixos-8G.img.zst

echo "✅ Done. Result: $(realpath pi5-nixos-8G.img.zst)"
