# ===========================================================================
# modules/system/graphical/app-nowted.nix — Nowted notes app
#
# Not in nixpkgs; pkgs/nowted/package.nix wraps upstream's AppImage. Turn it
# on by importing this file from a host; remove the import to turn it off.
#
#   nixpkgs.overlays             adds pkgs.nowted; kept here so only hosts that
#                                import this file evaluate the package
#   environment.systemPackages   pkgs.nowted (ships its own .desktop and icons)
#
# Update: scripts/nowted-bump
# ===========================================================================

{ pkgs, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      nowted = prev.callPackage ../../../pkgs/nowted/package.nix { };
    })
  ];

  environment.systemPackages = [ pkgs.nowted ];
}
