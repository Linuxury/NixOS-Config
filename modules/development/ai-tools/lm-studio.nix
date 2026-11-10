# ===========================================================================
# modules/development/ai-tools/lm-studio.nix — LM Studio
#
# LM Studio is a GUI application for discovering, downloading, and running
# local large language models (LLaMA, Mistral, Qwen, etc.) with a chat UI
# and an OpenAI-compatible local API server.
#
# Requires: modules/development/ai-tools/ai-tools.nix (nix-ld)
# LM Studio ships as a prebuilt binary — nix-ld must be enabled for it to run.
#
# Enable per host by importing this module alongside ai-tools/ai-tools.nix:
#   ../../modules/development/ai-tools/ai-tools.nix
#   ../../modules/development/ai-tools/lm-studio.nix
# ===========================================================================

{ pkgs, ... }:

{
  # =========================================================================
  # LM Studio — prebuilt GUI app, requires nix-ld (ai-tools/ai-tools.nix)
  # =========================================================================
  environment.systemPackages = [ pkgs.lmstudio ];
}
