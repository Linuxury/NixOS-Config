# ===========================================================================
# modules/development/editors/helix.nix — Helix
#
# Modal terminal editor (binary: hx). Run `hx --health` to see which LSPs it
# finds. Only config.toml is managed (theme = noctalia); themes/noctalia.toml
# is written by Noctalia itself, so themes/ stays unmanaged and writable.
#
# Enable per host by importing this module (remove the import to turn it off):
#   ../../modules/development/editors/helix.nix
# ===========================================================================

{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.helix ];

  home-manager.users.linuxury.xdg.configFile."helix/config.toml".text = ''
    theme = "noctalia"
  '';
}
