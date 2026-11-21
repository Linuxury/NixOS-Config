# ===========================================================================
# modules/system/graphical/helium.nix — Helium browser
#
# Helium is a privacy-focused Chromium-based browser with built-in ad and
# tracker blocking, split view, and !bang search shortcuts. It is not in
# nixpkgs; the package comes from the helium-browser flake input.
#
# Turn it on by importing this module from a host:
#   ../../modules/system/graphical/helium.nix
# Remove the import to turn it off.
#
#   environment.systemPackages   Helium for every user on the host
#   environment.etc."chromium/policies/managed/policies.json"
#                                the managed policy, when deSlop is on
#   home.file helium.desktop     desktop entry with
#                                --password-store=gnome-libsecret, so Helium
#                                uses the keyring unlocked at login instead
#                                of asking for a password on every launch
#
# Option of this module:
#   programs.helium.deSlop.enable   (default true) deploys
#     chromium/policies.json from the dotfiles input: telemetry, tracking
#     and password manager off, uBlock Origin and Proton Pass
#     force-installed, uBlock preloaded with a hardened filter list plus the
#     yt-shorts hider (github.com/gijsdev/ublock-hide-yt-shorts). Set false
#     to opt out. Helium bundles its own uBlock Origin fork, and whether it
#     reads the standard Chromium policy path is unverified; check
#     chrome://policy and chrome://extensions after enabling.
# ===========================================================================

{ config, pkgs, inputs, lib, ... }:

let
  cfg = config.programs.helium;
in

{
  options.programs.helium.deSlop.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Deploy the de-slop managed policy (dotfiles/chromium/policies.json).";
  };

  config = lib.mkMerge [
    {
      # =======================================================================
      # Helium — system package (available to all users on this host)
      # =======================================================================
      environment.systemPackages = [
        inputs.helium-browser.packages.${pkgs.stdenv.hostPlatform.system}.helium
      ];
    }

    (lib.mkIf cfg.deSlop.enable {
      environment.etc."chromium/policies/managed/policies.json".source =
        "${inputs.dotfiles}/chromium/policies.json";
    })

    {
      # =======================================================================
      # Desktop entry override — bind Helium to the system keyring
      #
      # Written to ~/.local/share/applications/, which comes before the
      # package's entry in XDG_DATA_DIRS and so overrides it.
      # home-manager.sharedModules applies it to every user on the host.
      # =======================================================================
      home-manager.sharedModules = [
        {
          home.file.".local/share/applications/helium.desktop".text = ''
            [Desktop Entry]
            Type=Application
            Version=1.5
            Name=Helium
            GenericName=Web Browser
            Icon=helium
            Exec=helium --password-store=gnome-libsecret %U
            Terminal=false
            Categories=Network;WebBrowser;
            MimeType=text/html;text/xml;application/xhtml+xml;x-scheme-handler/http;x-scheme-handler/https;
          '';
        }
      ];
    }
  ];
}
