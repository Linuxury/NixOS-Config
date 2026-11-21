# ===========================================================================
# modules/components/notifications/swaync/swaync.nix — SwayNC notification daemon
#
# Notification daemon with a slide-in control center, for any
# wlr-layer-shell compositor (Hyprland, Niri, Sway). Turn it on by importing
# this file from a host; remove the import to turn it off.
#
# When imported, this module:
#   1. Adds swaynotificationcenter to environment.systemPackages.
#   2. Adds swaync-hm.nix to every user via home-manager.sharedModules,
#      which generates ~/.config/swaync/config.json from host options.
#   3. If Hyprland is present: writes ~/.config/hypr/components/notifications.lua
#      (layer rules for the slide-in animation). Skipped on all other
#      compositors — this module itself is compositor-agnostic.
#
# Options, set in the host config (hosts/<name>/<name>.nix):
#   myModules.swaync.hasBacklight      = true;
#   myModules.swaync.backlightDevice   = "amdgpu_bl1";  # ls /sys/class/backlight/
#   myModules.swaync.hasKbBacklight    = true;
#   myModules.swaync.kbBacklightDevice = "tpacpi::kbd_backlight";
#   myModules.swaync.hasWifi           = true;   # default true
#   myModules.swaync.hasBluetooth      = true;   # default true
# hasBacklight / hasKbBacklight default to false and add the matching
# slider; the device names default to "".
#
# Home Manager's own services.swaync (enable, package, settings, style) is
# not used; swaync-hm.nix writes config.json directly.
# ===========================================================================

{ pkgs, lib, ... }:

{
  options.myModules.swaync = {
    hasBacklight = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Whether this host has a display backlight (laptop screen).";
    };

    backlightDevice = lib.mkOption {
      type    = lib.types.str;
      default = "";
      description = "Backlight device name (ls /sys/class/backlight/).";
    };

    hasKbBacklight = lib.mkOption {
      type    = lib.types.bool;
      default = false;
      description = "Whether this host has keyboard backlight LEDs.";
    };

    kbBacklightDevice = lib.mkOption {
      type    = lib.types.str;
      default = "";
      description = "Keyboard backlight LED device name (ls /sys/class/leds/).";
    };

    hasWifi = lib.mkOption {
      type    = lib.types.bool;
      default = true;
      description = "Whether to show WiFi toggle in SwayNC control panel.";
    };

    hasBluetooth = lib.mkOption {
      type    = lib.types.bool;
      default = true;
      description = "Whether to show Bluetooth toggle in SwayNC control panel.";
    };
  };

  config = {
    environment.systemPackages = [ pkgs.swaynotificationcenter ];

    home-manager.sharedModules = [
      # Generate ~/.config/swaync/config.json from host options.
      ./swaync-hm.nix

      # On Hyprland hosts (~/.config/hypr exists): writes layer rules that
      # slide the swaync windows in from the right. Other hosts skip it.
      ({ lib, ... }: {
        home.activation.swayncHyprRules = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          # Only run on Hyprland hosts — skip silently on all others
          [ -d "$HOME/.config/hypr" ] || exit 0
          _target="$HOME/.config/hypr/components/notifications.lua"
          [ -d "$(dirname "$_target")" ] || mkdir -p "$(dirname "$_target")"
          printf '%s\n' \
            '-- swaync layer rules — slide in from the right' \
            'hl.layer_rule({ match = { namespace = "swaync/control-center"      }, animation = "slide right" })' \
            'hl.layer_rule({ match = { namespace = "swaync/notification-window" }, animation = "slide right" })' \
            > "$_target"
        '';
      })
    ];
  };
}
