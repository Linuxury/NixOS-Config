# ===========================================================================
# modules/system/graphical/luciole.nix — Luciole file manager
#
# noctalia-dev's native Wayland file manager (sibling of Noctalia/Umbriel),
# from the luciole flake input. Installs the app system-wide only; it does
# NOT take over folders or Open/Save dialogs. To make it the picker, add its
# package to xdg.portal.extraPortals and set the host's
# xdg.portal.config.<session>."org.freedesktop.impl.portal.FileChooser"
# to [ "luciole" ].
#
# Trash and smb:// / sftp:// need GVfs, which graphical.nix already enables.
# Config: ~/.config/luciole/config.toml (live-reloaded).
#
# Turn it on by importing this module from a host; remove the import to
# turn it off.
# ===========================================================================

{ inputs, ... }:

{
  imports = [ inputs.luciole.nixosModules.default ];

  programs.luciole.enable = true;
}
