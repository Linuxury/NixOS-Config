# ===========================================================================
# hosts/Ryzen5800x/disk.nix — filesystems and swap for Ryzen5800x
#
# One btrfs filesystem (label "nixos") split into subvolumes, a vfat EFI
# partition (label "EFI") at /boot, and a swapfile. No LUKS here. Split out of
# Ryzen5800x.nix so the installer can (re)write this file for a new disk layout
# without touching the rest of the host config. Network shares and pooled
# mounts (cifs, mergerfs) stay in Ryzen5800x.nix.
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
    # Steam's own subvolume — kept out of @home so /home btrfs snapshots
    # do not hold the large, constantly changing game library. Snapper has
    # no per-path exclude; a separate subvolume is the way to leave a path out
    # of a snapshot (same approach as @cache above).
    "/home/babylinux/.local/share/Steam" = {
      device = "/dev/disk/by-label/nixos";
      fsType = "btrfs";
      options = [ "subvol=@steam" "compress=zstd:1" "noatime" ];
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
    # -----------------------------------------------------------------------
    # Local NTFS HDD used as storage (label "Warehouse").
    # Uses the ntfs3 in-kernel driver (faster than FUSE ntfs-3g).
    #   uid/gid/umask    owner babylinux, group users (100), mode rwx for owner+group
    #   nofail noauto    boot continues without it; not mounted at boot
    #   x-systemd.automount  mount on first access; idle-timeout=60 unmounts after
    #                    60 s idle; mount-timeout=10s gives up after 10 s
    #   force            mount even if Windows left the dirty/hibernation flag set
    # -----------------------------------------------------------------------
    "/mnt/Warehouse" = {
      device  = "/dev/disk/by-label/Warehouse";
      fsType  = "ntfs3";
      options = [
        "uid=${toString config.users.users.babylinux.uid}" "gid=100"
        "umask=007"
        "nofail" "noauto"
        "x-systemd.automount" "x-systemd.idle-timeout=60"
        "x-systemd.mount-timeout=10s"
        "force"
      ];
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
