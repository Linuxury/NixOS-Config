# ===========================================================================
# hosts/ThinkPad/disk.nix — local filesystems, LUKS and swap for the ThinkPad
#
# Btrfs subvolumes inside a LUKS container, an EFI system partition and a swapfile.
# The installer writes this file for a new disk layout. Network shares (CIFS) are in
# ThinkPad.nix. Boot loader settings are not in this file.
# ===========================================================================
{ config, lib, pkgs, ... }:

{
  # Btrfs subvolumes on the "nixos" partition (inside LUKS, see below), mounted by label.
  # Each uses zstd level 1 compression and noatime, except /swap, which is not compressed.
  # The snapshot subvolumes (@snapshots, @home_snapshots) are for snapper, which this host
  # does not import (services/snapper.nix is commented out in ThinkPad.nix).
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
      # No compression on swap: the swapfile must be on uncompressed Btrfs.
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
  };

  # ==============================================================
  # LUKS full-disk encryption (boot.initrd.luks.devices.cryptroot)
  #   device        the raw encrypted partition, by label "nixos-luks" (set here)
  #   allowDiscards pass TRIM through LUKS to the SSD (set here)
  # The BTRFS partition sits inside this container. A passphrase prompt appears at boot,
  # and after unlocking the device is /dev/mapper/cryptroot.
  # ==============================================================
  boot.initrd.luks.devices."cryptroot" = {
    device = "/dev/disk/by-label/nixos-luks";
    allowDiscards = true;
  };

  # ==============================================================
  # Swap — one swapfile on the @swap subvolume
  #   device  path of the swapfile
  # ==============================================================
  swapDevices = [
    {
      device = "/swap/swapfile";
    }
  ];
}
