# ===========================================================================
# modules/system/graphical/thunar.nix — Thunar as default file manager
#
# Home Manager module that makes Thunar the default file manager for
# linuxury. Turn it on by importing it from
# modules/users/linuxury/linuxury-home.nix; remove the import to go back to
# the shared default (Nautilus, set in graphical.nix). Do not add it to
# home-manager.sharedModules: other hosts do not install Thunar.
#
#   xdg.mimeApps.defaultApplications."inode/directory"
#                    thunar.desktop, with mkForce to win over the shared
#                    Nautilus default
#   home.file.".config/Thunar/uca.xml"
#                    right-click Custom Actions: Open Terminal Here (kitty)
#                    plus the three Nautilus scripts from nautilus.nix
#                    (Copy Name, Copy Path, Open as Root)
#
# Bookmarks come from ~/.config/gtk-3.0/bookmarks, which nautilus.nix writes;
# Thunar reads the same file.
#
# Each action passes %f as a positional argument ("$1") so paths with spaces
# stay intact. uca.xml is managed by Nix: actions added in Thunar's
# "Configure custom actions" dialog are lost on the next rebuild, so add them
# here instead.
# ===========================================================================

{ lib, ... }:

{
  xdg.mimeApps.defaultApplications."inode/directory" = lib.mkForce "thunar.desktop";

  home.file.".config/Thunar/uca.xml" = {
    force = true; # replace the default uca.xml Thunar writes on first launch
    text = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <actions>
      <action>
        <icon>utilities-terminal</icon>
        <name>Open Terminal Here</name>
        <unique-id>1-thunar-uca</unique-id>
        <command>kitty -d "%f"</command>
        <description>Open a kitty terminal in this location</description>
        <patterns>*</patterns>
        <directories/>
      </action>
      <action>
        <icon>edit-copy</icon>
        <name>Copy Name</name>
        <unique-id>2-thunar-uca</unique-id>
        <command>bash -c &apos;basename "$1" | tr -d "\n" | wl-copy&apos; -- "%f"</command>
        <description>Copy just the filename (no directory) to the clipboard</description>
        <patterns>*</patterns>
        <directories/>
        <audio-files/>
        <image-files/>
        <other-files/>
        <text-files/>
        <video-files/>
      </action>
      <action>
        <icon>edit-copy</icon>
        <name>Copy Path</name>
        <unique-id>3-thunar-uca</unique-id>
        <command>bash -c &apos;printf %s "$1" | wl-copy&apos; -- "%f"</command>
        <description>Copy the full path of the selected file to the clipboard</description>
        <patterns>*</patterns>
        <directories/>
        <audio-files/>
        <image-files/>
        <other-files/>
        <text-files/>
        <video-files/>
      </action>
      <action>
        <icon>system-run</icon>
        <name>Open as Root</name>
        <unique-id>4-thunar-uca</unique-id>
        <command>pkexec thunar "%f"</command>
        <description>Open the selected folder in Thunar with root privileges via pkexec</description>
        <patterns>*</patterns>
        <directories/>
      </action>
    </actions>
    '';
  };
}
