# ===========================================================================
# hosts/Ryzen5900x/disk.nix — local filesystems and swap for the Ryzen5900x desktop
#
# Btrfs subvolumes on the "nixos" partition, an EFI system partition, a swapfile and
# two XFS drives. There is no LUKS layer: Btrfs sits directly on the partition.
# The installer writes this file for a new disk layout. Network shares (CIFS) are in
# Ryzen5900x.nix. Boot loader settings are not in this file.
# ===========================================================================
{ config, lib, pkgs, ... }:

{
  # Btrfs subvolumes on the "nixos" partition, mounted by label. Each uses zstd level 1
  # compression and noatime, except /swap, which is not compressed (the swapfile needs
  # uncompressed Btrfs). The snapshot subvolumes (@snapshots, @home_snapshots) are for
  # snapper, which this host does not import (services/snapper.nix is commented out).
  fileSystems = {
    "/" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@"
        "compress=zstd:1"
        "noatime"
      ];
    };
    "/home" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@home"
        "compress=zstd:1"
        "noatime"
      ];
    };
    # Steam library, on its own subvolume (@steam). Keeping it out of @home means /home
    # snapshots do not retain the large game files. Snapper cannot exclude a path, so a
    # separate subvolume is the way to exclude it.
    "/home/linuxury/.local/share/Steam" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@steam" "compress=zstd:1" "noatime" ];
    };
    "/nix" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@nix"
        "compress=zstd:1"
        "noatime"
      ];
    };
    "/var/log" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@log"
        "compress=zstd:1"
        "noatime"
      ];
    };
    "/var/cache" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@cache"
        "compress=zstd:1"
        "noatime"
      ];
    };
    "/.snapshots" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@snapshots"
        "compress=zstd:1"
        "noatime"
      ];
    };
    "/home/.snapshots" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@home_snapshots"
        "compress=zstd:1"
        "noatime"
      ];
    };
    "/swap" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [
        "subvol=@swap"
        "noatime"
      ];
    };
    # EFI system partition (FAT, by label). fmask/dmask 0077: only root can read the files.
    "/boot" = {
      device = "/dev/disk/by-label/EFI";
      fsType = "vfat";
      options = [
        "fmask=0077"
        "dmask=0077"
      ];
    };
    # XFS drives, mounted by label. defaults: standard mount options. nofail: boot
    # continues if the drive is absent. x-gvfs-show: list the drive in GVfs file managers.
    "/mnt/Warehouse" = {
      device = "/dev/disk/by-label/Warehouse";
      fsType = "xfs";
      options = [
        "defaults"
        "nofail"
        "x-gvfs-show"
      ];
    };
    "/mnt/Games" = {
      device = "/dev/disk/by-label/Games";
      fsType = "xfs";
      options = [
        "defaults"
        "nofail"
        "x-gvfs-show"
      ];
    };
  };

  # ==============================================================
  # Swap — one swapfile on the @swap subvolume (swapDevices)
  #   device  path of the swapfile
  # ==============================================================
  swapDevices = [
    {
      device = "/swap/swapfile";
    }
  ];
}
