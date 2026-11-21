# ===========================================================================
# modules/system/graphical/hytale.nix — Hytale launcher: auto-install + flatpak overrides
#
# Home Manager module that installs the Hytale launcher Flatpak and sets its
# sandbox overrides. Hytale is not on Flathub; the launcher is downloaded
# from Hytale's own release URL and keeps itself up to date after install.
#   - Install on first login: download, `flatpak install --user`, delete
#     the download (Flathub is added as a user remote for the runtime)
#   - Flatpak overrides applied on every rebuild:
#       ELECTRON_OZONE_PLATFORM_HINT=x11  (prevents a blank window on COSMIC)
#       --device=input                    (controller support)
#       --filesystem=/run/udev:ro         (SDL2 udev enumeration)
#
# Controllers: Hytale detects Xbox, PlayStation and Switch pads natively but
# has no Steam Input translation, so a Steam Controller is not recognised.
# Nothing in this repo can work around that.
#
# Turn it on in a user's home.nix:
#   imports = [ ../../modules/system/graphical/hytale.nix ];
#   programs.hytale.enable = true;          # default false
# ===========================================================================

{ config, pkgs, lib, ... }:

let
  cfg = config.programs.hytale;
  url = "https://launcher.hytale.com/builds/release/linux/amd64/hytale-launcher-latest.flatpak";
in
{
  options.programs.hytale.enable =
    lib.mkEnableOption "Hytale launcher auto-install and flatpak overrides";

  config = lib.mkIf cfg.enable {
    # =========================================================================
    # Install service — oneshot user unit started with the graphical session.
    #
    # ConditionPathExists skips it once Hytale is installed. User units can't
    # order on network-online.target (system manager only), so curl retries
    # for about a minute while the network comes up after login.
    # =========================================================================
    systemd.user.services.hytale-flatpak-install = {
      Unit = {
        Description         = "Install the Hytale launcher from hytale.com";
        After               = [ "graphical-session.target" ];
        Wants               = [ "graphical-session.target" ];
        ConditionPathExists = "!%h/.local/share/flatpak/app/com.hypixel.HytaleLauncher";
      };

      Service = {
        Type    = "oneshot";
        Restart = "no";
        ExecStart = "${pkgs.writeShellScript "install-hytale" ''
          FLATPAK="${pkgs.flatpak}/bin/flatpak"
          if $FLATPAK info --user com.hypixel.HytaleLauncher &>/dev/null; then
            echo "Hytale already installed, skipping."
            exit 0
          fi
          # Runtime dependencies come from Flathub
          $FLATPAK remote-add --user --if-not-exists flathub \
            https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

          file=$(mktemp --suffix=.flatpak)
          trap 'rm -f "$file"' EXIT
          echo "Downloading ${url}"
          if ! ${pkgs.curl}/bin/curl -L --fail --retry 10 --retry-delay 6 --retry-all-errors \
               -o "$file" "${url}"; then
            echo "ERROR: could not download Hytale. Check the network, then: systemctl --user start hytale-flatpak-install"
            exit 1
          fi

          echo "Installing Hytale launcher..."
          $FLATPAK install --user --noninteractive "$file" || true
          # Remove the sideload origin remote — it has no appstream data and
          # causes COSMIC Store's flatpak-user backend to fail on load.
          $FLATPAK remote-delete --user --force hytalelauncher-origin 2>/dev/null || true
          if $FLATPAK info --user com.hypixel.HytaleLauncher &>/dev/null; then
            echo "Hytale installed successfully."
          else
            echo "ERROR: Hytale install failed. Check journalctl --user -u hytale-flatpak-install"
            exit 1
          fi
        ''}";
      };

      Install.WantedBy = [ "graphical-session.target" ];
    };

    # =========================================================================
    # Flatpak overrides — `flatpak override --user`, applied on every Home
    # Manager activation (repeat runs change nothing)
    #
    # ELECTRON_OZONE_PLATFORM_HINT=x11: forces XWayland mode so Hytale's
    #   Electron renderer doesn't use native Wayland GPU paths that produce
    #   a blank window on COSMIC.
    # --device=input: grants the sandbox access to /dev/input/* nodes so
    #   the kernel-visible controllers are reachable inside the Flatpak.
    # --filesystem=/run/udev:ro: SDL2's udev enumeration backend walks
    #   /run/udev/data/ to map device nodes to capabilities. Without this,
    #   SDL2 reports zero gamepads even though the nodes are accessible.
    # =========================================================================
    home.activation.hytale-overrides = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      ${pkgs.flatpak}/bin/flatpak override --user \
        --env=ELECTRON_OZONE_PLATFORM_HINT=x11 \
        --device=input \
        --filesystem=/run/udev:ro \
        com.hypixel.HytaleLauncher 2>/dev/null || true
    '';

    # =========================================================================
    # Flathub cleanup on restricted hosts — on every Home Manager activation
    #
    # The install service adds a user "flathub" remote for Hytale's runtime.
    # Hosts without a system Flathub remote (the child-account hosts remove
    # every system remote so there is no app store) would otherwise keep that
    # user remote, and with it a Flathub store. There, the user remote is
    # deleted again; installed apps stay, Hytale keeps updating itself, and
    # its runtime updates on the next reinstall. Hosts with a system Flathub
    # remote are left alone (their users may install from a user remote).
    # =========================================================================
    home.activation.hytale-flathub-cleanup = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if ! ${pkgs.flatpak}/bin/flatpak remote-list --system --columns=name 2>/dev/null | ${pkgs.gnugrep}/bin/grep -qx flathub; then
        ${pkgs.flatpak}/bin/flatpak remote-delete --user --force flathub 2>/dev/null || true
      fi
    '';
  };
}
