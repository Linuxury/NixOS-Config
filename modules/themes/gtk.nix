# ===========================================================================
# modules/themes/gtk.nix — Shared GTK and cursor base theme
#
# Home Manager module with the shared cursor and GTK theme. It has no
# enable flag: the compositor and desktop theme modules import it, and
# removing it from them turns it off. Provides:
#   - BreezeX-Light cursor (Wayland env + GTK + X11 fallback)
#   - adw-gtk3-dark GTK theme + Papirus-Dark icons + BreezeX cursor via GTK
#   - dconf dark mode + cursor settings for libadwaita / GSettings apps
#   - dconf button-layout for Firefox CSD window buttons
#   - gtk3 on PATH for gtk-update-icon-cache
#
# Importers add only their own config on top:
#   compositors/hyprland/hyprland-themes.nix  → + gtk-decoration-layout
#   compositors/umbriel/umbriel-themes.nix
#   desktops/cosmic/cosmic-themes.nix         → + CosmicTk files + favorites
#   desktops/gnome/gnome-themes.nix           → (base is enough for GNOME)
#   greeters/greeter-noctalia.nix
# ===========================================================================

{ pkgs, config, lib, ... }:

let
  # =========================================================================
  # BreezeX cursor theme — not in nixpkgs, fetched from GitHub releases
  #
  # BreezeX is a refined KDE Breeze cursor with larger sizes and cleaner
  # rendering. The release bundle ships three variants: Black, Dark, Light;
  # BreezeX-Light is used here.
  #
  # To upgrade: run nix-prefetch-url --unpack <new release URL> and update
  # version, url and sha256 below; every theme module uses this derivation.
  # =========================================================================
  breezex-cursors = pkgs.stdenv.mkDerivation {
    pname   = "breezex-cursor-theme";
    version = "2.0.1";

    src = pkgs.fetchzip {
      url       = "https://github.com/ful1e5/BreezeX_Cursor/releases/download/v2.0.1/BreezeX.tar.xz";
      sha256    = "10fbvbls52cgp5kshlcxbh3nqarh2mwhpj0w5kkk4hrl3sdc1bcj";
      stripRoot = false; # archive has multiple top-level dirs (BreezeX, BreezeX-Black, …)
    };

    dontBuild     = true;
    dontConfigure = true;

    installPhase = ''
      mkdir -p $out/share/icons
      cp -r . $out/share/icons/
    '';
  };

in

{
  # =========================================================================
  # Cursor — BreezeX-Light
  #
  # home.pointerCursor handles three layers at once:
  #   1. Sets XCURSOR_THEME + XCURSOR_SIZE in the systemd user environment
  #      so Wayland compositors (COSMIC, Hyprland, Niri) pick it up
  #   2. Creates ~/.icons/default/index.theme for X11 / XWayland fallback
  #   3. Writes cursor settings to GTK config (gtk.enable = true below)
  # Also available, not set here: dotIcons.enable (~/.icons link),
  # hyprcursor.enable / sway.enable (per-compositor cursor config).
  # =========================================================================
  home.pointerCursor = {
    enable     = true;
    name       = "BreezeX-Light";
    package    = breezex-cursors;
    size       = 24;
    gtk.enable = true;
    x11.enable = true;
  };

  # =========================================================================
  # GTK theme — icons, cursor, and dark mode
  #
  # GTK3, GTK4, and libadwaita apps all read from settings.ini.
  # Compositor/desktop-specific modules extend gtk3/gtk4.extraConfig
  # with additional keys (e.g. gtk-decoration-layout); HM merges them.
  #   theme / iconTheme / cursorTheme   name + package for all GTK versions
  #   gtk3/gtk4.extraConfig             extra settings.ini keys
  # Also available, not set here: font, colorScheme ("dark" / "light"),
  # gtk3/gtk4.extraCss, gtk3.bookmarks.
  # =========================================================================
  gtk = {
    enable = true;
    theme = {
      name    = "adw-gtk3-dark";
      package = pkgs.adw-gtk3;
    };
    iconTheme = {
      name    = "Papirus-Dark";
      package = pkgs.papirus-icon-theme;
    };
    cursorTheme = {
      name    = "BreezeX-Light";
      package = breezex-cursors;
      size    = 24;
    };
    gtk3.extraConfig.gtk-application-prefer-dark-theme = 1;
    gtk4 = {
      theme = config.gtk.theme; # set explicitly; HM's default for gtk4.theme depends on stateVersion
      extraConfig.gtk-application-prefer-dark-theme = 1;
    };
  };

  # gtk-update-icon-cache — not on PATH by default. Needed by any tool that
  # edits an icon theme in place (e.g. Noctalia's papirus-icons community
  # template, which recolors folder icons and refreshes the cache after).
  home.packages = [ pkgs.gtk3 ];

  # =========================================================================
  # dconf — dark mode, cursor, and window button layout
  #
  # org/gnome/desktop/interface is read by libadwaita/GTK4 apps even outside
  # GNOME. color-scheme=prefer-dark triggers dark mode in all libadwaita apps.
  #
  # org/gnome/desktop/wm/preferences: button-layout is read by Firefox (via
  # GSettings) in addition to the GTK settings.ini path — both must be set.
  # =========================================================================
  dconf.settings."org/gnome/desktop/interface" = {
    color-scheme  = "prefer-dark";
    cursor-theme  = "BreezeX-Light";
    cursor-size   = 24;
  };

  dconf.settings."org/gnome/desktop/wm/preferences" = {
    button-layout = ":minimize,maximize,close";
  };

  # =========================================================================
  # gtk.css conflict guard
  #
  # libcosmic apps (COSMIC Files, Settings, etc.) write
  # ~/.config/gtk-4.0/cosmic/{dark,light}.css and symlink gtk.css → cosmic/dark.css
  # on every launch, clobbering HM's managed file. Removing it before HM's
  # checkLinkTargets phase lets HM recreate its own symlink cleanly.
  # =========================================================================
  home.activation.clearGtkCss = lib.hm.dag.entryBefore ["checkLinkTargets"] ''
    rm -f "${config.home.homeDirectory}/.config/gtk-4.0/gtk.css"
  '';
}
