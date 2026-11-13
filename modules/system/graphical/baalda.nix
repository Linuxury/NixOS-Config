# ===========================================================================
# modules/system/graphical/baalda.nix — Baalda desktop (local-first notes)
#
# Packaged from the upstream GitHub release .deb in pkgs/baalda (version + hash
# in baalda.json, shared with the server and bumped by scripts/baalda-bump via nru).
# Connects to the self-hosted server on Media-Server (modules/services/baalda).
#
# Overlay is scoped here, so only hosts importing this module fetch it.
# ===========================================================================

{ pkgs, ... }:

{
  nixpkgs.overlays = [
    (final: prev: {
      baalda = prev.callPackage ../../../pkgs/baalda/desktop.nix {};
    })
  ];

  environment.systemPackages = [ pkgs.baalda ];
}
