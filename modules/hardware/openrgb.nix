# ===========================================================================
# modules/hardware/openrgb.nix — OpenRGB RGB lighting control
#
# Wrapper around nixpkgs services.hardware.openrgb. flake.nix (mkHost)
# imports it for every host; it does nothing until a host turns it on:
#
#   hardware.openrgb.enable = true;
#
# Enabling installs the openrgb package, its udev rules (device access for
# non-root users) and the `openrgb --server` systemd service.
#
# Options of this wrapper:
#   enable        turn the whole module on (default false)
#   motherboard   "amd" (default) or "intel"; loads i2c-piix4 or i2c-i801
#                 for SMBus RGB devices
#   profile       profile file under /var/lib/OpenRGB loaded at startup;
#                 null (default) loads none. Leave it null when something
#                 else sets the colours (Noctalia led-sync): a startup profile
#                 is applied after device detection and overrides it.
#                 null also switches off every ProfileManager trigger
#                 (startup/suspend/resume/shutdown...) in the server's
#                 /var/lib/OpenRGB/OpenRGB.json before each start: OpenRGB
#                 1.1 keeps those GUI-set triggers there, outside the CLI flag.
#
# Upstream services.hardware.openrgb also offers, not set here:
#   package       OpenRGB build to use (default pkgs.openrgb)
#   server.port   SDK server port (default 6742)
# ===========================================================================

{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.openrgb;
in
{
  # ==============================================================
  # Options
  # ==============================================================
  options.hardware.openrgb = {
    enable = lib.mkEnableOption "OpenRGB with udev rules and server daemon";

    motherboard = lib.mkOption {
      type = lib.types.enum [ "amd" "intel" ];
      default = "amd";
      description = "Motherboard platform — loads the matching SMBus kernel module.";
    };

    profile = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Profile loaded by the server on boot; null loads none.";
    };
  };

  # ==============================================================
  # Implementation — only materialises when enable = true
  # ==============================================================
  config = lib.mkIf cfg.enable {
    services.hardware.openrgb = {
      enable = true;
      motherboard = cfg.motherboard;
      startupProfile = cfg.profile;
    };

    # No profile: keep the server from loading any saved profile itself.
    systemd.services.openrgb.preStart = lib.mkIf (cfg.profile == null) ''
      f=/var/lib/OpenRGB/OpenRGB.json
      if [ -f "$f" ] && ${pkgs.jq}/bin/jq -e '.ProfileManager' "$f" >/dev/null; then
        ${pkgs.jq}/bin/jq '.ProfileManager |= with_entries(.value.enabled = false)' "$f" > "$f.tmp"
        mv "$f.tmp" "$f"
      fi
    '';
  };
}
