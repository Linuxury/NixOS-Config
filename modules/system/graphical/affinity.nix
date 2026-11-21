# ===========================================================================
# modules/system/graphical/affinity.nix — Affinity v3 (Wine)
#
# Installs Affinity v3 (Photo, Designer, Publisher) under Wine, from the
# affinity-nix flake input. Imported by graphical.nix on every graphical
# host, but does nothing until a host turns it on:
#
#   programs.affinity.enable = true;    # default false
#
# The overlay is added only when enabled. Adding it always would make every
# rebuild query the garnix cache even on hosts that never install Affinity.
# ===========================================================================

{ inputs, config, lib, pkgs, ... }:

let cfg = config.programs.affinity; in

{
  options.programs.affinity.enable = lib.mkEnableOption "Affinity v3 via Wine (affinity-nix)";

  config = lib.mkIf cfg.enable {
    # The overlay builds affinity-v3 with this repo's nixpkgs, which has
    # allowUnfree = true (core.nix). The package is unfree, so
    # inputs.affinity-nix.packages.* would fail: that path uses the input's
    # own nixpkgs, which does not allow unfree packages.
    nixpkgs.overlays = [ inputs.affinity-nix.overlays.default ];

    environment.systemPackages = [ pkgs.affinity-v3 ];
  };
}
