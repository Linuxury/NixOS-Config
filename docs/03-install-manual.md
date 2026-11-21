# Install by hand

This guide produces the same disk layout as the [installer](02-install.md): the same labels, btrfs subvolumes and mount options. Use it when you cannot or do not want to run the installer. After the install, continue with [04-first-boot.md](04-first-boot.md).

## Before you start

1. Boot the NixOS live ISO (the graphical or minimal image both work) and open a root shell: `sudo -i`.
2. Get a network connection. The install downloads everything.

   ```bash
   ping -c 3 nixos.org     # wired networks usually work already
   nmtui                   # Wi-Fi: "Activate a connection"
   ```

3. Pick the host. It must exist in `flake.nix` (see the host table in the [README](../README.md)). To add a new host, see [05-flake-and-modules.md](05-flake-and-modules.md) first. Each host has a primary user (`linuxury`, `babylinux` or `alex`), set by the `user` line of its `mkHost` entry in `flake.nix`.
4. Check the firmware mode. The partition layout differs.

   ```bash
   [ -d /sys/firmware/efi ] && echo UEFI || echo "legacy BIOS"
   ```

5. Set the variables used below. Find the disk with `lsblk`.

   ```bash
   export DISK=/dev/nvme0n1          # the whole disk; everything on it is erased
   export HOST=ThinkPad
   export NIXUSER=linuxury
   # Partition names: NVMe and MMC disks add a "p" (nvme0n1p1), SATA disks do not (sda1)
   export P1=${DISK}p1 P2=${DISK}p2  # for /dev/sda use: P1=${DISK}1 P2=${DISK}2
   ```

## 1. Partition

Both layouts use a GPT table with two partitions. Partition 2 is always the root partition.

**UEFI: EFI system partition (1 GiB) and root**

```bash
wipefs -a $DISK
parted -s $DISK -- mklabel gpt
parted -s $DISK -- mkpart ESP fat32 1MiB 1GiB set 1 esp on mkpart root 1GiB 100%
udevadm settle
mkfs.fat -F32 -n EFI $P1
```

**Legacy BIOS: BIOS boot partition (1 MiB) and root**

GRUB embeds itself in the BIOS boot partition. There is no `/boot` partition; `/boot` lives on the root filesystem.

```bash
wipefs -a $DISK
parted -s $DISK -- mklabel gpt
parted -s $DISK -- mkpart bios 1MiB 2MiB set 1 bios_grub on mkpart root 2MiB 100%
udevadm settle
```

## 2. Encryption (optional)

Skip this section for an unencrypted install. To encrypt the root partition with LUKS2:

```bash
cryptsetup luksFormat --type luks2 --label nixos-luks1 $P2
cryptsetup open $P2 cryptroot1
export ROOT=/dev/mapper/cryptroot1
```

Without encryption, set `export ROOT=$P2` instead.

The label `nixos-luks1` and the mapper name `cryptroot1` must match the `boot.initrd.luks.devices` entry you write in `disk.nix` (step 6).

## 3. Btrfs and subvolumes

The root filesystem is labelled `nixos`. `disk.nix` finds it by that label.

```bash
mkfs.btrfs -f -L nixos $ROOT
udevadm settle
mount $ROOT /mnt
for s in @ @home @nix @log @cache @snapshots @home_snapshots @swap; do
  btrfs subvolume create /mnt/$s
done
umount /mnt
```

## 4. Mount

Mount by label, root first. `@swap` has no compression because a swapfile needs uncompressed btrfs.

```bash
O=compress=zstd:1,noatime
mount -o subvol=@,$O                  /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/{home,nix,var/log,var/cache,.snapshots,home/.snapshots,swap}
mount -o subvol=@home,$O              /dev/disk/by-label/nixos /mnt/home
mount -o subvol=@nix,$O               /dev/disk/by-label/nixos /mnt/nix
mount -o subvol=@log,$O               /dev/disk/by-label/nixos /mnt/var/log
mount -o subvol=@cache,$O             /dev/disk/by-label/nixos /mnt/var/cache
mount -o subvol=@snapshots,$O         /dev/disk/by-label/nixos /mnt/.snapshots
mount -o subvol=@home_snapshots,$O    /dev/disk/by-label/nixos /mnt/home/.snapshots
mount -o subvol=@swap,noatime         /dev/disk/by-label/nixos /mnt/swap
```

On UEFI, mount the ESP:

```bash
mkdir -p /mnt/boot
mount -o umask=0077 /dev/disk/by-label/EFI /mnt/boot
```

Create the swapfile (size in GB; the installer uses the RAM size, capped at 16):

```bash
btrfs filesystem mkswapfile --size 16G /mnt/swap/swapfile
```

### Layout summary

| Subvolume | Mount point | Options |
|-----------|-------------|---------|
| `@` | `/` | `compress=zstd:1,noatime` |
| `@home` | `/home` | `compress=zstd:1,noatime` |
| `@nix` | `/nix` | `compress=zstd:1,noatime` |
| `@log` | `/var/log` | `compress=zstd:1,noatime` |
| `@cache` | `/var/cache` | `compress=zstd:1,noatime` |
| `@snapshots` | `/.snapshots` | `compress=zstd:1,noatime` |
| `@home_snapshots` | `/home/.snapshots` | `compress=zstd:1,noatime` |
| `@swap` | `/swap` | `noatime` |

| Label | What | Filesystem |
|-------|------|-----------|
| `EFI` | ESP at `/boot` (UEFI only) | vfat |
| `nixos` | root (inside LUKS when encrypted) | btrfs |
| `nixos-luks1` | LUKS partition (encrypted installs only) | LUKS2 |

## 5. Clone the repo

The config lives in the primary user's home, so it is already in place after the first boot.

```bash
mkdir -p /mnt/home/$NIXUSER
git clone https://github.com/Linuxury/nixos-config /mnt/home/$NIXUSER/nixos-config
git config --global --add safe.directory /mnt/home/$NIXUSER/nixos-config
```

## 6. Write hosts/&lt;host&gt;/disk.nix

Hosts mount their disks by label from `hosts/<host>/disk.nix`, which the host file imports (`./disk.nix`). There is no generated hardware file. If you are reinstalling an existing host with the same layout, `disk.nix` already exists: check that its labels match the ones above and skip to step 7.

For a new host, create `hosts/$HOST/disk.nix`. Start from a real file such as `hosts/Ryzen5900x/disk.nix` (plain) or `hosts/ThinkPad/disk.nix` (LUKS). The shape, shortened from `hosts/ThinkPad/disk.nix`:

```nix
{ config, lib, pkgs, ... }:

{
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@" "compress=zstd:1" "noatime" ];
    };
    "/home" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@home" "compress=zstd:1" "noatime" ];
    };
    # ... same pattern for /nix (@nix), /var/log (@log), /var/cache (@cache),
    #     /.snapshots (@snapshots), /home/.snapshots (@home_snapshots)
    "/swap" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@swap" "noatime" ];
    };
    "/boot" = {                                   # UEFI only
      device = "/dev/disk/by-label/EFI";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
  };

  swapDevices = [ { device = "/swap/swapfile"; } ];

  # Encrypted installs only (matches step 2)
  boot.initrd.luks.devices."cryptroot1" = {
    device = "/dev/disk/by-label/nixos-luks1";
    allowDiscards = true;
  };
}
```

Notes:

- `hosts/ThinkPad/disk.nix` names its LUKS device `cryptroot` and label `nixos-luks`; the installer and this guide use `cryptroot1` and `nixos-luks1`. Any pair works as long as `disk.nix` matches the label you gave `cryptsetup`.
- The existing hosts also mount an `@steam` subvolume over the Steam library path. That is optional and not part of the base layout above.
- The installer writes the `/boot` options as `umask=0077`; existing hosts use `fmask=0077` and `dmask=0077`. Both restrict `/boot` to root.

### Boot loader

- **UEFI:** nothing to add. `modules/system/core.nix` enables systemd-boot for every host.
- **Legacy BIOS:** switch to GRUB in `disk.nix`, as `hosts/Alex-Desktop/disk.nix` does. Use a stable `/dev/disk/by-id/...` path for the disk if you can; `hosts/Alex-Desktop/disk.nix` uses `/dev/sda`.

  ```nix
  boot.loader.systemd-boot.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };
  ```

Commit the file so the flake sees it (flakes ignore untracked files):

```bash
git -C /mnt/home/$NIXUSER/nixos-config add hosts/$HOST/disk.nix
```

## 7. Secrets and the host key

Secrets are encrypted to each host's SSH host key, so a new host needs a key that is registered before the install can decrypt anything. The full procedure is in [06-secrets.md](06-secrets.md). In short:

1. Create the host key in the target system.

   ```bash
   mkdir -p /mnt/etc/ssh
   ssh-keygen -q -t ed25519 -N "" -C "root@$HOST" -f /mnt/etc/ssh/ssh_host_ed25519_key
   cat /mnt/etc/ssh/ssh_host_ed25519_key.pub
   ```

2. On the admin machine, add that public key as an entry for `$HOST` in `secrets/secrets.nix`, then re-key from the `secrets/` directory:

   ```bash
   cd ~/nixos-config/secrets
   nix run nixpkgs#ragenix -- -r
   ```

3. Commit and push the re-keyed secrets, then pull them on the target:

   ```bash
   git -C /mnt/home/$NIXUSER/nixos-config pull --rebase
   ```

For a reinstall, the host key is new unless you restore the old one to `/mnt/etc/ssh/` first. If you skip this step, the install still works but secrets fail to decrypt until the host is registered and rebuilt.

## 8. Install

```bash
nixos-install --flake /mnt/home/$NIXUSER/nixos-config#$HOST --no-root-passwd
nixos-enter --root /mnt -- passwd $NIXUSER
chown -R $(awk -v u=$NIXUSER '$1==u {gsub(/;/,"",$3); print $3}' /mnt/home/$NIXUSER/nixos-config/modules/users/uids.nix):100 /mnt/home/$NIXUSER
```

- `--no-root-passwd` skips the root password; log in as the primary user.
- `passwd` sets that user's password inside the new system.
- The `chown` hands the home directory, including the clone, to the user. It reads the user's fixed UID from `modules/users/uids.nix` (`linuxury` 1000, `babylinux` 1001, `alex` 1002).

## 9. Reboot

```bash
swapoff -a
umount -R /mnt
reboot
```

If you encrypted the disk, the boot asks for the LUKS passphrase. Remove the ISO and continue with [04-first-boot.md](04-first-boot.md). If something fails, see [14-troubleshooting.md](14-troubleshooting.md).
