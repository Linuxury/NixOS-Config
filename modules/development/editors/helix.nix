# ===========================================================================
# modules/development/editors/helix.nix — Helix
#
# Modal terminal editor (binary: hx). Run `hx --health` to see which LSPs it
# finds. config.toml lives in the dotfiles repo (~/dotfiles/helix/) and is
# linked as a single file; themes/noctalia.toml is written by Noctalia itself,
# so themes/ stays unmanaged and writable.
#
# Enable per host by importing this module (remove the import to turn it off):
#   ../../modules/development/editors/helix.nix
# ===========================================================================

{ pkgs, ... }:

{
  # taplo: TOML language server; marksman: Markdown language server.
  # Other languages reuse servers installed by the neovim/zed/language modules.
  environment.systemPackages = with pkgs; [ helix taplo marksman ];

  # Live link into the ~/dotfiles clone: edits there apply on the next hx start.
  home-manager.users.linuxury = { config, ... }: {
    xdg.configFile."helix/config.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/helix/config.toml";
  };
}
