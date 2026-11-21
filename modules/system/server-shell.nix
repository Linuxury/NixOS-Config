# ===========================================================================
# modules/system/server-shell.nix — Zsh config for headless servers
#
# Gives headless hosts the same zsh setup as desktops by embedding the
# shared zsh repo (flake input "zsh", see its init.nix), so the nru/nr/nrt
# functions and aliases live in one place. Everything is system-level
# (/etc/zsh/), so it applies to all users without Home Manager.
# Turn it on by importing it from a headless host (Radxa-X4, MinisForum,
# Media-Server); remove the import to turn it off.
#
# Server-only additions (not in the shared zshrc):
#   - TERM fallback (silences "can't find terminal definition" on SSH login)
#   - age-edit / age-rekey aliases (desktops use zsh-abbr for these)
#
# ===========================================================================

{ pkgs, lib, inputs, ... }:

{
  # SSH agent — starts ssh-agent as a systemd user service at login.
  #   agentTimeout           key lifetime (default null = forever)
  #   agentPKCS11Whitelist   allowed PKCS#11 provider paths
  programs.ssh.startAgent = true;

  # Starship — cross-shell prompt for all users.
  #   settings / presets       starship.toml content or named presets
  #   enable<Shell>Integration bash/zsh/fish/xonsh/nushell hooks (default on)
  programs.starship.enable = true;

  # Zoxide — `z` jumps to frequently used directories.
  #   flags                    extra `zoxide init` flags (e.g. "--cmd cd")
  #   enable<Shell>Integration per-shell hooks (default on)
  programs.zoxide.enable = true;

  # FZF — fuzzy finder.
  #   keybindings       Ctrl+R history, Ctrl+T file picker, Alt+C cd
  #   fuzzyCompletion   `**<Tab>` fuzzy completion
  programs.fzf.fuzzyCompletion = true;
  programs.fzf.keybindings     = true;

  # Direnv — loads .envrc on cd (nix develop shells, project env vars).
  #   nix-direnv.enable   cached `use flake` / `use nix`
  #   silent              hide direnv's load messages
  #   settings            direnv.toml content; direnvrcExtra extra direnvrc
  programs.direnv = {
    enable            = true;
    nix-direnv.enable = true;
  };

  # Fastfetch — system info on shell start, using the shared zsh repo's
  # config.jsonc (same as desktops).
  environment.systemPackages = [ pkgs.fastfetch ];
  environment.etc."fastfetch/config.jsonc".source = "${inputs.zsh}/fastfetch/config.jsonc";

  # TERM fallback — runs in /etc/zsh/zshenv before NixOS's set-environment
  # script, silencing "can't find terminal definition" errors on SSH login.
  programs.zsh.shellInit = ''
    if [ -n "$TERM" ] && ! infocmp "$TERM" >/dev/null 2>&1; then
      export TERM=xterm-256color
    fi
  '';

  # Zsh for all users.
  #   autosuggestions.enable    grey history suggestions (also: strategy,
  #                             highlightStyle, async)
  #   syntaxHighlighting.enable colour the command line (also: highlighters,
  #                             patterns, styles)
  #   shellAliases              aliases for every user
  #   interactiveShellInit      shared init from the zsh repo
  # Not set here: promptInit, histSize, histFile, setOptions,
  # enableCompletion, enableLsColors, ohMyZsh.
  programs.zsh = {
    enable                 = true;
    autosuggestions.enable  = true;
    syntaxHighlighting.enable = true;

    shellAliases = {
      # agenix secret management; run from the secrets/ directory, where
      # secrets.nix lives.
      age-edit  = "nix run github:ryantm/agenix -- -e";
      age-rekey = "nix run github:ryantm/agenix -- -r";
    };

    # Shared init — same shell config as desktop hosts.
    # init.nix embeds the file contents at eval time; shell ${...}
    # references are not interpreted by Nix, only by zsh at runtime.
    interactiveShellInit = import "${inputs.zsh}/init.nix" { inherit lib; };
  };
}
