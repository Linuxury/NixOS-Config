# ===========================================================================
# hosts/MinisForum/disk.nix — local filesystems and swap for the MinisForum server
#
# Btrfs subvolumes on the "nixos" partition, an EFI system partition and a swapfile.
# There is no LUKS layer on this server. The installer writes this file for a new disk
# layout. Network shares (CIFS) are in MinisForum.nix. Boot loader settings are not in this file.
# ===========================================================================
{ config, lib, pkgs, ... }:

{
  # Btrfs subvolumes on the "nixos" partition, mounted by label. Each uses zstd level 1
  # compression and noatime, except /swap, which is not compressed. The snapshot subvolumes
  # (@snapshots, @home_snapshots) are for snapper; this host does not import it.
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
  };

  # ==============================================================
  # Swap — one swapfile on the @swap subvolume
  #   device  path of the swapfile
  # ==============================================================
  swapDevices = [{
    device = "/swap/swapfile";
  }];
}
