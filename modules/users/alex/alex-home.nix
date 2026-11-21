# ===========================================================================
# modules/users/alex/alex-home.nix — Home Manager config for alex
#
# Machines: Alex-Desktop, Alex-Laptop
# Account: child account (restricted)
# Role: child machine — educational, creative, gaming
#
# This file is a function that accepts wallpaperDir from the flake.
# wallpaperDir is passed per-host in flake.nix:
#   Alex-Desktop → "PikaOS"
#   Alex-Laptop  → "PikaOS"
#
# Contents: XDG dirs and default browser, wallpapers + avatar + fastfetch image
# from the Assets input, shared kitty/fastfetch/starship/zsh setup, zoxide, fzf,
# direnv, Hytale, ssh-agent. Applied through the Home Manager user list in flake.nix.
#
# Restrictions that live at host level, not here:
#   - No sudo access
#   - DNS filtering via Cloudflare 1.1.1.3
#   - Login time restrictions (modules/users/alex/screen-time.nix)
#   - Flatpak disabled system-wide except for the local Hytale bundle
#   - Own Mojang account for Minecraft
#   - PikaOS wallpapers generate colorful color schemes via matugen
# ===========================================================================

# Function arguments: config/pkgs/lib are the module set; inputs are the flake
# inputs (assets, dotfiles, zsh); wallpaperDir comes from extraSpecialArgs in flake.nix.
{ config, pkgs, lib, inputs, wallpaperDir, ... }:

{
  imports = [
    ../../system/graphical/hytale.nix
    ../wallpapers.nix
  ];

  # =========================================================================
  # Home Manager basics
  # =========================================================================
  # Account name, home path and the Home Manager release the state format
  # follows (stateVersion: keep at the install-time release; do not bump for upgrades).
  home.username      = "alex";
  home.homeDirectory = "/home/alex";
  home.stateVersion  = "24.11";

  programs.home-manager.enable = true; # install the home-manager CLI for this user

  # =========================================================================
  # Browser — per-user choice (shared app defaults live in graphical/graphical.nix)
  # xdg.mimeApps.defaultApplications maps a MIME type or URL scheme to a .desktop
  # file: here web links and HTML open in Firefox. Other entries (mail, pdf,
  # image/*, ...) can be added the same way.
  # =========================================================================
  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/http"  = "firefox.desktop";
    "x-scheme-handler/https" = "firefox.desktop";
    "text/html"              = "firefox.desktop";
    "application/xhtml+xml"  = "firefox.desktop";
  };

  # =========================================================================
  # XDG User Directories
  #   enable               write ~/.config/user-dirs.dirs
  #   createDirectories    create the folders below at activation
  #   setSessionVariables  export XDG_*_DIR variables in the session
  #   desktop/documents/download/music/pictures/projects/videos/templates/
  #   publicShare          paths of the standard folders (null disables one)
  #   extraConfig          extra XDG_<NAME>_DIR entries
  #   package              xdg-user-dirs package (null to skip it)
  # =========================================================================
  xdg.userDirs = {
    enable            = true;
    createDirectories = true;
    setSessionVariables = true; # export XDG_*_DIR variables (explicit, so no default-change warning)

    desktop    = "${config.home.homeDirectory}/Desktop";
    documents  = "${config.home.homeDirectory}/Documents";
    download   = "${config.home.homeDirectory}/Downloads";
    music      = "${config.home.homeDirectory}/Music";
    pictures   = "${config.home.homeDirectory}/Pictures";
    videos     = "${config.home.homeDirectory}/Videos";
    templates  = "${config.home.homeDirectory}/Templates";
    publicShare = "${config.home.homeDirectory}/Public";
  };

  # =========================================================================
  # Extra directories
  # systemd user tmpfiles rules, "type path mode user group age": d = create the
  # directory if missing (age "-" = never cleaned).
  # =========================================================================
  systemd.user.tmpfiles.rules = [
    # Creative workspace
    "d ${config.home.homeDirectory}/Documents/Art                 0755 alex users -"
    "d ${config.home.homeDirectory}/Documents/School              0755 alex users -"
  ];

  # =========================================================================
  # Asset directories — home.file below links Pictures/Avatar into the Assets
  # input. This activation step (entryBefore checkLinkTargets, so it runs before
  # Home Manager checks link targets) removes an empty plain directory at those
  # paths, because a real directory would block the link.
  # =========================================================================
  home.activation.migrateAssetDirs = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    # Old ~/Pictures/Avatar plain dir → now symlinked at ~/Pictures/Avatar
    if [ -d "$HOME/Pictures/Avatar" ] && [ ! -L "$HOME/Pictures/Avatar" ]; then
      rmdir "$HOME/Pictures/Avatar" 2>/dev/null || true
    fi
    # Old ~/Documents/assets/flatpaks plain dir → now symlinked at ~/Documents/assets/flatpaks
    if [ -d "$HOME/Documents/assets/flatpaks" ] && [ ! -L "$HOME/Documents/assets/flatpaks" ]; then
      rmdir "$HOME/Documents/assets/flatpaks" 2>/dev/null || true
    fi
    # Remove ~/Documents/assets parent if empty
    if [ -d "$HOME/Documents/assets" ] && [ ! -L "$HOME/Documents/assets" ]; then
      rmdir "$HOME/Documents/assets" 2>/dev/null || true
    fi
  '';

  # Starship prompt — copy-once seed (not a symlink) so matugen's post-hook
  # can overwrite the live file after each wallpaper change. The template comes
  # from the ZSH repo (flake input "zsh"). Runs after writeBoundary; a symlink
  # at the target is removed first, an existing regular file is kept.
  home.activation.starshipSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _cfg="$HOME/.config/starship.toml"
    _template="${inputs.zsh}/starship/starship.toml"
    [ -L "$_cfg" ] && rm -f "$_cfg"
    if [ ! -f "$_cfg" ]; then
      cp "$_template" "$_cfg"
    fi
    # $_template is a Nix store path (read-only) — cp preserves that, so
    # matugen's own post-hook cp can't overwrite it without this.
    chmod u+w "$_cfg"
  '';

  # =========================================================================
  # Dotfiles — shared terminal setup with the rest of the family
  # home.file.<path>.source links a store path into $HOME. The starship config
  # is not here: it is seeded by home.activation.starshipSeed above (same
  # pattern as modules/users/linuxury/linuxury-home.nix).
  # =========================================================================
  home.file = {
    # Kitty terminal — shared config
    ".config/kitty/kitty.conf".source = "${inputs.dotfiles}/kitty/kitty.conf";

    # Fastfetch — shared config
    ".config/fastfetch".source = "${inputs.zsh}/fastfetch";

    # ~/Pictures/Wallpapers is a writable folder, filled from the Assets input
    # by modules/users/wallpapers. Both machines use "PikaOS" — set in
    # flake.nix. matugen generates colorful themes from them.

    # ~/Pictures/Avatar → <assets>/Avatar (family profile photos)
    "Pictures/Avatar".source =
      "${inputs.assets}/Avatar";

    # ~/.face.icon — SDDM reads this as the primary user avatar.
    ".face.icon".source =
      "${inputs.assets}/Avatar/alexander.jpg";

    # ~/Pictures/Fastfetch → <assets>/Fastfetch/alex (per-user image pool)
    "Pictures/Fastfetch".source =
      "${inputs.assets}/Fastfetch/alex";

  };

  # =========================================================================
  # Zsh shell
  #   autosuggestion.enable  grey inline history suggestions
  #   enableCompletion       tab completion
  #   plugins                fast-syntax-highlighting (command colouring)
  #   zsh-abbr.enable        fish-style abbreviations
  #   shellAliases.ll        long eza listing with icons and git status
  #   initContent            shared init from the ZSH repo (init.nix)
  # =========================================================================
  programs.zsh = {
    enable            = true;
    autosuggestion.enable = true;
    enableCompletion  = true;

    plugins = [
      {
        name = "fast-syntax-highlighting";
        src  = pkgs.zsh-fast-syntax-highlighting;
        file = "share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh";
      }
    ];

    zsh-abbr.enable = true;

    shellAliases = {
      ll = "eza -la --color=always --icons --group-directories-first --git";
    };

    initContent = import "${inputs.zsh}/init.nix" { inherit lib; };
  };

  # =========================================================================
  # Starship prompt — enable installs it and hooks zsh; the config file itself
  # is seeded by home.activation.starshipSeed.
  # =========================================================================
  programs.starship = {
    enable = true;
  };

  # =========================================================================
  # Zoxide — smarter cd (z <dir>); enableZshIntegration adds the zsh hook
  # =========================================================================
  programs.zoxide = {
    enable               = true;
    enableZshIntegration = true;
  };

  # =========================================================================
  # FZF — fuzzy finder; enableZshIntegration adds Ctrl-R/Ctrl-T/Alt-C bindings
  # =========================================================================
  programs.fzf = {
    enable               = true;
    enableZshIntegration = true;
  };

  # =========================================================================
  # Direnv — auto-loads .envrc on cd (nix develop shells, project env vars)
  #   enableZshIntegration  zsh hook
  #   nix-direnv.enable     fast cached `use flake` / `use nix`
  # =========================================================================
  programs.direnv = {
    enable               = true;
    enableZshIntegration = true;
    nix-direnv.enable    = true;
  };

  # =========================================================================
  # Hytale — auto-install + overrides (see modules/system/graphical/hytale.nix)
  # Flatpak is disabled system-wide on these machines except for the local Hytale
  # bundle; that exception is handled in hosts/Alex-Desktop and hosts/Alex-Laptop.
  # =========================================================================
  programs.hytale.enable = true;

  # =========================================================================
  # SSH agent — keeps loaded keys for the session; enabled for parity with the
  # other users, unused here
  # =========================================================================
  services.ssh-agent.enable = true;

  # Per-user packages: none declared in this file.
}
