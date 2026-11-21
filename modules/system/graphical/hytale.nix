# ===========================================================================
# modules/system/graphical/hytale.nix — Hytale launcher: auto-install + flatpak overrides
#
# Home Manager module that installs the Hytale launcher Flatpak and sets its
# sandbox overrides. Hytale is not on Flathub, so it installs from a bundled
# .flatpak file.
#   - Installs from the bundled flatpak on first login (Assets input)
#   - Optional CDN fallback (downloads if the local bundle is missing)
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
# Options:
#   programs.hytale.cdnFallback = true;     # default false; download from the
#                                           # Hytale CDN if the bundle is
#                                           # missing (linuxury uses this)
# ===========================================================================

{ config, pkgs, lib, inputs, ... }:

let
  cfg = config.programs.hytale;
in

{
  options.programs.hytale = {
    enable = lib.mkEnableOption "Hytale launcher auto-install and flatpak overrides";

    cdnFallback = lib.mkOption {
      type        = lib.types.bool;
      default     = false;
      description = ''
        Download the Hytale flatpak from the official CDN if the local bundle
        is not found. Requires network access at login. Intended for linuxury
        only — babylinux and alex always use the bundled file from the assets repo.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    # =========================================================================
    # Bundle path — ~/Documents/assets/flatpaks/hytale-launcher-latest.flatpak
    #
    # cdnFallback = false (babylinux, alex): symlink to the Assets input, a
    #   read-only store path.
    # cdnFallback = true (linuxury): a plain directory created by the
    #   activation below, so the downloaded file can be written there.
    # =========================================================================
    home.file = lib.mkIf (!cfg.cdnFallback) {
      "Documents/assets/flatpaks".source =
        "${inputs.assets}/flatpaks";
    };

    home.activation.hytale-flatpak-dir = lib.mkIf cfg.cdnFallback
      (lib.hm.dag.entryBefore [ "writeBoundary" ] ''
        mkdir -p "$HOME/Documents/assets/flatpaks"
      '');

    # =========================================================================
    # Install service — oneshot user unit started with the graphical session.
    #
    # ConditionPathExists skips it once Hytale is installed. With cdnFallback
    # it also waits for network-online.target.
    # =========================================================================
    systemd.user.services.hytale-flatpak-install = {
      Unit = {
        Description         = "Install Hytale launcher from bundled flatpak";
        After               = [ "graphical-session.target" ]
          ++ lib.optionals cfg.cdnFallback [ "network-online.target" ];
        Wants               = [ "graphical-session.target" ]
          ++ lib.optionals cfg.cdnFallback [ "network-online.target" ];
        ConditionPathExists = "!%h/.local/share/flatpak/app/com.hypixel.HytaleLauncher";
      };

      Service = {
        Type    = "oneshot";
        Restart = "no";
        ExecStart = "${pkgs.writeShellScript "install-hytale" (
          ''
            FLATPAK="${pkgs.flatpak}/bin/flatpak"
            FLATPAK_FILE="$HOME/Documents/assets/flatpaks/hytale-launcher-latest.flatpak"
          ''
          + lib.optionalString cfg.cdnFallback ''
            CURL="${pkgs.curl}/bin/curl"
            HYTALE_URL="https://launcher.hytale.com/builds/release/linux/amd64/hytale-launcher-latest.flatpak"
          ''
          + ''

            if $FLATPAK info --user com.hypixel.HytaleLauncher &>/dev/null; then
              echo "Hytale already installed, skipping."
              exit 0
            fi

            # Ensure Flathub is available for runtime dependencies
            $FLATPAK remote-add --user --if-not-exists flathub \
              https://flathub.org/repo/flathub.flatpakrepo 2>/dev/null || true

          ''
          + lib.optionalString cfg.cdnFallback ''
            if [ ! -f "$FLATPAK_FILE" ]; then
              echo "Local bundle not found — downloading from $HYTALE_URL"
              mkdir -p "$(dirname "$FLATPAK_FILE")"
              if ! $CURL -L --fail -o "$FLATPAK_FILE" "$HYTALE_URL"; then
                echo "ERROR: Could not download Hytale. Check internet or clone the assets repo."
                exit 1
              fi
            fi

          ''
          + lib.optionalString (!cfg.cdnFallback) ''
            if [ ! -f "$FLATPAK_FILE" ]; then
              echo "ERROR: Hytale flatpak not found at $FLATPAK_FILE"
              echo "  Place hytale-launcher-latest.flatpak in the Assets repo (flatpaks/), then run nru."
              exit 1
            fi

          ''
          + ''
            echo "Installing Hytale launcher..."
            $FLATPAK install --user --noninteractive "$FLATPAK_FILE" || true

            # Remove the sideload origin remote — it has no appstream data and
            # causes COSMIC Store's flatpak-user backend to fail on load.
            $FLATPAK remote-delete --user --force hytalelauncher-origin 2>/dev/null || true

            if $FLATPAK info --user com.hypixel.HytaleLauncher &>/dev/null; then
              echo "Hytale installed successfully."
            else
              echo "ERROR: Hytale install failed. Check journalctl --user -u hytale-flatpak-install"
              exit 1
            fi
          ''
        )}";
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
  };
}
