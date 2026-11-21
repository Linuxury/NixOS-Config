# ===========================================================================
# modules/system/graphical/fluxer.nix — Fluxer via Flathub (system-wide)
#
# Installs Fluxer, a self-hostable chat and community app, from Flathub
# (nixpkgs has no package for it). Imported by graphical.nix, so it runs on
# every graphical host; remove that import to turn it off.
#
# A systemd user service installs the Flatpak for each user at first login.
#   ConditionPathExists   skips the unit once the app directory exists
#   after / wants         waits for the graphical session and the network
#   Type = oneshot        runs once per login, Restart = "no"
#
# The script exits cleanly when:
#   - Fluxer is already installed
#   - the system has no Flathub remote (child-account hosts remove all
#     system remotes)
#
# Requires services.flatpak.enable = true and the Flathub system remote,
# both set in graphical.nix.
# ===========================================================================

{ pkgs, ... }:

{
  systemd.user.services.fluxer-flatpak-install = {
    description         = "Install Fluxer from Flathub";
    after               = [ "graphical-session.target" "network-online.target" ];
    wants               = [ "graphical-session.target" "network-online.target" ];
    unitConfig.ConditionPathExists =
      "!%h/.local/share/flatpak/app/app.fluxer.Fluxer";
    serviceConfig = {
      Type    = "oneshot";
      Restart = "no";
      ExecStart = pkgs.writeShellScript "install-fluxer" ''
        FLATPAK="${pkgs.flatpak}/bin/flatpak"

        # Skip gracefully on hosts where Flathub has been removed (e.g. Alex's machines)
        if ! $FLATPAK remote-list --system 2>/dev/null | grep -q flathub; then
          echo "Flathub remote not available, skipping Fluxer install."
          exit 0
        fi

        if $FLATPAK info --user app.fluxer.Fluxer &>/dev/null; then
          echo "Fluxer already installed, skipping."
          exit 0
        fi

        echo "Installing Fluxer from Flathub..."
        if $FLATPAK install --user --noninteractive flathub app.fluxer.Fluxer; then
          echo "Fluxer installed successfully."
        else
          echo "ERROR: Fluxer install failed. Check: journalctl --user -u fluxer-flatpak-install"
          exit 1
        fi
      '';
    };
    wantedBy = [ "graphical-session.target" ];
  };
}
