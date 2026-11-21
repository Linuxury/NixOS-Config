# ===========================================================================
# modules/system/graphical/mailcraft.nix — MailCraft mail/calendar client
#
# Installs MailCraft, a mail and calendar client that supports Microsoft
# accounts. Turn it on by importing this file from a host; remove the import
# to turn it off.
#
# The package is built in pkgs/mailcraft from the upstream release tarball.
# Its version and hash live in mailcraft.json and are bumped by
# scripts/mailcraft-bump (run from nru).
#
#   nixpkgs.overlays             adds pkgs.mailcraft; kept in this file so only
#                                hosts that import it build the package
#   environment.systemPackages   puts mailcraft on PATH with its .desktop entry
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
