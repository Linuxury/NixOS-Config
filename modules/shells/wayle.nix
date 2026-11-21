# ===========================================================================
# modules/shells/wayle.nix — Wayle shell layer
#
# GTK4/Rust desktop shell: top bar, notification center, on-screen display
# and wallpaper management, for any wlr-layer-shell compositor.
#
# Importing this module turns Wayle on; there is no enable flag. To switch
# shell, remove this import and import shells/noctalia instead. Wayle has no
# login screen, so the host also needs a greeter (e.g. greeters/sddm).
#
#   environment.systemPackages      wayle, plus awww for wallpaper cycling
#   systemd.user.services.wayle     starts `wayle shell` with the graphical
#                                   session, restarts on failure
#   home.activation.shellActiveConf     Wayle keybinds for Hyprland
#   home.activation.shellAutostartConf  empties shell-autostart.lua
#
# Home Manager also has a services.wayle module that could replace the
# hand-written unit:
#   enable                    run wayle as a user service
#   package                   wayle build (default pkgs.wayle)
#   settings                  config written as TOML (bar, styling, palette…)
#   autoInstallDependencies   install soft dependencies the config needs
#                             (default true)
# ===========================================================================

{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    wayle
    awww   # wallpaper backend Wayle uses for wallpaper cycling
  ];

  # =========================================================================
  # Home Manager — Wayle autostart + Hyprland shell-active.conf
  # =========================================================================
  home-manager.sharedModules = [

    # Wayle shell as a systemd user service, started and stopped with
    # graphical-session.target.
    ({ pkgs, lib, ... }: {
      systemd.user.services.wayle = {
        Unit = {
          Description = "Wayle desktop shell";
          After       = [ "graphical-session.target" ];
          PartOf      = [ "graphical-session.target" ];
        };
        Service = {
          Type      = "simple";
          ExecStart = "${pkgs.wayle}/bin/wayle shell";
          Restart   = "on-failure";
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };
    })

    # Writes Wayle keybinds (SUPER+W next wallpaper, SUPER+N do-not-disturb)
    # into ~/dotfiles/hypr/shell-active.lua. They live here because the wayle
    # CLI exists only when this module is imported. Skipped if the hypr
    # directory is missing.
    ({ lib, ... }: {
      home.activation.shellActiveConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _target="$HOME/dotfiles/hypr/shell-active.lua"
        [ -d "$(dirname "$_target")" ] || exit 0
        printf '%s\n' \
          'local mod = "SUPER"' \
          'hl.bind(mod .. " + W", hl.dsp.exec_cmd("wayle wallpaper next"))' \
          'hl.bind(mod .. " + N", hl.dsp.exec_cmd("wayle notify dnd"))' \
          > "$_target"
      '';
    })

    # Empties shell-autostart.lua: the systemd user service starts Wayle, so
    # Hyprland needs no exec-once line for it.
    ({ lib, ... }: {
      home.activation.shellAutostartConf = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _target="$HOME/dotfiles/hypr/shell-autostart.lua"
        [ -d "$(dirname "$_target")" ] || exit 0
        : > "$_target"
      '';
    })

  ];
}
