# ===========================================================================
# modules/compositors/umbriel/umbriel-themes.nix — Umbriel theme
#
# Extends the shared GTK base with Kvantum + qt6ct wiring — toolkit-level
# config, not Hyprland-specific, so reused verbatim from
# compositors/hyprland/hyprland-themes.nix.
#
# gtk-decoration-layout (window buttons for GTK CSD apps) is left out here:
# Umbriel's appearance.prefer_no_csd defaults to true (its own border-only
# decoration). Add the gtk3/gtk4 extraConfig lines from hyprland-themes.nix
# if GTK apps show the wrong buttons.
#
# For the cursor, icon theme, GTK dark mode, and dconf base, see:
#   modules/themes/gtk.nix
#
# Home Manager module: umbriel.nix adds it to home-manager.sharedModules.
# Remove it from that list to turn it off.
# ===========================================================================

{ ... }:

{
  imports = [ ../../themes/gtk.nix ];

  # =========================================================================
  # Qt theming — Kvantum + qt6ct
  #
  # Kvantum reads its active theme from kvantumrc. matugen writes the
  # kvantum-colors theme files to ~/.config/Kvantum/kvantum-colors/ on each
  # wallpaper change, so the palette stays in sync automatically — Noctalia
  # has no Kvantum template, so matugen keeps this part.
  #
  # qt6ct.conf itself stays fully Nix-managed (Noctalia's own "qt" theming
  # is compiled-in, not a shell apply.sh like kitty/gtk — it only writes a
  # separate color file at colors/noctalia.conf). color_scheme_path points
  # there: theme-matugen.nix (the matugen config on this compositor) has no
  # qt6ct template, so colors/matugen.conf is never written here.
  # =========================================================================
  home.file.".config/Kvantum/kvantumrc".text = ''
    [General]
    theme=kvantum-colors
  '';

  home.file.".config/qt6ct/qt6ct.conf" = {
    force = true;
    text = ''
    [Appearance]
    color_scheme_path=%h/.config/qt6ct/colors/noctalia.conf
    custom_palette=true
    icon_theme=Tela-dark
    style=kvantum

    [Fonts]
    fixed=@Variant(\0\0\0@\0\0\0\x12JetBrainsMono Nerd Font\0\0\0\0\0\0\0\0\0\xfe\xff\xff\xff)
    general=@Variant(\0\0\0@\0\0\0\nNoto Sans\0\0\0\0\0\0\0\0\0\xfe\xff\xff\xff)
  '';
  };
}
