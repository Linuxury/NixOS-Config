# ===========================================================================
# modules/system/graphical/zen-browser.nix — Zen Browser
#
# Zen is a Firefox-based browser focused on privacy and a clean UI. It is
# not in nixpkgs; it comes from the Home Manager module of the zen-browser
# flake input (github:0xc000022070/zen-browser-flake), for linuxury only.
#
# Turn it on by importing this module from a host:
#   ../../modules/system/graphical/zen-browser.nix
# Remove the import to turn it off.
#
# Option of this module:
#   programs.zen-browser.deSlop.enable   (default true) applies the managed
#     policy shared with Firefox (dotfiles/firefox/policies.json; Zen reads
#     the same schema): telemetry, AI and password manager off, uBlock Origin
#     and Proton Pass force-installed, uBlock preloaded with a hardened
#     filter list plus the yt-shorts hider
#     (github.com/gijsdev/ublock-hide-yt-shorts). Set false to opt out.
# ===========================================================================

{ config, inputs, lib, ... }:

let
  cfg = config.programs.zen-browser;
in

{
  options.programs.zen-browser.deSlop.enable = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = "Apply the de-slop managed policy (dotfiles/firefox/policies.json) to Zen.";
  };

  config = {
    # =======================================================================
    # Zen Browser — Home Manager module from the flake (homeModules.default,
    # the beta channel). It is built on Home Manager's Firefox module, so it
    # takes the same options:
    #   enable               install Zen
    #   policies             enterprise policies (from policies.json here);
    #                        policies.Preferences sets prefs without needing
    #                        the on-disk profile name
    #   profiles.<name>      per-profile settings, search, bookmarks,
    #                        extensions
    #   nativeMessagingHosts, languagePacks
    # Zen-specific extras, not set here: setAsDefaultBrowser,
    # profiles.<name>.mods / keyboardShortcuts / pins, extraPrefs.
    # =======================================================================
    home-manager.users.linuxury = {
      imports = [ inputs.zen-browser.homeModules.default ];

      programs.zen-browser = {
        enable = true;

        policies = lib.mkIf cfg.deSlop.enable
          (builtins.fromJSON (builtins.readFile "${inputs.dotfiles}/firefox/policies.json")).policies;

        # gfx.color_management.hdr stays unset: it tints all SDR video red
        # (same Gecko bug as Firefox, see firefox.nix).
      };
    };
  };
}
