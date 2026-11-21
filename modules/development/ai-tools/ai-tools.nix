# ===========================================================================
# modules/development/ai-tools/ai-tools.nix — AI tools base infrastructure
#
# Provides the runtime plumbing that claude, opencode and lm-studio depend on.
# Import this alongside any AI tool module; remove the import to turn it off.
#
#   nix-ld   — compatibility shim so prebuilt Linux binaries (claude-code)
#               can run on NixOS without ELF patching.
#   uv       — runs Python-based MCP servers via `uvx` without a global venv.
#   ffmpeg   — required by the faster-whisper MCP server for audio processing.
# ===========================================================================

{ pkgs, ... }:

{
  # =========================================================================
  # nix-ld — dynamic linker compatibility for prebuilt binaries
  #   enable     install a stub dynamic linker at the FHS path so unpatched ELF
  #              binaries start
  #   libraries  shared libraries those binaries can find (default set plus glibc);
  #              add more here if a binary reports a missing .so
  # =========================================================================
  programs.nix-ld = {
    enable    = true;
    libraries = with pkgs; [ glibc ];
  };

  # =========================================================================
  # MCP server runtime dependencies
  # =========================================================================
  environment.systemPackages = with pkgs; [
    uv      # uvx runner for Python MCP servers — no venv management needed
    ffmpeg  # audio processing for the faster-whisper MCP server
  ];

  # =========================================================================
  # IteraCompute API key (free Qwen tier) — shells export it as
  # ITERACOMPUTE_API_KEY (ZSH repo, conf.d/core/00-env.zsh) for any AI tool to use.
  # Also declared identically in editors/zed; identical definitions merge.
  #   file   encrypted source        mode   0440: owner + group read
  #   owner  root                    group  users, so every local user can read it
  # =========================================================================
  age.secrets.iteracompute-api-key = {
    file  = ../../../secrets/api-keys/iteracompute.age;
    mode  = "0440";
    owner = "root";
    group = "users";
  };
}
