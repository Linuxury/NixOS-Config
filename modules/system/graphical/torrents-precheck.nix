# ===========================================================================
# modules/system/graphical/torrents-precheck.nix — Fast-fail for Torrents automount
#
# Makes the /mnt/Torrents CIFS automount fail fast when Media-Server
# (10.0.0.3) is unreachable, e.g. a laptop away from the home LAN. Without
# it, mount.cifs waits out the full TCP SYN timeout (~120s), and file
# managers such as COSMIC Files, which probe favourite paths on startup and
# retry, hang for over a minute.
#
# Two parts:
#   1. A oneshot pre-check (radxa-smb-check) tests SMB port 445 with
#      `nc -w 1`; the mount requires it, so an offline server fails in ~1s.
#   2. A start limit on the mount unit: after 2 failures within 60s, further
#      automount requests get an immediate error instead of a new attempt.
#
# Turns itself on: everything is under lib.mkIf, so it applies only to hosts
# that define fileSystems."/mnt/Torrents" and is a no-op elsewhere.
# ===========================================================================

{ config, pkgs, lib, ... }:

lib.mkIf (config.fileSystems ? "/mnt/Torrents") {

  # Oneshot service: probe Media-Server port 445 with a 1s timeout.
  #   Type = oneshot, RemainAfterExit = false   re-runs on every mount attempt
  #   DefaultDependencies = no                  no implicit ordering on
  #                                             basic.target / shutdown
  #   startLimitIntervalSec / startLimitBurst   at most 5 runs per 30s
  systemd.services.radxa-smb-check = {
    description = "Check Media-Server SMB connectivity before mounting Torrents";
    serviceConfig = {
      Type            = "oneshot";
      ExecStart       = "${pkgs.netcat-openbsd}/bin/nc -z -w 1 10.0.0.3 445";
      RemainAfterExit = false;
    };
    unitConfig = {
      DefaultDependencies = "no";
    };
    # Rate-limit the check itself so it cannot flood the network
    startLimitIntervalSec = 30;
    startLimitBurst       = 5;
  };

  # Drop-in for the generated mnt-Torrents.mount unit:
  #   Requires / After=radxa-smb-check   the check must pass before mounting
  #   StartLimitIntervalSec=60, StartLimitBurst=2
  #                     after 2 failures in 60s, callers get an immediate
  #                     error and the automount releases waiting processes
  #
  # systemd.units with overrideStrategy = "asDropin" writes a drop-in
  # (mnt-Torrents.mount.d/overrides.conf) next to the generated unit.
  # environment.etc cannot do this: /etc/systemd/system is a store symlink,
  # so no subdirectories can be created inside it.
  systemd.units."mnt-Torrents.mount" = {
    overrideStrategy = "asDropin";
    text = ''
      [Unit]
      Requires=radxa-smb-check.service
      After=radxa-smb-check.service
      StartLimitIntervalSec=60
      StartLimitBurst=2
    '';
  };

}
