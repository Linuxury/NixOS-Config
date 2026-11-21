# ===========================================================================
# modules/system/graphical/claude-desktop.nix — Claude Desktop
#
# Installs the Claude Desktop app for Linux. Turn it on by importing this
# file from a host; remove the import to turn it off.
#
# The package is built in pkgs/claude-desktop/package.nix from Anthropic's
# .deb; its version and hash live there. Sign-in needs a Secret Service
# provider; the Hyprland, Niri, Umbriel and COSMIC modules already enable
# gnome-keyring.
#
#   nixpkgs.overlays             adds pkgs.claude-desktop; kept in this file so
#                                only hosts that import it build the package
#   environment.systemPackages   puts claude-desktop on PATH
#   home.activation.registerVaultMcp   (linuxury only, see below)
#
# Vault MCP (linuxury only): a filesystem MCP server named "vault" is merged
# into ~/.config/Claude/claude_desktop_config.json so Chat can read the live
# rules and vault: ~/Jarvis, ~/.agents/Shared (AGENTS.md) and
# ~/.agents/memory. Not the rest of ~/.agents: ~/.agents/Claude holds Claude
# Code's settings.json, which Chat must not be able to edit.
# ===========================================================================

{ lib, pkgs, ... }:

let
  home = "/home/linuxury";
  vaultServer = pkgs.writeText "vault-mcp-server.json" (builtins.toJSON {
    command = lib.getExe pkgs.mcp-server-filesystem;
    args = [ "${home}/Jarvis" "${home}/.agents/Shared" "${home}/.agents/memory" ];
  });
in
{
  nixpkgs.overlays = [
    (final: prev: {
      claude-desktop = prev.callPackage ../../../pkgs/claude-desktop/package.nix {};
    })
  ];

  environment.systemPackages = [ pkgs.claude-desktop ];

  # Merges the "vault" server into claude_desktop_config.json the same way
  # registerCraftMcp (craft-apps.nix) does: only the "vault" key is replaced,
  # every other server is kept, invalid JSON is left alone with a warning, and
  # the write goes to a temp file first and is then moved into place.
  home-manager.users.linuxury = { lib, ... }: {
    home.activation.registerVaultMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      run mkdir -p "${home}/.config/Claude"
      _cfg="${home}/.config/Claude/claude_desktop_config.json"
      _cur=$(cat "$_cfg" 2>/dev/null || printf '{}')
      if _new=$(printf '%s' "$_cur" | ${lib.getExe pkgs.jq} \
          --slurpfile s ${vaultServer} '.mcpServers = ((.mcpServers // {}) + { vault: $s[0] })'); then
        if [ "$_new" != "$_cur" ]; then
          printf '%s\n' "$_new" | run tee "$_cfg.hm-tmp" > /dev/null
          run mv "$_cfg.hm-tmp" "$_cfg"
        fi
      else
        warnEcho "registerVaultMcp: $_cfg is not valid JSON; left untouched"
      fi
      unset _cfg _cur _new
    '';
  };
}
