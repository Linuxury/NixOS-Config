# ===========================================================================
# modules/hardware/peripherals/lemokey-keychron.nix — WebHID access
#
# Lets the logged-in user reach Lemokey and Keychron devices over WebHID.
# flake.nix (mkHost) imports it for every host; it does nothing until a host
# turns it on:
#
#   hardware.lemokey-keychron.enable = true;    # default false
#
# The Lemokey and Keychron web launchers use the WebHID API to configure
# keyboards and mice directly from the browser. By default /dev/hidraw*
# nodes are root-only. TAG+="uaccess" tells systemd-logind to grant the
# active logged-in user a session-scoped ACL — no MODE=0666 or static
# group needed.
#
# The rules ship as 70-*.rules through services.udev.packages, not
# services.udev.extraRules: extraRules goes into 99-local.rules, which runs
# after 73-seat-late.rules (where uaccess tags become ACLs), so a tag set
# there would never be applied.
#
# VID 362d = Lemokey  (Hall Effect keyboards — P1 HE, etc.)
# VID 3434 = Keychron (QMK keyboards + M-series mice)
# ===========================================================================

{ config, lib, pkgs, ... }:

let
  cfg = config.hardware.lemokey-keychron;
in
{
  # ==============================================================
  # Options
  # ==============================================================
  options.hardware.lemokey-keychron = {
    enable = lib.mkEnableOption "udev rules for Lemokey/Keychron WebHID configurators";
  };

  # ==============================================================
  # Implementation — only materialises when enable = true
  # ==============================================================
  config = lib.mkIf cfg.enable {
    services.udev.packages = [
      (pkgs.writeTextDir "lib/udev/rules.d/70-lemokey-keychron.rules" ''
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="362d", TAG+="uaccess"
        KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="3434", TAG+="uaccess"
      '')
    ];
  };
}
