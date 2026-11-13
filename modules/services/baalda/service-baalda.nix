# ===========================================================================
# modules/services/baalda/service-baalda.nix — Baalda self-hosted sync server
#
# Local-first Markdown notes; the server stores CRDT updates in Postgres and
# serves sync + MCP. No image is published upstream, so the pinned tag is built
# on the host. Tailnet only: https://media-server.tail1023a0.ts.net
#
# Secret: secrets/baalda-env.age (env-file format)
#   POSTGRES_PASSWORD, JWT_SECRET, DATABASE_URL, BETTER_AUTH_URL
#   POSTGRES_PASSWORD only applies at first initdb; changing it later needs ALTER USER.
# Data:    /var/lib/baalda/pgdata (NVMe; Postgres does not belong on mergerfs)
# Backups: /data/backups/baalda (nightly pg_dump, 14 days)
# ===========================================================================

{ config, lib, pkgs, ... }:

let
  # Pinned tag, shared with the desktop package; scripts/baalda-bump rewrites it.
  pin     = builtins.fromJSON (builtins.readFile ../../../pkgs/baalda/baalda.json);
  podman  = "${pkgs.podman}/bin/podman";
  ts      = "${config.services.tailscale.package}/bin/tailscale";
  image   = "localhost/baalda-server:${pin.version}";
  envFile = config.age.secrets.baalda-env.path;

  # BAALDA_DEPLOYMENT=self-hosted lifts the cloud limits (no Polar token set).
  serverEnv = {
    NODE_ENV          = "production";
    BAALDA_DEPLOYMENT = "self-hosted";
    PORT              = "3010";
  };
  envArgs = lib.concatMapStringsSep " " (n: "-e ${n}=${serverEnv.${n}}") (builtins.attrNames serverEnv);
in
{
  virtualisation.podman.enable = lib.mkDefault true;
  virtualisation.oci-containers.backend = lib.mkDefault "podman";

  age.secrets.baalda-env = {
    file = ../../../secrets/baalda-env.age;
    mode = "0400";
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/baalda/pgdata  0700 70   70   -"   # uid 70 = postgres in the alpine image
    "d /data/backups/baalda    0750 root root -"
  ];

  # ===========================================================================
  # Containers: Postgres (no published port) and the server (loopback only)
  # ===========================================================================
  virtualisation.oci-containers.containers = {
    baalda-postgres = {
      image            = "docker.io/library/postgres:16-alpine";
      volumes          = [ "/var/lib/baalda/pgdata:/var/lib/postgresql/data" ];
      environment      = { POSTGRES_USER = "baalda"; POSTGRES_DB = "baalda"; };
      environmentFiles = [ envFile ];
      extraOptions     = [ "--network=baalda" ];
    };

    baalda-server = {
      inherit image;
      ports            = [ "127.0.0.1:3010:3010" ];
      environment      = serverEnv;
      environmentFiles = [ envFile ];
      extraOptions     = [ "--network=baalda" ];
      dependsOn        = [ "baalda-postgres" ];
    };
  };

  # ===========================================================================
  # Start order: network -> postgres -> image build -> migrate -> server
  # ===========================================================================
  systemd.services.baalda-network = {
    description   = "Create the baalda podman network";
    wantedBy      = [ "multi-user.target" ];
    before        = [ "podman-baalda-postgres.service" "podman-baalda-server.service" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    script        = "${podman} network exists baalda || ${podman} network create baalda";
  };

  systemd.services.baalda-build = {
    description   = "Build the Baalda server image from the pinned tag";
    wantedBy      = [ "multi-user.target" ];
    wants         = [ "network-online.target" ];
    after         = [ "network-online.target" ];
    before        = [ "baalda-migrate.service" "podman-baalda-server.service" ];
    path          = [ pkgs.git ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; TimeoutStartSec = 1200; };
    script = ''
      if ! ${podman} image exists ${image}; then
        src=$(mktemp -d)
        trap 'rm -rf "$src"' EXIT
        git clone --depth 1 --branch v${pin.version} https://github.com/naveedharri/baalda.git "$src"
        ${podman} build -f app/apps/server/Dockerfile -t ${image} "$src"
      fi
      # Keep the newest two tags for rollback; a running image refuses removal, hence || true.
      ${podman} images --format '{{.Tag}}' localhost/baalda-server | sort -V | head -n -2 \
        | while read -r t; do ${podman} rmi "localhost/baalda-server:$t" || true; done
    '';
  };

  # Migrations land before the server accepts traffic (upstream's Compose design).
  systemd.services.baalda-migrate = {
    description   = "Apply Baalda database migrations";
    wantedBy      = [ "multi-user.target" ];
    after         = [ "baalda-build.service" "podman-baalda-postgres.service" ];
    requires      = [ "baalda-build.service" "podman-baalda-postgres.service" ];
    before        = [ "podman-baalda-server.service" ];
    path          = [ pkgs.gzip ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    script = ''
      for _ in $(seq 1 60); do
        ${podman} exec baalda-postgres pg_isready -U baalda -d baalda -q && break
        sleep 2
      done
      # One dump per version, taken before its migrations; restore it if a bump goes wrong.
      f=/data/backups/baalda/baalda-pre-migrate-${pin.version}.sql.gz
      if [ ! -e "$f" ]; then
        set -o pipefail
        ${podman} exec baalda-postgres pg_dump -U baalda baalda | gzip > "$f.tmp"
        mv "$f.tmp" "$f"
      fi
      ${podman} run --rm --network=baalda --env-file ${envFile} ${envArgs} \
        ${image} node dist/db/migrate.js
    '';
  };

  systemd.services.podman-baalda-postgres = {
    after    = [ "baalda-network.service" "agenix.service" ];
    requires = [ "baalda-network.service" ];
    wants    = [ "agenix.service" ];
  };

  systemd.services.podman-baalda-server = {
    after    = [ "baalda-migrate.service" ];
    requires = [ "baalda-migrate.service" ];
  };

  # ===========================================================================
  # HTTPS over the tailnet (certificates are enabled in the admin console)
  # ===========================================================================
  systemd.services.tailscale-serve-baalda = {
    description   = "Publish Baalda over tailnet HTTPS";
    wantedBy      = [ "multi-user.target" ];
    wants         = [ "tailscaled.service" ];
    after         = [ "tailscaled.service" "podman-baalda-server.service" ];
    serviceConfig = { Type = "oneshot"; RemainAfterExit = true; };
    # tailscaled can take a while to log in after boot, so retry.
    script = ''
      for _ in $(seq 1 30); do
        ${ts} serve --bg --https=443 http://127.0.0.1:3010 && exit 0
        sleep 2
      done
      exit 1
    '';
    preStop = "${ts} serve --https=443 off || true";
  };

  networking.firewall.interfaces."tailscale0".allowedTCPPorts = [ 443 ];

  # ===========================================================================
  # Nightly dump
  # ===========================================================================
  systemd.services.baalda-backup = {
    description   = "Dump the Baalda database";
    after         = [ "podman-baalda-postgres.service" ];
    path          = [ pkgs.gzip ];
    serviceConfig.Type = "oneshot";
    script = ''
      set -o pipefail
      out=/data/backups/baalda/baalda-$(date +%F).sql.gz
      ${podman} exec baalda-postgres pg_dump -U baalda baalda | gzip > "$out.tmp"
      mv "$out.tmp" "$out"
      find /data/backups/baalda -name 'baalda-*.sql.gz' -mtime +14 -delete
    '';
  };

  systemd.timers.baalda-backup = {
    wantedBy    = [ "timers.target" ];
    timerConfig = { OnCalendar = "*-*-* 03:30:00"; Persistent = true; };
  };
}
