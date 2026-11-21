# ===========================================================================
# modules/development/ai-tools/goose.nix — Goose AI agent
#
# Goose (block/goose) with Claude through the claude-acp provider: Goose drives
# the official Claude Code via the claude-agent-acp adapter, so requests come
# from Claude Code and the Claude Pro/Max subscription covers them. (Tools that
# reuse Claude's OAuth login directly, like opencode-claude-auth, get rejected.)
# Shares the subscription's usage limits with Claude Code.
#
# One-time setup per user (~/.config/goose/config.yaml is app-owned, so it's
# not managed here):
#   goose configure → Configure Providers → Claude Code → model "default" (opus)
#   Optional: Goose Settings → Goose Mode → smart_approve (ask before acting;
#   the default "auto" runs tools without asking).
#
# Requires: modules/development/ai-tools/claude.nix (logged-in claude)
# Enable per host by importing this module; remove the import to turn it off.
# ===========================================================================

{ pkgs, inputs, ... }:

{
  # System packages:
  #   goose-cli         the agent, taken from the separate nixpkgs-goose input
  #                     (flake.nix) so it is built from a pinned nixpkgs revision
  #   claude-agent-acp  ACP adapter the claude-acp provider runs
  environment.systemPackages = with pkgs; [
    # Taken from the nixpkgs-goose input rather than the main nixpkgs
    inputs.nixpkgs-goose.legacyPackages.${pkgs.stdenv.hostPlatform.system}.goose-cli
    claude-agent-acp  # ACP adapter Goose's claude-acp provider runs
  ];
}
