# ===========================================================================
# hosts/Radxa-X4/disk.nix — filesystems and swap for Radxa-X4
#
# One btrfs filesystem (label "nixos") split into subvolumes, a vfat EFI
# partition (label "EFI") at /boot, and a swapfile. No LUKS here. Split out of
# Radxa-X4.nix so the installer can (re)write this file for a new disk layout
# without touching the rest of the host config. Network shares and pooled
# mounts (cifs, mergerfs) stay in Radxa-X4.nix.
#
# Mount options used:
#   subvol=@<name>   btrfs subvolume to mount
#   compress=zstd:1  transparent zstd compression, level 1 (fast)
#   noatime          no access-time writes
#   fmask/dmask=0077 /boot files and dirs accessible by root only
# ===========================================================================
{ config, lib, pkgs, ... }:

{
  # One entry per mount point; device is the btrfs label, subvol picks the subvolume.
  # Separate subvolumes for /home, /nix, /var/log and /var/cache keep snapshots
  # of / small; /.snapshots and /home/.snapshots hold snapper's snapshots.
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
    # Own subvolume for the swapfile (no compression: btrfs swapfiles must be
    # uncompressed and nodatacow).
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
  # Swap — swapfile inside the @swap subvolume (size is set when the file is
  # created, not here)
  # ==============================================================
  swapDevices = [{
    device = "/swap/swapfile";
  }];
}
