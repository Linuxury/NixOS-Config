# ===========================================================================
# modules/system/graphical/keybinds.nix — Shared terminal keybinds
#
# Home Manager module with the shared terminal and close-window keybinds,
# written for every desktop at once whichever DE/WM is active. graphical.nix
# adds it to home-manager.sharedModules, so every user on every graphical
# host gets it; remove that entry to turn it off. Keybinds that must match
# across desktops are defined here:
#
#   SUPER+Return       → kitty (tiled)
#   SUPER+SHIFT+Return → kitty --class floating-term (floating quick terminal)
#   SUPER+Q            → close window (KDE and GNOME, set below)
#
# DE coverage:
#   Hyprland — dotfiles/hypr/modules/keybinds.lua (managed in dotfile; Hyprland's
#              Lua config is a dotfile, not a NixOS/HM module)
#   COSMIC   — RON files in ~/.config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/
#   KDE      — kglobalshortcutsrc (appended via home.activation; must be
#              writable because KDE modifies it at runtime — no symlinks)
#   GNOME    — dconf org/gnome/settings-daemon/plugins/media-keys custom keybindings
#   Niri     — programs.niri.settings.binds in compositors/niri.nix sharedModules
#              (programs.niri HM option only exists when NixOS niri module is enabled,
#              so it cannot be set here safely)
#
# Files written for inactive DEs are never read, so a host can add or
# switch DEs without extra keybind config.
# ===========================================================================

{ lib, pkgs, ... }:

{
  # =========================================================================
  # COSMIC shortcuts
  #
  # COSMIC merges custom/ on top of its built-in defaults, so only overrides
  # are listed. system_actions maps the System(Terminal) action (SUPER+T by
  # default) to kitty too. force = true replaces files COSMIC wrote itself.
  # =========================================================================
  home.file.".config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/custom" = {
    force = true;
    text = ''
      {
          (modifiers: [Super], key: "Return"): Spawn("kitty"),
          (modifiers: [Super, Shift], key: "Return"): Spawn("kitty --class floating-term"),
      }
    '';
  };

  home.file.".config/cosmic/com.system76.CosmicSettings.Shortcuts/v1/system_actions" = {
    force = true;
    text = ''
      {
          Terminal: "kitty",
      }
    '';
  };

  # =========================================================================
  # KDE shortcuts
  #
  # kitty-floating needs a .desktop entry so KDE can register it as a
  # shortcut target. NoDisplay=true keeps it out of the app launcher.
  #
  # KDE edits kglobalshortcutsrc at runtime (System Settings), so a
  # home.file / xdg.configFile read-only symlink would block its writes.
  # Instead two activation scripts edit it in place:
  #   kdeCloseWindowShortcut   kwriteconfig6 sets kwin "Window Close" to
  #                            Meta+Q and Alt+F4
  #   kdeKittyShortcuts        appends the kitty sections only if absent,
  #                            leaving all other shortcuts untouched
  # =========================================================================
  home.file.".local/share/applications/kitty-floating.desktop".text = ''
    [Desktop Entry]
    Type=Application
    Name=kitty (floating)
    Comment=Floating terminal
    Exec=kitty --class floating-term
    Icon=kitty
    Categories=System;TerminalEmulator;
    NoDisplay=true
  '';

  home.activation.kdeCloseWindowShortcut = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    ${pkgs.kdePackages.kconfig}/bin/kwriteconfig6 \
      --file "$HOME/.config/kglobalshortcutsrc" \
      --group kwin \
      --key "Window Close" $'Meta+Q\tAlt+F4,Alt+F4,Close Window'
  '';

  home.activation.kdeKittyShortcuts = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    KGLOBAL="$HOME/.config/kglobalshortcutsrc"
    if ! grep -q '^\[kitty\.desktop\]' "$KGLOBAL" 2>/dev/null; then
      printf '\n[kitty.desktop]\n_k_friendly_name=kitty\n_launch=Meta+Return,none,kitty\n' >> "$KGLOBAL"
    fi
    if ! grep -q '^\[kitty-floating\.desktop\]' "$KGLOBAL" 2>/dev/null; then
      printf '\n[kitty-floating.desktop]\n_k_friendly_name=kitty (floating)\n_launch=Meta+Shift+Return,none,kitty (floating)\n' >> "$KGLOBAL"
    fi
  '';

  # =========================================================================
  # GNOME shortcuts
  #
  # GNOME keeps keybindings in dconf (dconf.settings).
  #   org/gnome/desktop/wm/keybindings.close   window close key
  #   custom-keybindings/customN               app-launch shortcuts, each
  #                                            with name, command, binding
  # The custom-keybindings list on the parent key must name every customN
  # path, or GNOME ignores it.
  # =========================================================================
  dconf.settings = {
    "org/gnome/desktop/wm/keybindings" = {
      close = [ "<Super>q" ];
    };
    "org/gnome/settings-daemon/plugins/media-keys" = {
      custom-keybindings = [
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0/"
        "/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1/"
      ];
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom0" = {
      name    = "kitty";
      command = "kitty";
      binding = "<Super>Return";
    };
    "org/gnome/settings-daemon/plugins/media-keys/custom-keybindings/custom1" = {
      name    = "kitty (floating)";
      command = "kitty --class floating-term";
      binding = "<Super><Shift>Return";
    };
  };

}
