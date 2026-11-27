# ===========================================================================
# modules/development/editors/helix.nix — Helix extras for graphical hosts
#
# The helix package and EDITOR=hx come from modules/system/core.nix (every
# host). This module adds, on graphical hosts:
#   - language servers Helix finds on $PATH (run `hx --health <lang>`)
#   - a "Helix" desktop entry (opens in Kitty) as the default for text files
#   - for linuxury only: ~/.config/helix/config.toml linked to the dotfiles
#     repo (~/dotfiles/helix/). themes/noctalia.toml is written by Noctalia
#     itself, so themes/ stays unmanaged and writable. Other users get
#     Helix's built-in defaults.
#
# Enable per host by importing this module (remove the import to turn it off):
#   ../../modules/development/editors/helix.nix
# ===========================================================================

{ pkgs, lib, ... }:

{
  # Language servers (rust-analyzer and ruff come from the language modules).
  environment.systemPackages = with pkgs; [
    nixd                          # Nix
    bash-language-server          # Bash / sh
    lua-language-server           # Lua
    vscode-langservers-extracted  # JSON, CSS, HTML
    taplo                         # TOML
    marksman                      # Markdown
  ];

  # sharedModules: applied to every Home Manager user on the host. The
  # linuxury-only part is guarded by home.username, so importing this module
  # on a babylinux/alex host does not create a linuxury HM profile.
  home-manager.sharedModules = [
    ({ config, ... }: {
      # Live link into the ~/dotfiles clone: edits there apply on the next hx start.
      xdg.configFile."helix/config.toml" = lib.mkIf (config.home.username == "linuxury") {
        source = config.lib.file.mkOutOfStoreSymlink
          "${config.home.homeDirectory}/dotfiles/helix/config.toml";
      };

      # Helix desktop entry — opens files in Kitty (Kitty is on every graphical host).
      # Named "Helix" (capital H) to match the package's own Helix.desktop: the per-user
      # profile comes first in XDG_DATA_DIRS, so this one shadows it and the menu shows one entry.
      xdg.desktopEntries.Helix = {
        name        = "Helix";
        genericName = "Text Editor";
        comment     = "Modal terminal text editor";
        exec        = "kitty hx %F";
        terminal    = false;
        categories  = [ "Utility" "TextEditor" ];
        icon        = "helix";
        mimeType    = [
          "text/plain"
          "application/json"
          "application/x-yaml"
          "application/toml"
          "application/x-shellscript"
          "text/x-shellscript"
        ];
      };

      # Text files open in Helix.
      xdg.mimeApps.defaultApplications = {
        "text/plain"                = "Helix.desktop";
        "application/json"          = "Helix.desktop";
        "application/x-yaml"        = "Helix.desktop";
        "application/toml"          = "Helix.desktop";
        "application/x-shellscript" = "Helix.desktop";
        "text/x-shellscript"        = "Helix.desktop";
      };
    })
  ];
}
