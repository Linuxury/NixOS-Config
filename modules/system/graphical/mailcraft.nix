# ===========================================================================
# modules/system/graphical/mailcraft.nix — MailCraft mail/calendar client
#
# Packaged from the upstream GitHub release tarball in pkgs/mailcraft
# (version + hash in mailcraft.json, bumped by scripts/mailcraft-bump via nru).
# Public beta: Microsoft accounts only for now.
#
# Overlay is scoped here, so only hosts importing this module fetch it.
# ===========================================================================

{ pkgs, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      mailcraft = prev.callPackage ../../../pkgs/mailcraft/package.nix {};
    })
  ];

  environment.systemPackages = [ pkgs.mailcraft ];
}
