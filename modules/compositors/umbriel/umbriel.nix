# ===========================================================================
# modules/compositors/umbriel/umbriel.nix — Umbriel Wayland Compositor
#
# Umbriel is noctalia-dev's independent wlroots compositor (scrolling,
# dwindle, and master layouts) — a sibling project to Noctalia Shell and
# noctalia-greeter, designed to pair with Noctalia as an alternative to
# Hyprland.
#
# Package, session-picker registration (services.displayManager.sessionPackages),
# systemd service, and xdg.portal wiring are ALL handled automatically by
# inputs.umbriel.nixosModules.default once programs.umbriel.enable = true —
# no UWSM wrapper or greeter-compositor override needed here (unlike
# Hyprland's KWin-for-SDDM workaround): noctalia-greeter runs its own
# bundled wlroots compositor regardless of which session compositor is
# picked.
#
# Shell layer: pair with modules/shells/noctalia/shell-noctalia.nix, same as
# Hyprland. Import this module in a host config to make it selectable; remove
# the import to turn it off.
# ===========================================================================

{ inputs, pkgs, ... }:

{
  imports = [ inputs.umbriel.nixosModules.default ];

  programs.umbriel.enable = true;
  # package self-defaults via the flake's withDefaultPackage wrapper —
  # no override needed.

  # Expose the bundled effect presets at a stable path
  # (/run/current-system/sw/share/umbriel/effects) for
  # dotfiles/umbriel/modules/effects.toml to include — the package's own
  # store path changes on every umbriel bump.
  environment.pathsToLink = [ "/share/umbriel" ];

  # =========================================================================
  # Polkit — Authentication agent
  # =========================================================================
  security.polkit.enable = true;

  # =========================================================================
  # Keyring — Secret storage for apps (GNOME Keyring works fine outside GNOME)
  # =========================================================================
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;

  # Thunderbird: opaque window. Under Umbriel, Gecko's ARGB window can leave
  # the header transparent after a live pywalfox recolor, so the wallpaper
  # shows through until a forced repaint. Only matters on hosts that also
  # import system/graphical/thunderbird.
  programs.thunderbird.preferences."widget.transparent-windows" = false;

  # =========================================================================
  # Shared Home Manager modules — injected into every user on this host.
  # These are compositor-level concerns, not shell-specific.
  # =========================================================================
  home-manager.sharedModules = [
    ./umbriel-themes.nix    # BreezeX-Light cursor + Tela-dark icons + GTK + Kvantum/qt6ct
    ../../themes/theme-matugen.nix  # matugen color sync (Kvantum only — everything else is Noctalia-native)

    ({ config, lib, ... }: {
      # =====================================================================
      # Umbriel's own config — real dotfiles, not a generated Nix attrset.
      #
      # ~/.config/umbriel is a live symlink into dotfiles/umbriel/ (same
      # mkOutOfStoreSymlink pattern as dotfiles/hypr/) — edits in the repo
      # take effect immediately, matched by Umbriel's own live-reload.
      # config.toml there splits into general.toml/keybinds.toml/
      # outputs.toml via Umbriel's own [include] mechanism (docs/user/
      # configuration.md), plus noctalia-fixed.toml (gitignored, generated
      # by ./noctalia-bridge on every wallpaper change).
      #
      # Nothing validates the config at build time — run it by hand after
      # editing: `umbriel validate -c ~/.config/umbriel/config.toml`.
      #
      # Pre-clear: if ~/.config/umbriel exists as a real directory, HM's
      # checkLinkTargets refuses to replace it with a symlink ("would be
      # clobbered"). Remove it when it is not already the symlink; a no-op
      # once the symlink is in place.
      # =====================================================================
      home.activation.clearUmbrielConfigDir = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        _p="$HOME/.config/umbriel"
        if [ -e "$_p" ] && [ ! -L "$_p" ]; then
          rm -rf "$_p"
        fi
      '';

      home.file.".config/umbriel".source =
        config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/umbriel";
    })
  ];

  # =========================================================================
  # Umbriel companion tools — compositor-agnostic subset of the Hyprland
  # toolset.
  # =========================================================================
  # sway-audio-idle-inhibit can abort (SIGABRT in Idle::block) when audio
  # starts. Running it as a user unit with Restart=always keeps the inhibitor
  # alive so idle never locks mid-video.
  systemd.user.services.sway-audio-idle-inhibit = {
    description = "Inhibit idle while audio plays";
    wantedBy = [ "graphical-session.target" ];
    partOf = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.sway-audio-idle-inhibit}/bin/sway-audio-idle-inhibit";
      Restart = "always";
      RestartSec = 1;
    };
  };

  environment.systemPackages = with pkgs; [
    # Cursor theme — installed system-wide so the greeter picks it up
    breezex-cursors

    # Real Wayland idle inhibitor while audio plays (browsers do not inhibit
    # under Umbriel)
    sway-audio-idle-inhibit

    # Screen recording
    wl-screenrec

    # Night light
    wlsunset

    # Clipboard
    wl-clipboard
    cliphist

    # Audio
    pavucontrol

    # Notifications
    libnotify

    # Theming
    nwg-look
    qt6Packages.qt6ct
    kdePackages.qtstyleplugin-kvantum

    # Polkit authentication agent
    polkit_gnome

    # Brightness control
    brightnessctl

    # File manager — off: dux-files is the default on this host.
    # Nautilus + Thunar kept below, commented, to re-enable if needed.
    # File manager — Nautilus
    #nautilus
    #sushi
    #tinysparql
    #localsearch

    # File manager — Thunar. Nautilus draws its own hardcoded folder graphic
    # instead of reading the icon theme, so Papirus's dynamic recolor never
    # reaches it; Thunar reads icon themes normally and does. (Nemo would
    # also work but pulls in ~170MB of MATE stack as a dependency.)
    #
    # xfconf is xfconfd, the settings daemon Thunar needs to persist any
    # preference change at all — not installed by pkgs.thunar itself, so
    # without it every settings-dialog change is silently lost on restart.
    #
    # thunar-archive-plugin — right-click create/extract archives (Nautilus
    # gets this for free via gnome-autoar, Thunar needs it explicit).
    # thunar-volman — auto-mount removable media (USB drives, etc.) on
    # insert, same role gvfs-udisks2 plays for Nautilus/GNOME automount.
    #thunar
    #xfconf
    #thunar-archive-plugin
    #thunar-volman

    # Media keys
    playerctl

    # IPC / scripting
    socat
  ];

  # =========================================================================
  # Tracker — file indexer for Nautilus search
  # =========================================================================
  # services.gnome.tinysparql.enable = true;   # disabled with Nautilus
  # services.gnome.localsearch.enable = true;
}
