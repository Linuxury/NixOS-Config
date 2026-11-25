# ===========================================================================
# modules/shells/noctalia/shell-noctalia.nix — Noctalia shell layer (v5+)
#
# Noctalia is a C++ Wayland desktop shell (bar, launcher, lock screen,
# idle, wallpaper, theming). It comes from the noctalia flake input, not
# nixpkgs. inputs.noctalia.homeModules.default replaces Home Manager's own
# programs/noctalia.nix module (disabledModules) and sets its package to
# the input's build.
#
# What this module sets up:
#   - programs.noctalia.enable          installs the package
#   - programs.noctalia.systemd.enable  runs it as a systemd user service;
#     the upstream module ties it to graphical-session.target
#   - programs.noctalia.settings        declarative config.toml
#     (wallpaper, theme templates, idle, lock screen, screenshots,
#     session menu, plugins, hooks; see each block below). The
#     wallpaper_changed hook writes ~/.local/share/current-wallpaper so the
#     matugen path unit (themes/theme-matugen.nix) runs.
#   - led-sync template                 on hosts with hardware.openrgb.enable
#   - greeters/greeter-noctalia.nix     noctalia-greeter (greetd), imported
#     here so hosts need no separate greeter import; unlike wayle it does
#     not need greeters/sddm.
# Upstream programs.noctalia options not set here:
#   package          Noctalia build (default: the flake input's)
#   extraPackages    extra commands on Noctalia's PATH (e.g. for plugins)
#   checkConfig      validate config.toml at build time (default true)
#   customPalettes   extra colour palettes
#
# Theming split: Noctalia's own templates own app theming (kitty, gtk, qt,
# starship, umbriel, pywalfox, papirus-icons, ...). Thunderbird is themed
# live through pywalfox (the add-on is force-installed by
# system/graphical/thunderbird.nix), not the `thunderbird` template: that
# one is userChrome.css, only read at startup. Which templates are on is
# app state (Settings → Theme → Templates, saved to
# ~/.local/state/noctalia/settings.toml), not Nix. matugen
# (themes/theme-matugen.nix) only covers Kvantum, which has no Noctalia
# template. Templates need writable target files, so they must not point at
# Home Manager (read-only store) paths; that is why the fastfetch template
# is off.
#
# Importing this module turns Noctalia on (shell + greeter); there is no
# enable flag. To switch shell, remove this import and import shells/wayle
# plus greeters/sddm.
# ===========================================================================

{ config, inputs, pkgs, ... }:

let
  # Pushes the palette's primary color to OpenRGB devices + the Lemokey
  # keyboard. Only wired up on hosts with hardware.openrgb.enable.
  ledSync = pkgs.writeShellApplication {
    name = "led-sync";
    runtimeInputs = [ config.services.hardware.openrgb.package ] ++ (with pkgs; [ gawk gnugrep coreutils ]);
    text = builtins.readFile ./color-sync/led-sync.sh;
  };
in
{
  imports = [ ../../greeters/greeter-noctalia.nix ];

  home-manager.sharedModules = [

    inputs.noctalia.homeModules.default

    ({ lib, ... }: {
      programs.noctalia = {
        enable = true;

        # Systemd user service; the upstream module adds the
        # graphical-session.target dependency itself.
        systemd.enable = true;

        # Declarative config.toml — only the fields that differ from
        # Noctalia's defaults.
        settings = {
          # ── Wallpaper ──────────────────────────────────────────────────────
          # Rotates wallpapers from ~/Pictures/Wallpapers (the per-host
          # wallpaper symlink): random order, every 30 min, subfolders
          # included. The wallpaper_changed hook (below) reports each change.
          wallpaper = {
            enabled   = true;
            directory = "~/Pictures/Wallpapers";
            automation = {
              enabled          = true;
              interval_seconds = 1800;
              order            = "random";
              recursive        = true;
            };
          };

          # ── Theme ──────────────────────────────────────────────────────────
          # Dark mode, accent colours taken from the active wallpaper.
          # templates.user adds user templates (input_path rendered with the
          # palette to output_path, optional post_hook) next to the built-in
          # ones toggled in the app.
          theme = {
            mode   = "dark";
            source = "wallpaper";
            templates.user = {
              # Dux Files reads DankMaterialShell's color handoff file
              # (~/.cache/dms/dms-colors.json) when its Color source is "Auto".
              # Render the same matugen-style JSON from Noctalia's palette so
              # it follows the wallpaper. Harmless if dux-files isn't installed.
              dux-files = {
                input_path  = "${./dux-files/dms-colors.json}";
                output_path = "$XDG_CACHE_HOME/dms/dms-colors.json";
              };
            } // lib.optionalAttrs config.hardware.openrgb.enable {
              # LED sync: render the bare primary hex, then push it to the
              # RGB hardware (see color-sync/led-sync.sh).
              led-sync = {
                input_path  = "${pkgs.writeText "led-color" "{{colors.primary.default.hex_stripped}}"}";
                output_path = "$XDG_CACHE_HOME/noctalia/led-color";
                post_hook   = "${ledSync}/bin/led-sync";
              };
            };
          };

          # ── Idle ───────────────────────────────────────────────────────────
          # Noctalia is the only idle manager (hypridle is not started, so
          # Noctalia owns org.freedesktop.ScreenSaver and honours app
          # inhibits). Desktop: no suspend. Each action is preceded by a 60 s
          # fade, and a timeout is when that fade starts, so: fade at 14 min,
          # lock at 15, fade at 25, screen off at 26. The fade is an overlay
          # layer, hidden by the lock screen, so only the first one is seen.
          idle.pre_action_fade_seconds = 60.0;
          idle.behavior.lock = { action = "lock"; enabled = true; timeout = 840.0; };
          idle.behavior.screen-off = { action = "screen_off"; enabled = true; timeout = 1500.0; };
          idle.behavior.lock-and-suspend.enabled  = false;

          # Dark lock screen with no entry animation: the animation reveals it
          # from the desktop, which flashed full brightness after the fade.
          lockscreen = {
            transition     = [ ];
            tint_color     = "#000000";
            tint_intensity = 0.85;
          };

          # ── Screenshots ────────────────────────────────────────────────────
          # Built-in capture. Only the directory and format are set; other
          # fields (save_to_file, copy_to_clipboard, freeze_screen, ...) keep
          # their defaults.
          shell.screenshot.directory = "~/Pictures/Screenshots";
          # Lossless WebP (quality 100): smaller than PNG, same pixels.
          # Clipboard/pipe output stays PNG regardless.
          shell.screenshot.format  = "webp";
          shell.screenshot.quality = 100;

          # ── Umbriel ────────────────────────────────────────────────────────
          # Both no-ops on any other compositor (noctalia checks isUmbriel()).
          # Close the overview when an app is launched from it, and feed
          # Umbriel's audio-reactive effects from noctalia's PipeWire spectrum.
          shell.umbriel_overview_close_on_launch_enabled = true;
          shell.umbriel_audio_provider_enabled           = true;

          # ── Session panel ──────────────────────────────────────────────────
          # Noctalia's default five actions + reboot to UEFI firmware setup.
          # Declaring the list replaces the defaults, so all of them are
          # spelled out (shortcuts match upstream's 1–5). reboot_uefi refuses
          # to run (logs an error) on non-UEFI boots.
          shell.session.actions = [
            { action = "lock";             shortcut = "1"; }
            { action = "logout";           shortcut = "2"; }
            { action = "lock_and_suspend"; shortcut = "3"; }
            { action = "reboot";           shortcut = "4"; }
            { action = "shutdown";         shortcut = "5"; variant = "destructive"; }
            { action = "reboot_uefi";      shortcut = "6"; }
          ];

          # ── App launching ──────────────────────────────────────────────────
          # Run launcher/dock apps as their own app-*.service units instead of
          # children of noctalia.service — otherwise every home-manager restart
          # of noctalia (most nru runs) kills every app launched through it.
          shell.launch_apps_as_systemd_services = true;

          # ── Plugins ────────────────────────────────────────────────────────
          # nixos-updates: bar badge + panel for pending package/Flatpak updates.
          # Its update_command is app state (Settings → Plugins → ⚙): it
          # opens a floating terminal via `umbriel msg spawn kitty --class
          # nix-updates` (rule in umbriel's window-rules.toml), because the
          # plugin has no terminal setting
          # (noctalia-dev/community-plugins#1237).
          # Declaring any source replaces Noctalia's built-in list, so official
          # and community must be listed here too. Don't add/remove sources via
          # IPC or the GUI: that saves a full source list to the app-owned
          # settings.toml, which then overrides this one.
          plugin_settings."dmopp/nixos-updates" = {
            flake_dir            = "${config.users.users.linuxury.home}/nixos-config";
            check_interval_hours = 1;
          };

          plugins = {
            enabled = [ "dmopp/nixos-updates" ];
            source  = [
              { name = "official";  kind = "git"; location = "https://github.com/noctalia-dev/official-plugins";  enabled = true; }
              { name = "community"; kind = "git"; location = "https://github.com/noctalia-dev/community-plugins"; enabled = true; }
            ];
          };

          # ── Hooks ──────────────────────────────────────────────────────────
          # wallpaper_changed: write the new wallpaper path to the handoff
          # file that the matugen path unit (themes/theme-matugen.nix) watches.
          # $NOCTALIA_WALLPAPER_PATH is set by noctalia before running this.
          hooks.wallpaper_changed =
            ''echo "$NOCTALIA_WALLPAPER_PATH" > "$HOME/.local/share/current-wallpaper"'';
        };
      };
    })

    # =========================================================================
    # Empties shell-autostart.lua — the systemd service above starts Noctalia.
    # Empties shell-active.lua   — Noctalia needs no extra Hyprland binds.
    # hyprland.lua runs both with dofile(); an empty file does nothing.
    # =========================================================================
    ({ lib, ... }: {
      home.activation.noctaliaV5HyprFiles = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        for _f in \
          "$HOME/dotfiles/hypr/shell-autostart.lua" \
          "$HOME/dotfiles/hypr/shell-active.lua"; do
          [ -d "$(dirname "$_f")" ] && : > "$_f"
        done
      '';

    })

  ];
}
