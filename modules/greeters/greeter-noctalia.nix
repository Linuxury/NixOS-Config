# ===========================================================================
# modules/greeters/greeter-noctalia.nix — noctalia-greeter (greetd)
#
# First-party login greeter for Noctalia v5. Runs under greetd with its own
# bundled wlroots compositor — no SDDM/Qt6 involved.
#
# Bundled automatically by shells/noctalia/shell-noctalia.nix — importing that
# shell module pulls this in too, no separate host import needed. Only
# import this directly if you want the greeter without the Noctalia shell.
#
# What this module owns:
#   - services.greetd + services.displayManager.noctalia-greeter (enabled via the upstream
#     NixOS module — see inputs.noctalia-greeter.nixosModules.default)
#   - Default session — "Umbriel" (Name= from Umbriel's own session .desktop
#     entry, registered automatically by modules/compositors/umbriel).
#     session.default matches by picker label, not id. The default is shared
#     by every host that imports shells/noctalia (Ryzen5900x), so a host with
#     a different compositor would need a per-host default instead.
#   - Cursor theme (BreezeX-Light, matches the Hyprland/Noctalia session —
#     see modules/themes/gtk.nix). Not in nixpkgs; provided by the
#     breezex-cursors overlay (flake.nix). Installed system-wide below so the
#     greeter compositor can find it under /run/current-system/sw/share/icons
#     regardless of which compositor module is paired with this shell.
#
# What this module does NOT own:
#   - Wallpaper/palette sync — appearance.scheme = "Synced" below picks up
#     whatever Noctalia Shell last pushed via Settings -> Security ->
#     Noctalia Greeter -> "Sync Now". That's a manual action in the shell,
#     not something worth replicating declaratively (unlike hypr-sddm's
#     matugen-driven wallpaper copy, which exists because SDDM has no
#     native concept of "the shell's current theme").
#
# Options (services.displayManager.noctalia-greeter.*):
#   enable                   run the greeter under greetd
#   package                  greeter build (here from the flake input)
#   passwordless-sync-users  users allowed the appearance-only sync without
#                            a password prompt (Polkit rule)
#   settings                 greeter config: session.default, appearance
#                            (scheme, theme_mode), cursor (theme, size, path)
#   Not set here: greeter-args (extra noctalia-greeter-session args),
#   cursorTheme.package (deprecated, use settings.cursor.path).
# ===========================================================================

{ config, inputs, lib, pkgs, ... }:

{
  imports = [ inputs.noctalia-greeter.nixosModules.default ];

  services.displayManager.noctalia-greeter = {
    enable = true;
    package = inputs.noctalia-greeter.packages.${pkgs.stdenv.hostPlatform.system}.default;

    # Polkit rule: appearance-only sync from the shell skips the password prompt
    # for every normal user on the host (whoever is logged in can sync).
    passwordless-sync-users = lib.attrNames (lib.filterAttrs (_: u: u.isNormalUser) config.users.users);

    settings = {
      session.default = "Umbriel";

      appearance = {
        scheme = "Synced";
        theme_mode = "dark";
      };

      cursor = {
        theme = "BreezeX-Light";
        size = 24;
        path = "/run/current-system/sw/share/icons";
      };
    };
  };

  environment.systemPackages = [ pkgs.breezex-cursors ];
}
