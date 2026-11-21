# ===========================================================================
# modules/components/notifications/swaync/swaync-hm.nix — SwayNC (Home Manager)
#
# Home Manager module, added to every user by swaync.nix. Generates
# ~/.config/swaync/config.json from the host's hardware options
# (options.myModules.swaync.*, declared in swaync.nix) and links the CSS.
#
# Host option reference (set in hosts/<name>/<name>.nix):
#   myModules.swaync.hasBacklight      = true;
#   myModules.swaync.backlightDevice   = "amdgpu_bl1";  # ls /sys/class/backlight/
#   myModules.swaync.hasKbBacklight    = true;
#   myModules.swaync.kbBacklightDevice = "tpacpi::kbd_backlight";  # ls /sys/class/leds/
#   myModules.swaync.hasWifi           = true;   # default true
#   myModules.swaync.hasBluetooth      = true;   # default true
#
# Widget layout (panel top → bottom):
#   title
#   Network:        label#network → buttons-grid (WiFi | BT — 2 per row, 50% each)
#   Display*:       label#display → backlight#display → backlight#kbd
#   Do Not Disturb: label#dnd → buttons-grid#dnd-timers (30m | 1h | 2h | Off)
#   Volume:         label#volume → volume (+ expandable per-app)
#   Media Player:   mpris (autohide=true — hidden when nothing plays; no label needed)
#   Notifications:  notifications (no label — cards are self-evident)
#   *laptop only
# ===========================================================================

{ config, lib, osConfig, ... }:

let
  cfg = osConfig.myModules.swaync;

  # Whether there are any buttons to show in the grid
  hasButtons = cfg.hasWifi || cfg.hasBluetooth;

  # Whether this host has any laptop display hardware
  hasDisplay = cfg.hasBacklight || cfg.hasKbBacklight;

  # Dynamic widget list — host-capability-aware
  widgets =
    [ "title" ]
    ++ lib.optionals hasButtons  [ "label#network" "buttons-grid" ]
    ++ lib.optionals hasDisplay  [ "label#display" ]
    ++ lib.optionals cfg.hasBacklight   [ "backlight#display" ]
    ++ lib.optionals cfg.hasKbBacklight [ "backlight#kbd" ]
    ++ [ "label#dnd" "buttons-grid#dnd-timers" ]
    ++ [ "label#volume" "volume" ]
    ++ [ "mpris" ]
    ++ [ "notifications" ];

  # Toggle button actions — only include the hardware that exists
  buttonActions =
    lib.optionals cfg.hasWifi [{
      label    = "󰖩  WiFi";
      command  = "sh -c 'if nmcli radio wifi 2>/dev/null | grep -q enabled; then nmcli radio wifi off; else nmcli radio wifi on; fi'";
    }]
    ++ lib.optionals cfg.hasBluetooth [{
      label    = "󰂯  BT";
      command  = "sh -c 'if bluetoothctl show 2>/dev/null | grep -q \"Powered: yes\"; then bluetoothctl power off; else bluetoothctl power on; fi'";
    }];

  # Per-widget configuration
  widgetConfig =
    {
      title = {
        text             = "Control Panel";
        clear-all-button = true;
        button-text      = "Clear All";
      };

      # Section labels — styled as subtle category headers via .widget-label CSS
      # Format: ── TEXT ─(right)─  all labels end at ~50 chars
      "label#network"       = { text = "── Network ────────────────────────────────";  max-lines = 1; };
      "label#display"       = { text = "── Display ────────────────────────────────";  max-lines = 1; };
      "label#dnd"           = { text = "── Do Not Disturb ─────────────────────────";  max-lines = 1; };
      "label#volume"        = { text = "── Volume ─────────────────────────────────";  max-lines = 1; };

      # DND timer options — the buttons are the only controls (no toggle widget).
      # Each time button enables DND immediately then sets a systemd one-shot timer
      # to disable it after the chosen duration. "Off" disables DND immediately.
      "buttons-grid#dnd-timers" = {
        buttons-per-row = 4;
        actions = [
          {
            label   = "30m";
            command = "sh -c 'swaync-client --dnd-on; systemd-run --user --on-active=1800 swaync-client --dnd-off'";
          }
          {
            label   = "1h";
            command = "sh -c 'swaync-client --dnd-on; systemd-run --user --on-active=3600 swaync-client --dnd-off'";
          }
          {
            label   = "2h";
            command = "sh -c 'swaync-client --dnd-on; systemd-run --user --on-active=7200 swaync-client --dnd-off'";
          }
          {
            label   = "Off";
            command = "swaync-client --dnd-off";
          }
        ];
      };

      volume = {
        label                 = "󰕾";
        show-per-app          = true;
        expand-per-app        = false;
        empty-list-label      = "No active apps";
        expand-button-label   = "󰐕  Apps";
        collapse-button-label = "󰐊  Done";
      };

      mpris = {
        image-size   = 80;
        image-radius = 8;
        autohide     = true;  # hidden when no player is running, so it has no section label
      };
    }
    // lib.optionalAttrs hasButtons {
      "buttons-grid" = {
        buttons-per-row = 2;    # two columns → each button ~50% panel width
        actions         = buttonActions;
      };
    }
    // lib.optionalAttrs cfg.hasBacklight {
      "backlight#display" = {
        label     = "󰃠";
        device    = cfg.backlightDevice;
        subsystem = "backlight";
        min       = 1;  # never go fully dark
      };
    }
    // lib.optionalAttrs cfg.hasKbBacklight {
      "backlight#kbd" = {
        label     = "󰌌";
        device    = cfg.kbBacklightDevice;
        subsystem = "leds";
        min       = 0;
      };
    };

  # Top-level swaync settings. Every key is described in the JSON schema the
  # package installs at /etc/xdg/swaync/configSchema.json (linked by "$schema").
  #   positionX/Y, layer           where popups appear and on which layer
  #   control-center-*             panel layer, size and margins
  #   notification-*               popup size, icons, images, 2FA, replies
  #   timeout, timeout-low/-critical  seconds before popups close (0 = never)
  #   hide-on-clear/-action        close the panel after clearing or acting
  #   widgets / widget-config      panel layout, built above
  swayncConfig = {
    "$schema"                    = "/etc/xdg/swaync/configSchema.json";
    positionX                    = "right";
    positionY                    = "top";
    layer                        = "overlay";
    "control-center-layer"       = "top";
    "layer-shell"                = true;
    cssPriority                  = "user";
    "control-center-margin-top"    = 18;
    "control-center-margin-bottom" = 18;
    "control-center-margin-right"  = 18;
    "control-center-margin-left"   = 0;
    "notification-2fa-action"    = true;
    "notification-inline-replies"= false;
    "notification-icon-size"     = 40;    # deprecated but kept for compat
    "notification-body-image-height" = 80;
    "notification-body-image-width"  = 160;
    timeout          = 5;
    "timeout-low"    = 2;
    "timeout-critical" = 0;
    "fit-to-screen"  = true;
    "control-center-width"  = 420;
    "notification-window-width" = 480;
    "keyboard-shortcuts" = true;
    "image-visibility"   = "when-available";
    "transition-time"    = 100;
    "hide-on-clear"  = true;
    "hide-on-action" = true;
    "notification-grouping"  = false;
    "script-fail-notify"     = true;
    inherit widgets;
    "widget-config" = widgetConfig;
  };

in {
  home.file.".config/swaync/config.json" = {
    text = builtins.toJSON swayncConfig;
  };

  # CSS files link to ~/dotfiles/swaync so edits apply without a rebuild.
  # config.json is generated here, so the directory cannot be one symlink;
  # each CSS file is linked on its own.
  home.file.".config/swaync/style.css".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/swaync/style.css";
  home.file.".config/swaync/colors.css".source =
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dotfiles/swaync/colors.css";
}
