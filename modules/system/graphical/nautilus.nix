# ===========================================================================
# modules/system/graphical/nautilus.nix — Bookmarks and scripts for Nautilus
#
# Home Manager module for linuxury. It hardcodes /home/linuxury paths, so
# turn it on by importing it from modules/users/linuxury/linuxury-home.nix,
# never from home-manager.sharedModules; remove the import to turn it off.
#
#   home.file.".config/gtk-3.0/bookmarks"
#            sidebar bookmarks: home folders plus the /mnt server mounts.
#            Thunar reads the same file (thunar.nix).
#   home.file.".local/share/nautilus/scripts/<name>"
#            executable scripts shown under right-click -> Scripts:
#            Copy Path, Copy Name, Open as Root
#
# smb:// locations are browsed through gvfs, which graphical.nix enables
# with Samba support.
# ===========================================================================

{ ... }:

{
  # ---------------------------------------------------------------------------
  # Sidebar bookmarks
  # ---------------------------------------------------------------------------
  home.file.".config/gtk-3.0/bookmarks".text = ''
    file:///home/linuxury/Documents Documents
    file:///home/linuxury/Downloads Downloads
    file:///home/linuxury/Music Music
    file:///home/linuxury/Pictures Pictures
    file:///home/linuxury/Videos Videos
    file:///mnt/Media-Server Media-Server
    file:///mnt/MinisForum MinisForum
  '';

  # ---------------------------------------------------------------------------
  # Scripts — appear in the right-click -> Scripts menu. The copy scripts
  # use wl-copy (wl-clipboard), so they need a Wayland session.
  # ---------------------------------------------------------------------------
  home.file.".local/share/nautilus/scripts/Copy Path" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Copy the full path of the selected file to the Wayland clipboard.
      echo -n "$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS" | head -1 | tr -d '\n' | wl-copy
    '';
  };

  home.file.".local/share/nautilus/scripts/Copy Name" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Copy just the filename (no directory) to the Wayland clipboard.
      echo -n "$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS" | head -1 | xargs basename | tr -d '\n' | wl-copy
    '';
  };

  home.file.".local/share/nautilus/scripts/Open as Root" = {
    executable = true;
    text = ''
      #!/usr/bin/env bash
      # Open the selected folder in Nautilus with root privileges via pkexec.
      # Polkit handles the password prompt (polkit_gnome is running on Hyprland).
      DIR=$(echo "$NAUTILUS_SCRIPT_SELECTED_FILE_PATHS" | head -1 | tr -d '\n')
      pkexec nautilus "$DIR"
    '';
  };
}
