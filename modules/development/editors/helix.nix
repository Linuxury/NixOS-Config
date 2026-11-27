# ===========================================================================
# modules/development/editors/helix.nix — Helix
#
# Modal terminal editor (binary: hx). Package only, default config:
# no ~/.config/helix is managed. Run `hx --health` to see which LSPs it finds.
#
# Enable per host by importing this module (remove the import to turn it off):
#   ../../modules/development/editors/helix.nix
# ===========================================================================

{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.helix ];
}
