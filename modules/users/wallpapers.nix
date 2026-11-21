# ===========================================================================
# modules/users/wallpapers.nix — writable ~/Pictures/Wallpapers
#
# A real folder in the user's home, so wallpapers can be added, replaced or
# deleted freely. It is filled from the Assets input (Wallpapers/<wallpaperDir>)
# by copying the files that are not there yet:
#   - files the user added are never touched
#   - files the user replaced or edited are never overwritten
#   - a repo wallpaper the user deleted comes back at the next rebuild
# New wallpapers pushed to the Assets repo therefore reach every machine with
# the next "nix flake update assets" + rebuild (nru does both).
#
# Imported by the three Home Manager user configs (alex, babylinux, linuxury).
# Arguments:
#   wallpaperDir  from extraSpecialArgs in flake.nix: "4k", "3440x1440" or "PikaOS"
#   inputs.assets the Assets flake input holding Wallpapers/<wallpaperDir>/
# To use it: add ../wallpapers.nix to a user's home imports; drop the import to
# stop managing the folder (existing files stay).
# ===========================================================================

{ pkgs, lib, inputs, wallpaperDir, ... }:

{
  # home.activation.wallpapers — runs after linkGeneration, which has already
  # removed any Home Manager symlink at the path, so what is left to create is
  # a plain folder. Alternative ordering: lib.hm.dag.entryBefore / entryAnywhere.
  home.activation.wallpapers = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    _dir="$HOME/Pictures/Wallpapers"
    [ -L "$_dir" ] && rm -f "$_dir"
    mkdir -p "$_dir"
    # --update=none: never overwrite. --no-preserve=mode: store files are
    # read-only, the copies must be writable. --reflink=auto: free on btrfs.
    ${pkgs.coreutils}/bin/cp -r --update=none --no-preserve=mode --reflink=auto \
      "${inputs.assets}/Wallpapers/${wallpaperDir}/." "$_dir/"
  '';
}
