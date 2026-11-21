# ===========================================================================
# hosts/Alex-Desktop/disk.nix — local filesystems, swap and boot loader for the child account desktop
#
# Btrfs subvolumes on the "nixos" partition, a swapfile, and a legacy BIOS boot loader (GRUB
# on /dev/sda). There is no LUKS layer. The installer writes this file for a new disk layout.
# Network shares (CIFS) are in Alex-Desktop.nix.
# ===========================================================================
{ config, lib, pkgs, ... }:

{
  # Btrfs subvolumes on the "nixos" partition, mounted by label. Each uses zstd level 1
  # compression and noatime, except /swap, which is not compressed. The snapshot subvolumes
  # (@snapshots, @home_snapshots) are for snapper, which this host does not import.
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
    # Steam library, on its own subvolume (@steam). Keeping it out of @home means /home
    # snapshots do not retain the large game files. Snapper cannot exclude a path, so a
    # separate subvolume is the way to exclude it.
    "/home/alex/.local/share/Steam" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@steam" "compress=zstd:1" "noatime" ];
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
  };

  # ==============================================================
  # Swap — one swapfile on the @swap subvolume
  #   device  path of the swapfile
  # ==============================================================
  swapDevices = [{
    device = "/swap/swapfile";
  }];

  # ==============================================================
  # Boot loader — legacy BIOS (the M5A78L-M LX board has no UEFI)
  #   boot.loader.grub.enable   GRUB (set here)
  #   boot.loader.grub.device   disk GRUB installs to: /dev/sda (set here)
  #   systemd-boot and EFI variables are forced off, since there is no EFI
  # ==============================================================
  boot.loader.systemd-boot.enable = lib.mkForce false;

  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;

  boot.loader.grub = {
    enable = true;
    device = "/dev/sda";
  };
}
