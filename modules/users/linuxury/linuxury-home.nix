# ===========================================================================
# modules/users/linuxury/linuxury-home.nix — Home Manager config for linuxury
#
# Machines: ThinkPad (laptop), Ryzen5900x (desktop)
# Role: Admin, developer, power user
#
# Per-host values are injected via extraSpecialArgs in flake.nix:
#   wallpaperDir     ThinkPad → "4k" | Ryzen5900x → "3440x1440"
#   hypridleProfile  ThinkPad → "laptop" | Ryzen5900x → "desktop"
#
# Contents: session PATH/env vars, default browser, XDG dirs, dotfile links and
# seeds (kitty, starship, hypr, fastfetch, MangoHud, topgrade, nano, wayle), AI
# config symlinks into ~/.agents, Assets pictures, SSH client config, zsh, git,
# zoxide, fzf, direnv, ssh-agent, Hytale, hypridle profile. Applied through the
# Home Manager user list in flake.nix.
# ===========================================================================

# Function arguments: config/pkgs/lib are the module set; inputs are the flake
# inputs (assets, dotfiles, zsh); wallpaperDir and hypridleProfile come from
# extraSpecialArgs in flake.nix.
{
  config,
  pkgs,
  lib,
  inputs,
  wallpaperDir,
  hypridleProfile,
  ...
}:

{
  imports = [
    ../../system/graphical/hytale.nix
    ../wallpapers.nix
    ../../system/graphical/nautilus.nix
    #../../system/graphical/thunar.nix   # alternative file manager, not imported (Luciole is the default)
  ];

  # =========================================================================
  # Home Manager basics
  # =========================================================================
  # Account name, home path and the Home Manager release the state format
  # follows (stateVersion: keep at the install-time release; do not bump for upgrades).
  home.username = "linuxury";
  home.homeDirectory = "/home/linuxury";
  home.stateVersion = "24.11";

  programs.home-manager.enable = true; # install the home-manager CLI for this user

  # =========================================================================
  # Session PATH — expose Nix profile bin to GUI apps
  #
  # GUI apps launched from Hyprland run inside a systemd user session whose
  # PATH comes from environment.d configs, not from shell profiles.
  # Without this, apps like Zed can't find binaries installed via
  # Home Manager (e.g. claude-code, nil, nixfmt).
  #
  # home.sessionPath (list of directories prepended to PATH) writes to
  # ~/.config/environment.d/ which systemd user sessions read automatically —
  # no shell involved.
  # =========================================================================
  home.sessionPath = [
    "/run/wrappers/bin"
    "/etc/profiles/per-user/linuxury/bin"
    "/run/current-system/sw/bin"
  ];

  # =========================================================================
  # Default app env vars
  #
  # Some apps (scripts, Claude Code, file managers' "Open Terminal Here",
  # language runtimes, etc.) use $BROWSER/$TERMINAL instead of xdg-open.
  #   BROWSER   zen-beta (matches the xdg.mimeApps default below)
  #   TERMINAL  kitty
  # home.sessionVariables writes to ~/.config/environment.d/ so every
  # app in the systemd user session inherits them — not just shell children.
  # =========================================================================
  home.sessionVariables = {
    BROWSER  = "zen-beta";
    TERMINAL = "kitty";
  };

  # =========================================================================
  # GSettings default apps — GNOME apps check this instead of mimeapps.list
  #
  # Nautilus "Open Terminal Here" reads terminal.exec from GSettings, not
  # mimeapps.list. The schema default is xdg-terminal-exec, which is not
  # installed, so the entry would do nothing; exec/exec-arg set kitty directly
  # (exec-arg "--" ends kitty's options before the command).
  # =========================================================================
  dconf.settings = {
    "org/gnome/desktop/default-applications/terminal" = {
      exec     = "kitty";
      exec-arg = "--";
    };
  };

  # =========================================================================
  # XDG MIME type associations
  #
  # Tells the desktop environment which app opens each file type.
  # Browser — per-user choice (shared app defaults live in graphical/graphical.nix);
  # xdg.mimeApps.defaultApplications maps a MIME type or URL scheme to a .desktop file.
  # =========================================================================
  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/http"  = "zen-beta.desktop";
    "x-scheme-handler/https" = "zen-beta.desktop";
    "text/html"              = "zen-beta.desktop";
    "application/xhtml+xml"  = "zen-beta.desktop";
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
    enable = true;
    createDirectories = true;
    setSessionVariables = true; # export XDG_*_DIR variables (explicit, so no default-change warning)

    desktop = "${config.home.homeDirectory}/Desktop";
    documents = "${config.home.homeDirectory}/Documents";
    download = "${config.home.homeDirectory}/Downloads";
    music = "${config.home.homeDirectory}/Music";
    pictures = "${config.home.homeDirectory}/Pictures";
    videos = "${config.home.homeDirectory}/Videos";
    templates = "${config.home.homeDirectory}/Templates";
    publicShare = "${config.home.homeDirectory}/Public";
  };

  # =========================================================================
  # Extra directories
  # systemd user tmpfiles rules, "type path mode user group age": d = create the
  # directory if missing (age "-" = never cleaned).
  # =========================================================================
  systemd.user.tmpfiles.rules = [
    # ~/.agents — AI config root, synced via Syncthing
    "d ${config.home.homeDirectory}/.agents                  0755 linuxury users -"
    "d ${config.home.homeDirectory}/.agents/Claude           0755 linuxury users -"
    "d ${config.home.homeDirectory}/.agents/OpenCode         0755 linuxury users -"
    "d ${config.home.homeDirectory}/.agents/Shared           0755 linuxury users -"
    "d ${config.home.homeDirectory}/.agents/Shared/mcp-servers 0755 linuxury users -"
    "d ${config.home.homeDirectory}/.agents/memory           0755 linuxury users -"
    "d ${config.home.homeDirectory}/.agents/backups          0755 linuxury users -"
    "d ${config.home.homeDirectory}/.agents/skills           0755 linuxury users -"

    # SSH directory with correct permissions (sshd refuses looser modes)
    "d ${config.home.homeDirectory}/.ssh  0700 linuxury users -"
  ];

  # =========================================================================
  # Dotfiles — links and seeds from the Dotfiles/ZSH/Assets inputs
  # home.file.<path>.source links a store path (or, with mkOutOfStoreSymlink, a
  # live path outside the store) into $HOME; .text writes content.
  # =========================================================================
  home.file = {
    # Starship prompt — deployed via home.activation.starshipSeed below
    # (copy-once, not a symlink) so Noctalia's native app-theming can patch
    # the live file. See modules/shells/noctalia/shell-noctalia.nix.

    # Fastfetch
    ".config/fastfetch".source = "${inputs.zsh}/fastfetch";

    # Topgrade — NixOS flake version
    ".config/topgrade.toml".source = "${inputs.dotfiles}/topgrade/topgrade-nixos.toml";

    # MangoHud — performance overlay for gaming
    ".config/MangoHud".source = "${inputs.dotfiles}/MangoHud";

    # Kitty terminal — deployed via home.activation.kittyConfSeed below
    # (copy-once, not a symlink) so Noctalia's native app-theming can patch
    # the live file with its own color include. See
    # modules/shells/noctalia/shell-noctalia.nix.

    # Hyprland — full config directory (entry point + all modules)
    # Live symlink (mkOutOfStoreSymlink) so edits in the clone take effect via hyprctl reload
    ".config/hypr".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/hypr";

    # Zed editor — dotfile managed by modules/development/editors/zed.nix
    # OpenCode dotfiles — managed by modules/development/ai-tools/opencode.nix

    # -----------------------------------------------------------------------
    # AI config symlinks — source files live in ~/.agents/{Claude,OpenCode,Shared}/
    # synced via Syncthing. home-manager only creates the outbound symlinks:
    # a rebuild creates them, Syncthing populates ~/.agents.
    #
    # ~/.claude is a full directory symlink to ~/.agents/Claude/ so all of
    # Claude Code's runtime data (history, sessions, projects, credentials)
    # lands in ~/.agents/Claude/ and syncs across hosts via Syncthing.
    # -----------------------------------------------------------------------
    "AGENTS.md".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/Shared/AGENTS.md";
    "CLAUDE.md".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/Claude/CLAUDE.md";
    ".claude".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/Claude";
    # opencode.json — managed by modules/development/ai-tools/opencode.nix

    # Pi (pi-acp, used via Zed's agent_servers) reads its global instructions
    # from ~/.pi/agent/AGENTS.md at startup — same shared rules file as the
    # top-level ~/AGENTS.md, so Pi follows the same conventions as Claude
    # Agent and opencode when run as a Zed external agent.
    ".pi/agent/AGENTS.md".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.agents/Shared/AGENTS.md";


    # Wayle desktop shell — static config (runtime.toml stores GUI/CLI overrides)
    ".config/wayle/config.toml".source =
      config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/wayle/config.toml";

    # Nano — for quick root edits
    ".nanorc".source = "${inputs.dotfiles}/nano/.nanorc";

    # -----------------------------------------------------------------------
    # ~/Pictures/Wallpapers is a writable folder, filled from the Assets input
    # by modules/users/wallpapers (wallpaperDir is passed per-host from
    # flake.nix: ThinkPad "4k", Ryzen5900x "3440x1440"). The slideshow reads it.
    #
    # Picture assets — symlinked from the Assets input into ~/Pictures/
    #
    # This puts all family photos and game art where the DE and image
    # viewer can discover them naturally, without a detour through the store.
    # -----------------------------------------------------------------------

    # ~/Pictures/Avatar → <assets>/Avatar (family profile photos)
    "Pictures/Avatar".source =
      "${inputs.assets}/Avatar";

    # ~/.face.icon — SDDM reads this as the primary user avatar. Points
    # directly to the Assets input (not through ~/Pictures/Avatar) so it does
    # not depend on that link existing.
    ".face.icon".source =
      "${inputs.assets}/Avatar/linuxury.jpg";

    # ~/Pictures/Minecraft → <assets>/Minecraft (skins, packs art)
    "Pictures/Minecraft".source =
      "${inputs.assets}/Minecraft";

    # ~/Pictures/SteamGridDB → <assets>/SteamGridDB (Steam cover art)
    "Pictures/SteamGridDB".source =
      "${inputs.assets}/SteamGridDB";

    # ~/Pictures/Fastfetch → <assets>/Fastfetch/linuxury (per-user image pool)
    "Pictures/Fastfetch".source =
      "${inputs.assets}/Fastfetch/linuxury";

    # SSH config — structure only, no keys
    ".ssh/config".text = ''
      # ===========================================================
      # SSH Config — linuxury
      # Keys are managed manually, not stored in the repo.
      # After first boot:
      #   ssh-keygen -t ed25519 -C "linuxury"
      #   ssh-copy-id -i ~/.ssh/id_ed25519 user@host
      # ===========================================================

      Host *
        AddKeysToAgent      yes
        IdentitiesOnly      yes
        ServerAliveInterval 60
        ServerAliveCountMax 3
        SetEnv              TERM=xterm-256color

      Host github.com
        HostName     github.com
        User         git
        IdentityFile ~/.ssh/id_ed25519

      Host media-server
        HostName     Media-Server
        User         linuxury
        IdentityFile ~/.ssh/id_ed25519

      Host minisforum
        HostName     MinisForum
        User         linuxury
        IdentityFile ~/.ssh/id_ed25519

      Host radxa
        HostName     Radxa-X4
        User         linuxury
        IdentityFile ~/.ssh/id_ed25519

      Host radxa-local
        HostName     10.0.0.5
        User         linuxury
        IdentityFile ~/.ssh/id_ed25519

      Host minisforum-local
        HostName     10.0.0.7
        User         linuxury
        IdentityFile ~/.ssh/id_ed25519

      # babylinux's machines: log in as babylinux (nru, that user's repo and shell); this key
      # is in users/babylinux/authorized-key.age. `ssh linuxury@<host>` for sudo.
      Host ryzen5800x
        HostName     Ryzen5800x
        User         babylinux
        IdentityFile ~/.ssh/id_ed25519

      Host asus-a15
        HostName     Asus-A15
        User         babylinux
        IdentityFile ~/.ssh/id_ed25519

      Host thinkpad
        HostName     ThinkPad
        User         linuxury
        IdentityFile ~/.ssh/id_ed25519

      Host ryzen5900x
        HostName     Ryzen5900x
        User         linuxury
        IdentityFile ~/.ssh/id_ed25519
    '';
  };

  # Removes ~/.local/share/applications/mimeapps.list (the legacy-spec location
  # that `xdg-mime default` writes) so it cannot diverge from the HM-managed
  # ~/.config/mimeapps.list, which takes precedence. Runs before checkLinkTargets.
  home.activation.cleanupOldMimeApps = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    rm -f "$HOME/.local/share/applications/mimeapps.list"
  '';

  # The live links (hypr, nvim, umbriel, ...) and the seeds below read from a
  # clone of Linuxury/Dotfiles at ~/dotfiles. Cloned when missing (a non-git
  # path is left alone, a failed clone only warns), never updated.
  home.activation.dotfilesClone = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    if [ ! -d "$HOME/dotfiles/.git" ]; then
      if [ -e "$HOME/dotfiles" ]; then
        echo "dotfiles: $HOME/dotfiles exists but is not a git clone, leaving it alone" >&2
      else
        echo "dotfiles: cloning Linuxury/Dotfiles to $HOME/dotfiles…"
        ${pkgs.git}/bin/git clone https://github.com/Linuxury/Dotfiles.git "$HOME/dotfiles" \
          || echo "dotfiles: WARNING, clone failed (offline?). Run: git clone https://github.com/Linuxury/Dotfiles.git ~/dotfiles" >&2
      fi
    fi
  '';

  # Direct link ~/.claude.json → ~/.agents/Claude/state.json. A home.file link
  # goes through the read-only Nix store, and Claude Code writes its temp file
  # next to the first link target, so saves would fail with EROFS.
  home.activation.claudeJsonLink = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    ln -sfn "$HOME/.agents/Claude/state.json" "$HOME/.claude.json"
  '';

  # Clears plain files/symlinks at the AI link targets (AGENTS.md, CLAUDE.md,
  # opencode.json, Pi AGENTS.md) so home.file can create them; moves a real
  # ~/.claude directory's data into ~/.agents/Claude before removing it (once,
  # skipped when ~/.claude is already a symlink); deletes flat-layout files in
  # ~/.agents that are not symlinks. Directories are never removed except ~/.claude.
  home.activation.migrateAiSymlinks = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    # Clean up top-level symlinks/files so HM can recreate them
    for f in \
      "$HOME/AGENTS.md" \
      "$HOME/CLAUDE.md" \
      "$HOME/.config/opencode/opencode.json" \
      "$HOME/.pi/agent/AGENTS.md"; do
      if [ -L "$f" ] || [ -f "$f" ]; then
        rm -f "$f"
      fi
    done

    # Migrate ~/.claude real directory → ~/.agents/Claude/ then remove it
    # so HM can create ~/.claude as a directory symlink to ~/.agents/Claude/.
    # Only runs once — skipped if ~/.claude is already a symlink.
    if [ -d "$HOME/.claude" ] && [ ! -L "$HOME/.claude" ]; then
      for item in projects history.jsonl todos sessions backups .credentials.json; do
        src="$HOME/.claude/$item"
        dst="$HOME/.agents/Claude/$item"
        if [ -e "$src" ] && [ ! -L "$src" ] && [ ! -e "$dst" ]; then
          mv "$src" "$dst"
        fi
      done
      rm -rf "$HOME/.claude"
    fi

    # Remove old flat-layout stale files if Syncthing left them behind
    for f in \
      "$HOME/.agents/AGENTS.md" \
      "$HOME/.agents/CLAUDE.md" \
      "$HOME/.agents/claude-settings.json" \
      "$HOME/.agents/claude-settings.local.json" \
      "$HOME/.agents/claude-state.json" \
      "$HOME/.agents/opencode-settings.json" \
      "$HOME/.agents/opencode-instructions.md" \
      "$HOME/.agents/mcp-servers.json" \
      "$HOME/.agents/sync-configs.sh"; do
      if [ -f "$f" ] && [ ! -L "$f" ]; then
        rm -f "$f"
      fi
    done
  '';

  # =========================================================================
  # Zsh shell
  #   autosuggestion.enable  grey inline history suggestions
  #   enableCompletion       tab completion
  #   plugins                fast-syntax-highlighting
  #   zsh-abbr               abbreviations (below)
  #   shellAliases           ll
  #   initContent            shared init from the ZSH repo (init.nix)
  # =========================================================================
  programs.zsh = {
    enable = true;
    autosuggestion.enable = true;
    enableCompletion = true;

    # fast-syntax-highlighting — richer colors and faster than zsh-syntax-highlighting
    plugins = [
      {
        name = "fast-syntax-highlighting";
        src = pkgs.zsh-fast-syntax-highlighting;
        file = "share/zsh/plugins/fast-syntax-highlighting/fast-syntax-highlighting.plugin.zsh";
      }
    ];

    # Abbreviations expand inline before running — you see the full command first.
    # Declared in programs.zsh.zsh-abbr.abbreviations.
    zsh-abbr = {
      enable = true;
      abbreviations = {
        # agenix — run from secrets/ dir without changing shell's cwd
        age-edit = "env -C ~/nixos-config/secrets nix run nixpkgs#ragenix -- -e";
        age-rekey = "env -C ~/nixos-config/secrets nix run nixpkgs#ragenix -- -r";

        # Jarvis vault
        notes = "cd ~/Jarvis && nvim .";

        # Snapper snapshot management
        snaps = "sudo snapper -c root list";
        snapsh = "sudo snapper -c home list";
        snapc = "sudo snapper -c root create --description";
      };
    };

    shellAliases = {
      # eza — modern ls with colors, icons, and git status (eza is in linuxury-packages.nix)
      ll = "eza -la --color=always --icons --group-directories-first --git";
    };

    # Shared shell initialization — env vars, PATH, fastfetch, nru function
    initContent = import "${inputs.zsh}/init.nix" { inherit lib; };
  };

  # =========================================================================
  # Starship prompt — enable installs it and hooks zsh; the config file is
  # seeded by home.activation.starshipSeed (copy-once, so it stays writable).
  # =========================================================================
  programs.starship = {
    enable = true;
  };

  # =========================================================================
  # Git
  #   signing.format  null = no commit signing configured
  #   includes        extra config files; the email lives in an agenix secret
  #   settings        user.name, init.defaultBranch, pull.rebase (false = merge),
  #                   core.editor, alias.{st,co,br,lg}
  # =========================================================================
  programs.git = {
    enable = true;
    signing.format = null; # no signing configured (explicit, so no default-change warning)
    # Email comes from an agenix secret ([user] email), so it stays out of the repo.
    includes = [ { path = "/run/agenix/git-email-linuxury"; } ];
    settings = {
      user.name = "Linuxury";
      init.defaultBranch = "main";
      pull.rebase = false;
      core.editor = "nvim";
      alias = {
        st = "status";
        co = "checkout";
        br = "branch";
        lg = "log --oneline --graph --decorate";
      };
    };
  };

  # =========================================================================
  # Zoxide — smarter cd (z <dir>); enableZshIntegration adds the zsh hook
  # =========================================================================
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  # =========================================================================
  # FZF — fuzzy finder; enableZshIntegration adds Ctrl-R/Ctrl-T/Alt-C bindings
  # =========================================================================
  programs.fzf = {
    enable = true;
    enableZshIntegration = true;
  };

  # =========================================================================
  # Direnv — auto-loads .envrc on cd (nix develop shells, project env vars)
  #   enableZshIntegration  zsh hook
  #   nix-direnv.enable     fast cached `use flake` / `use nix`
  # =========================================================================
  programs.direnv = {
    enable = true;
    enableZshIntegration = true;
    nix-direnv.enable = true;
  };

  # VSCodium: see modules/development/editors/vscodium/vscodium.nix

  # =========================================================================
  # SSH agent — keeps loaded keys for the session (pairs with AddKeysToAgent in
  # the SSH config above)
  # =========================================================================
  services.ssh-agent.enable = true;

  # =========================================================================
  # Hytale — auto-install + overrides (see modules/system/graphical/hytale.nix)
  #   enable  download and install the launcher at first login
  # =========================================================================
  programs.hytale.enable = true;

  # =========================================================================
  # "Herdr Team" launcher — opens herdr-app and starts the "desktop team"
  # (herdr-team launch, from the ZSH input's conf.d/herdr/team.zsh): an Opus
  # lead in a fresh space; it starts workers on demand. A second click while
  # the lead runs only notifies. Plain "Herdr" still opens the app without
  # touching the team. herdr-app is installed on ThinkPad and Ryzen5900x, the
  # hosts that use this home config.
  #   exec      zsh -ic: herdr-team is a zsh function loaded by the zshrc
  #   terminal  false: herdr-app is a window, the zsh only runs the script
  # =========================================================================
  xdg.desktopEntries.herdr-team = {
    name     = "Herdr Team";
    comment  = "Open herdr-app with the Claude desktop team (lead + on-demand workers)";
    exec     = "zsh -ic \"herdr-team launch\"";
    icon     = "herdr-app";
    terminal = false;
    categories = [ "Development" ];
  };

  # VSCodium Claude wrapper: see modules/development/editors/vscodium/vscodium-hm.nix

  # hypridle — symlink the profile config (hypridle-<hypridleProfile>.conf,
  # "laptop" or "desktop") to hypridle.conf inside the .config/hypr directory.
  # Since .config/hypr is a directory symlink to dotfiles/hypr/, home.file
  # cannot be used here; activation after writeBoundary does it. The symlink
  # is gitignored in the Dotfiles clone (dotfiles/hypr/hypridle.conf).
  home.activation.hypridleConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ln -sf "$HOME/dotfiles/hypr/hypridle-${hypridleProfile}.conf" \
           "$HOME/dotfiles/hypr/hypridle.conf"
  '';

  # Kitty + starship — copy-once instead of a symlink, so Noctalia's native
  # app-theming (enabled in its own settings.json, see
  # modules/shells/noctalia/shell-noctalia.nix) can patch the live file and reload
  # the app; a Nix-store symlink would silently block that write. Seeds only
  # when the file is missing (a symlink at the path is removed first); Nix never
  # touches the files afterward. Kitty copies from ~/dotfiles, starship from the
  # ZSH input.
  home.activation.kittyConfSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _cfg="$HOME/.config/kitty/kitty.conf"
    _template="$HOME/dotfiles/kitty/kitty.conf"
    mkdir -p "$HOME/.config/kitty"
    # A symlink here (from Home Manager managing the file) blocks seeding: remove
    # it so the [ ! -f ] check below seeds a real, writable
    # file instead of seeing the still-resolving symlink and skipping.
    [ -L "$_cfg" ] && rm -f "$_cfg"
    if [ ! -f "$_cfg" ] && [ -f "$_template" ]; then
      cp "$_template" "$_cfg"
    fi
  '';

  home.activation.starshipSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    _cfg="$HOME/.config/starship.toml"
    _template="${inputs.zsh}/starship/starship.toml"
    [ -L "$_cfg" ] && rm -f "$_cfg"
    if [ ! -f "$_cfg" ] && [ -f "$_template" ]; then
      cp "$_template" "$_cfg"
      # The template is a read-only store path; matugen must be able to overwrite the copy.
      chmod u+w "$_cfg"
    fi
  '';

  # Related modules:
  #   Millennium seeding: modules/gaming/gaming.nix (every user on a host with
  #     programs.steam.millennium.enable)
  #   Firefox userChrome.css: modules/system/graphical/firefox.nix
  #     (home-manager.sharedModules, every user)
  #   Neovim config: modules/development/editors/neovim/neovim-hm.nix
  #   Neovim desktop entry and text MIME defaults: modules/system/graphical/graphical.nix
  # Per-user packages: none declared in this file.
}
