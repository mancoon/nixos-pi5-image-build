# Manual Loopback Build (8 GiB) for Pi 5 NixOS

This document shows every command needed to create an **8 GiB** Raspberry Pi 5 NixOS SD-card image, step by step.

## Folder layout

In this repo, you should see:

.
├── README.md
├── docs/
│   └── BUILD-LOOPBACK.md
└──

We’ll run all commands from `/root/nixos-pi5-image-build`.

## Prerequisites

- You must be root on the Pi 5 (so all mounts, losetup, and `nixos-install` work).
- `git` is installed.
- You have a working “installed” `/etc/nixos/configuration.nix` and  
  `/etc/nixos/hardware-configuration.nix` on this Pi 5—these will be copied later.

## 1. Clean up any previous leftovers

```bash
# Unmount any stale mounts under /mnt/img-root
umount -l /mnt/img-root/boot 2>/dev/null || true
umount -l /mnt/img-root       2>/dev/null || true

# Detach loop devices if they still point at old images
losetup -a | grep pi5-nixos-8G.img | awk -F: '{print $1}' \
  | xargs -r -n1 losetup -d || true

# Remove stale mount directories
rm -rf /mnt/img-root

# Verify cleanup
mount | grep /mnt/img-root || echo "No mounts under /mnt/img-root"
losetup -a | grep pi5-nixos-8G.img || echo "No loop devices remain for that image"

## 2. Create a blank 8 GiB image file

cd /root/nixos-pi5-image-build

# Remove old image if it exists
rm -f pi5-nixos-8G.img pi5-nixos-8G.img.zst

# Create an empty sparse file of exactly 8 GiB
truncate -s 8G pi5-nixos-8G.img
ls -lh pi5-nixos-8G.img  # should show "8.0G"

## 3. Associate image with a loop device
export LOOPDEV=$(losetup --show -fP ./pi5-nixos-8G.img)
echo "Image attached to: $LOOPDEV"
lsblk "$LOOPDEV"

# You should see something like:
loop0      7:0    0    8G  0 loop

## 4. Partition the loop device (GPT)

# We’ll use parted from Nixpkgs so you don’t have to install it system-wide:

#  Create a new GPT partition table
nix shell nixpkgs#parted -- parted -s "$LOOPDEV" mklabel gpt

#  Create partition 1 (EFI, 512 MiB, FAT32)
nix shell nixpkgs#parted -- \
  parted -s "$LOOPDEV" \
    mkpart ESP fat32 1MiB 513MiB

#  Create partition 2 (root, ext4, remainder of disk)
nix shell nixpkgs#parted -- \
  parted -s "$LOOPDEV" \
    mkpart NIXOS ext4 513MiB 100%

#  Mark partition 1 as bootable (EFI)
nix shell nixpkgs#parted -- \
  parted -s "$LOOPDEV" \
    set 1 boot on

# Verify

lsblk "$LOOPDEV"
# Expect:
# loop0      7:0    0    8G  0 loop
# ├─loop0p1 259:1    0  512M  0 part 
# └─loop0p2 259:2    0 7.5G  0 part 

## 5. Format both partitions

# Format partition 1 as FAT32, label "BOOT"
nix shell nixpkgs#dosfstools -- \
  mkfs.fat -F32 -n BOOT "${LOOPDEV}p1"

# Format partition 2 as ext4, label "NIXOS"
nix shell nixpkgs#e2fsprogs -- \
  mkfs.ext4 -L NIXOS "${LOOPDEV}p2"

# Check:
lsblk -f "$LOOPDEV"
# loop0p1 should say FSTYPE=vfat, LABEL=BOOT
# loop0p2 should say FSTYPE=ext4, LABEL=NIXOS

## 6. Mount the new partitions

# Create mountpoints
mkdir -p /mnt/img-root
mkdir -p /mnt/img-root/boot

# Mount root (ext4) partition
mount "${LOOPDEV}p2" /mnt/img-root

# Mount EFI (FAT32) under /mnt/img-root/boot
mount "${LOOPDEV}p1" /mnt/img-root/boot

# Quick check
mount | grep /mnt/img-root
# Should show:
# loop0p2 on /mnt/img-root type ext4 …
# loop0p1 on /mnt/img-root/boot type vfat …

## 7. Copy in your installed NixOS configs

# Create the target directory
mkdir -p /mnt/img-root/etc/nixos

# Copy your installed configs (for reference)
cp /etc/nixos/configuration.nix \
  /mnt/img-root/etc/nixos/configuration.nix

cp /etc/nixos/hardware-configuration.nix \
  /mnt/img-root/etc/nixos/hardware-configuration.nix

## 8. Put the “image” config into place

# Copy from our repo (later we’ll commit this version to Git)
cp configuration.image.nix \
  /mnt/img-root/etc/nixos/configuration.image.nix

## 9. Bind-mount /dev, /proc, /sys, /run into the image

# Ensure these mountpoints exist inside the image
mkdir -p /mnt/img-root/dev
mkdir -p /mnt/img-root/proc
mkdir -p /mnt/img-roo/sys
mkdir -p /mnt/img-root/run 

# Bind-mount host interfaces
mount --rbind /dev  /mnt/img-root/dev
mount --rbind /proc /mnt/img-root/proc
mount --rbind /sys  /mnt/img-root/sys
mount --rbind /run  /mnt/img-root/run

# Verify
mount | grep /mnt/img-root

# You should see entries for devtmpfs, proc, sysfs, tmpfs under /mnt/img-root/{dev,proc,sys,run}

## 10. Install NixOS into the image

# Now we run nixos-install inside that chroot, pointing it at our configuration.image.nix:
chroot /mnt/img-root /run/current-system/sw/bin/nixos-install \
  --no-root-passwd \
  --config /etc/nixos/configuration.image.nix 

# You should see output like “installation complete” once it finishes.

## 11. Cleanup & detach

sync

# Unmount /boot first
umount -l /mnt/img-root/boot   2>/dev/null || true

# Unmount everything under /mnt-img-root
umount -l /mnt/img-root/run    2>/dev/null || true
umount -l /mnt/img-root/sys    2>/dev/null || true
umount -l /mnt/img-root/proc   2>/dev/null || true
umount -l /mnt/img-root/dev    2>/dev/null || true

# Unmount the root mount itself
umount -l /mnt/img-root         2>/dev/null || true

# Detach loop devices
losetup -a | grep pi5-nixos-8G.img | awk -F: '{print $1}' \
  | xargs -r losetup -d

# Verify nothing remains:
mount | grep /mnt/img-root    && echo "Still mounted—manual cleanup needed"
losetup -a | grep pi5-nixos-8G.img && echo "Still looped—manual cleanup needed"

## 12. Compress the final image

zstd --ultra -22 -v pi5-nixos-8G.img -o pi5-nixos-8G.img.zst

# You now have pi5-nixos-8G.img.zst in of /root/nixos-pi5-image-build.
# Congratulation!

