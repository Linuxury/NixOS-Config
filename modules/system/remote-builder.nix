# ===========================================================================
# modules/system/remote-builder.nix — offload Nix builds to MinisForum
#
# Sends Nix builds from a low-RAM host to MinisForum (16 cores, 31 GB,
# always on). Importing this file turns it on; there is no enable flag.
# Remove the import to turn it off. Imported by Radxa-X4, which
# build-capacity.nix limits to 1 job x 4 cores on 7 GB; the other hosts
# build locally about as fast as the builder does.
#
#   age.secrets.nix-builder-key       SSH key nix-daemon uses to log in
#   programs.ssh.knownHosts.minisforum  pinned builder host key
#   nix.distributedBuilds             use nix.buildMachines
#   nix.buildMachines                 the builder (see below)
#   nix.settings.builders-use-substitutes, fallback
#
# Trust: the key logs into `nixbuilder` on MinisForum, a trusted-user there
# that can add any path to that host's store. The key is therefore
# root-equivalent on the builder, so it is not deployed to child-account
# hosts. See secrets/secrets.nix.
#
# The builder is not a single point of failure: max-jobs keeps the value
# build-capacity.nix sets (never 0), and `fallback` builds locally when
# MinisForum is unreachable.
# ===========================================================================

{ config, ... }:

{
  # Private half of the builder keypair. nix-daemon runs as root, so root
  # owns it, read-only (0400). Owner root is agenix's default, written out to
  # match hosts/Radxa-X4/Radxa-X4.nix.
  age.secrets.nix-builder-key = {
    file  = ../../secrets/services/nix-builder-key.age;
    mode  = "0400";
    owner = "root";
  };

  # Pins the builder's host key instead of trusting it on first contact.
  # Writes /etc/ssh/ssh_known_hosts, which root's ssh reads. The attribute
  # name is the hostname matched, the same name buildMachines dials below.
  # The key is MinisForum's host key, also listed in secrets/secrets.nix.
  # Alternative: buildMachines.publicHostKey (base64 of the key line,
  # easy to get wrong).
  programs.ssh.knownHosts.minisforum.publicKey =
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM/HPvxQY35jS4VDZRy4viIfHIGjUqkCgFhRVNcIsZRG";

  nix = {
    distributedBuilds = true;

    # One builder. nix.buildMachines.* options:
    #   hostName           host to ssh to
    #   sshUser / sshKey   login user and private key
    #   protocol           "ssh-ng" (newer protocol) or "ssh"
    #   systems / system   platforms it builds for
    #   maxJobs            parallel builds sent to it
    #   speedFactor        preference among several builders (default 1)
    #   supportedFeatures  features it offers (big-parallel, kvm, …)
    #   mandatoryFeatures  features a build must require to be sent there
    #   publicHostKey      base64 host key (knownHosts is used instead)
    buildMachines = [{
      # Tailscale MagicDNS resolves this system-wide, not only through a
      # user's ~/.ssh/config, so nix-daemon (root) reaches it by name on the
      # LAN or away.
      hostName   = "minisforum";
      sshUser    = "nixbuilder";
      sshKey     = config.age.secrets.nix-builder-key.path;
      protocol   = "ssh-ng";
      systems    = [ "x86_64-linux" ];

      # Matches MinisForum's own 2 x 16; each remote build gets 16 threads,
      # and the idle CPU/IO scheduling keeps Crafty (Minecraft) responsive.
      maxJobs = 2;
      # speedFactor stays at its default: it only orders builders against
      # each other, and MinisForum is the only one.

      # big-parallel lets large packages (the ones that run a low-RAM host
      # out of memory) build remotely; kvm covers builds needing /dev/kvm.
      supportedFeatures = [ "big-parallel" "kvm" ];
    }];

    settings = {
      # The builder fetches from cache.nixos.org itself rather than having
      # substitutes proxied through the weak client's uplink.
      builders-use-substitutes = true;

      # Build locally if MinisForum is unreachable instead of failing the
      # rebuild. build-capacity.nix's floor tier relies on this.
      fallback = true;
    };
  };
}
