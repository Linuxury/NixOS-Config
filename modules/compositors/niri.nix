# ===========================================================================
# modules/compositors/niri.nix — Niri Wayland Compositor
#
# Niri is a scrollable-tiling Wayland compositor. Unlike Hyprland's
# dynamic tiling, Niri arranges windows in an infinite horizontal scroll —
# new windows always open to the right, never overlapping.
#
# It's an opinionated compositor with a simpler config format than
# Hyprland's.
#
# Not imported by any host. To enable it, add this file to a host's imports;
# remove the import to turn it off.
# ===========================================================================

{ config, pkgs, ... }:

{
  # =========================================================================
  # Niri — the compositor itself
  #
  # NixOS has a dedicated Niri module in nixpkgs.
  # xwayland support in Niri is handled differently than Hyprland —
  # it requires xwayland-satellite as a separate companion process
  # rather than being built in.
  #
  #   enable       install niri and register its session
  #   Not set here: package, useNautilus (Nautilus as the GNOME portal's file
  #   chooser, default true).
  # =========================================================================
  programs.niri = {
    enable = true;
  };

  # Enable Home Manager's niri module for all users so programs.niri.settings
  # generates config.kdl, and declare terminal keybinds inline.
  # (programs.niri HM option is only available when NixOS programs.niri is enabled,
  # so these binds cannot live in the shared graphical/keybinds module.)
  home-manager.sharedModules = [{
    programs.niri.enable = true;
    programs.niri.settings.binds = {
      "Super+Return".action.spawn       = [ "kitty" ];
      "Super+Shift+Return".action.spawn = [ "kitty" "--class" "floating-term" ];
    };
  }];

  # =========================================================================
  # XWayland Satellite — X11 app support for Niri
  #
  # Niri doesn't have built-in XWayland support like Hyprland does.
  # xwayland-satellite runs as a companion process that bridges X11 apps
  # into Niri's Wayland environment. You start it in your Niri config.
  # =========================================================================
  programs.xwayland.enable = true;

  # =========================================================================
  # XDG Portal for Niri
  #
  # Niri has no portal implementation of its own.
  # xdg-desktop-portal-gnome handles screen sharing, file pickers and other
  # integrations; gtk covers the rest.
  #
  #   enable                 run xdg-desktop-portal
  #   extraPortals           backends to install
  #   config.common.default  backend used for every interface
  #   Not set here: xdgOpenUsePortal, configPackages.
  # =========================================================================
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-gnome
      pkgs.xdg-desktop-portal-gtk
    ];
    config.common.default = "gnome";
  };

  # =========================================================================
  # Polkit — same reason as Hyprland, WMs don't include this by default
  # =========================================================================
  security.polkit.enable = true;

  # =========================================================================
  # Niri companion tools
  #
  # Very similar stack to Hyprland since both are bare compositors.
  # Some tools are shared concepts, some are Niri-specific.
  # Actual configuration lives in your dotfiles.
  # =========================================================================
  environment.systemPackages = with pkgs; [
    # Status bar
    waybar             # Same bar works for both Hyprland and Niri

    # Launcher
    fuzzel             # Lightweight launcher, popular in Niri setups
    rofi-wayland       # Alternative if you prefer it from Hyprland

    # Notifications
    swaynotificationcenter  # Sway Notification Center — notification daemon + panel
    libnotify               # notify-send — sends notifications from scripts/apps

    # Wallpaper
    awww               # Wallpaper daemon (the swww successor)

    # Screenshots
    grim
    slurp
    hyprpicker
    satty

    # Clipboard
    wl-clipboard
    cliphist

    # Screen locking
    swaylock
    swayidle

    # XWayland bridge for Niri
    xwayland-satellite # Bridges X11 apps into Niri without full XWayland

    # Theming
    nwg-look
    qt6Packages.qt6ct

  ];

  # =========================================================================
  # Keyring — same reasoning as Hyprland
  # =========================================================================
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.login.enableGnomeKeyring = true;
}
