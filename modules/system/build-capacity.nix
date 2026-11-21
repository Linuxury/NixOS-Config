# ===========================================================================
# modules/system/build-capacity.nix — per-host nix build parallelism
#
# Sets nix.settings.max-jobs and nix.settings.cores per host from its RAM
# and thread count. Imported by modules/system/core.nix, so every host gets
# it; a host overrides either value in its own file (both are mkDefault).
#
# The two settings control different things, so one fleet-wide pair is
# wrong for most hosts:
#
#   cores     — parallelism INSIDE one derivation (make -j). The MEMORY knob:
#               it is what multiplies into RAM. cores = 0 means "all of them",
#               so max-jobs × nproc compilers can run at once. On a 16-thread
#               host with 14 GB that is 32 compilers ≈ 32 GB — an OOM kill.
#   max-jobs  — how many derivations run AT ONCE. The THROUGHPUT knob: a
#               rebuild is mostly a long tail of small single-threaded
#               derivations, and a low max-jobs leaves most cores idle.
#
# So: cap total threads by RAM, pick max-jobs for throughput, divide to get
# cores. Specs come from hosts/<host>/specs.nix, written once by
# scripts/host-specs.sh and committed — nix eval is pure and cannot read
# /proc, so detection happens out of band and the result lives in git where
# dry-build can check it.
#
# A host without specs.nix (not probed, or old hardware such as the
# child-account hosts) gets the floor tier. Those machines rarely compile
# anything because nearly every path comes from cache.nixos.org, so
# surviving an unexpected build matters more than its speed.
#
# This module does not set nix.settings.fallback. Note that core.nix sets
# fallback = true for every host, so a floor-tier host also builds from
# source when substitution fails; remote-builder.nix sets it too.
# ===========================================================================

{ lib, hostname, ... }:

let
  specFile = ../../hosts/${hostname}/specs.nix;
  spec = if builtins.pathExists specFile then import specFile else null;

  # Hosts without specs.nix: 1 job x 2 cores, below the smallest probed
  # host (Radxa-X4, 4c/7G -> 1 x 4).
  floor = { jobs = 1; cores = 2; };

  # ~0.75 GB of RAM per build thread. This cap is what keeps core-rich,
  # RAM-poor hosts safe (ThinkPad: 10 threads on 14 GB, not 16).
  threads = lib.min spec.cores ((spec.ramGB * 3) / 4);
  # At most 2 slots, and each gets all the RAM-safe threads, not a share:
  # a rebuild is one or two big compiles plus many sub-second derivations,
  # and splitting threads across many slots leaves a big compile on a few
  # threads while the other slots sit idle. A second slot is used only when
  # the RAM budget covers both slots at full width; otherwise one (the small
  # derivations barely notice running one at a time).
  jobs = if (spec.ramGB * 3) / 4 >= 2 * threads then 2 else 1;

  cap = if spec == null then floor else {
    inherit jobs;
    cores = lib.max 1 threads;
  };
in
{
  nix.settings = {
    max-jobs = lib.mkDefault cap.jobs;
    cores    = lib.mkDefault cap.cores;   # never 0 — see header
  };
}
