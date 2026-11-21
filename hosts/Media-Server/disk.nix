# ===========================================================================
# hosts/Media-Server/disk.nix — local filesystems and swap for the Media-Server
#
# Btrfs subvolumes on the OS "nixos" partition, an EFI system partition, a swapfile, and
# the two ext4 HDDs that mergerfs pools into /data (in Media-Server.nix). There is no LUKS
# layer on this server. The installer writes this file for a new disk layout. Boot loader
# settings are not in this file.
# ===========================================================================
{ config, lib, pkgs, ... }:

{
  # Btrfs subvolumes on the OS partition, mounted by label. Each uses zstd level 1
  # compression and noatime, except /swap, which is not compressed. The snapshot subvolumes
  # are for snapper, which this host does not import.
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
    "/nix" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@nix" "compress=zstd:1" "noatime" ];
    };
    "/var/log" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@log" "compress=zstd:1" "noatime" ];
    };
    "/var/cache" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@cache" "compress=zstd:1" "noatime" ];
    };
    "/.snapshots" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@snapshots" "compress=zstd:1" "noatime" ];
    };
    "/home/.snapshots" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@home_snapshots" "compress=zstd:1" "noatime" ];
    };
    "/swap" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@swap" "noatime" ];
    };
    "/boot" = {
      device = "/dev/disk/by-label/EFI";
      fsType = "vfat";
      options = [ "fmask=0077" "dmask=0077" ];
    };
    # -----------------------------------------------------------------------
    # Individual HDD mounts — these feed into mergerfs
    # Both drives are ext4 formatted with labels disk1 and disk2
    # -----------------------------------------------------------------------
    "/mnt/disk1" = {
      device  = "/dev/disk/by-label/disk1";
      fsType  = "ext4";
      options = [ "noatime" "user_xattr" ];
    };
    "/mnt/disk2" = {
      device  = "/dev/disk/by-label/disk2";
      fsType  = "ext4";
      options = [ "noatime" "user_xattr" ];
    };
  };

  # ==============================================================
  # Swap — one swapfile on the @swap subvolume
  #   device  path of the swapfile
  # ==============================================================
  swapDevices = [{
    device = "/swap/swapfile";
  }];
}
