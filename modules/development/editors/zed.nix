# ===========================================================================
# modules/development/editors/zed.nix — Zed Editor
#
# Zed is a fast, Wayland-native code editor written in Rust with built-in
# LSP support, vim mode, blurred window background, and GPU rendering.
#
# Enable per host by importing this module (remove the import to turn it off):
#   ../../modules/development/editors/zed.nix
#
# Sets: WGPU_BACKEND, the iteracompute-api-key secret, a zeditor wrapper
# package plus nixd, text-editor MIME defaults, and three activation steps
# (bootstrap settings, inject OpenRouter key, write the IteraCompute provider).
#
# Settings portability: dotfiles/zed/settings.json holds the full baseline
# config (fonts, panels, keymap, agent setup, etc). On first activation, if
# ~/.config/zed/settings.json doesn't exist yet, it's copied from that tracked
# template, so a new host gets the same setup instead of starting blank. After
# that first copy the file is left alone (Zed writes to it directly via its
# Settings UI, and the key injection below edits it in place), so per-host
# changes are kept and not reset to the template on rebuild.
#
# AI: Claude via OpenRouter (language_model_providers.openai → openrouter.ai),
# plus free Qwen via IteraCompute (language_models.openai_compatible.iteracompute).
# The OpenRouter key is injected from /run/agenix/openrouter-api-key at
# activation time; the IteraCompute key comes from ITERACOMPUTE_API_KEY, set
# by the zeditor wrapper. Neither key is ever in the Nix store or the repo.
# ===========================================================================

{ lib, pkgs, ... }:

{
  # WGPU_BACKEND = "gl": make Zed's wgpu renderer use OpenGL instead of Vulkan
  # (other values: vulkan, dx12, metal, auto). Set for every session.
  environment.sessionVariables.WGPU_BACKEND = "gl";

  # IteraCompute key — readable by every normal user (group users). Also
  # declared identically in ai-tools/ai-tools.nix; identical definitions merge.
  #   file   encrypted source       mode   0440: owner + group read
  #   owner  root                   group  users
  age.secrets.iteracompute-api-key = {
    file  = ../../../secrets/api-keys/iteracompute.age;
    mode  = "0440";
    owner = "root";
    group = "users";
  };

  # =========================================================================
  # Zed — system package (available to all users on this host)
  # =========================================================================
  # Zed reads provider keys from <PROVIDER_ID>_API_KEY env vars or the keychain,
  # never from settings.json. The wrapper loads the IteraCompute key at launch,
  # so it works for every user and from the desktop file (Exec=zeditor via PATH).
  #   symlinkJoin + makeWrapper  copy of zed-editor whose zeditor binary first
  #                              exports ITERACOMPUTE_API_KEY from the agenix file
  #   nixd                       Nix language server
  environment.systemPackages = with pkgs; [
    (symlinkJoin {
      name = "zed-editor-${zed-editor.version}";
      paths = [ zed-editor ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = ''
        wrapProgram $out/bin/zeditor --run \
          '[ -r /run/agenix/iteracompute-api-key ] && export ITERACOMPUTE_API_KEY="$(cat /run/agenix/iteracompute-api-key)"'
      '';
    })
    nixd        # Nix language server — used by Zed's Nix extension
  ];

  # Text editor MIME defaults — lib.mkForce wins over VSCodium (plain) and
  # Neovim (lib.mkDefault) when all three are installed on the same host.
  # home-manager.sharedModules entries are merged into every user's config.
  home-manager.sharedModules = [
    ({ lib, ... }: {
      xdg.mimeApps.defaultApplications = {
        "text/plain"                = lib.mkForce "dev.zed.Zed.desktop";
        "application/json"          = lib.mkForce "dev.zed.Zed.desktop";
        "application/x-yaml"        = lib.mkForce "dev.zed.Zed.desktop";
        "application/toml"          = lib.mkForce "dev.zed.Zed.desktop";
        "application/x-shellscript" = lib.mkForce "dev.zed.Zed.desktop";
        "text/x-shellscript"        = lib.mkForce "dev.zed.Zed.desktop";
      };

      # =====================================================================
      # Bootstrap ~/.config/zed/settings.json from the tracked template.
      #
      # Only copies if the file doesn't exist yet. Existing configs are never
      # overwritten. Runs after writeBoundary.
      # =====================================================================
      home.activation.zedBootstrapSettings =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          _cfg="$HOME/.config/zed/settings.json"
          _template="$HOME/dotfiles/zed/settings.json"
          mkdir -p "$HOME/.config/zed"
          if [ ! -f "$_cfg" ] && [ -f "$_template" ]; then
            cp "$_template" "$_cfg"
          fi
          unset _cfg _template
        '';

      # =====================================================================
      # Inject OpenRouter API key into Zed's settings.json at activation time.
      #
      # Zed doesn't support environment variable expansion in settings values,
      # so jq writes the key (language_model_providers.openai.api_key) into the
      # file from the agenix runtime path. Runs on every rebuild; re-running is
      # harmless (idempotent merge). Skipped when the key or settings file is missing.
      #
      # Zed uses JSONC (JSON with comments). sed strips comment lines before
      # jq parses; the result is written back as plain JSON — Zed accepts both.
      # =====================================================================
      home.activation.zedInjectOpenRouterKey =
        lib.hm.dag.entryAfter [ "zedBootstrapSettings" ] ''
          _key_file="/run/agenix/openrouter-api-key"
          _cfg="$HOME/.config/zed/settings.json"
          if [ -r "$_key_file" ] && [ -f "$_cfg" ]; then
            _key=$(cat "$_key_file")
            _tmp=$(${pkgs.gnused}/bin/sed '/^[[:space:]]*\/\//d' "$_cfg" \
              | ${lib.getExe pkgs.jq} \
                  --arg key "$_key" \
                  '.language_model_providers.openai.api_key = $key')
            printf '%s\n' "$_tmp" > "$_cfg"
            unset _key _tmp
          fi
          unset _key_file _cfg
        '';

      # IteraCompute provider (free Qwen tier). Writes the whole provider block
      # so users whose settings.json predates it get it too. Provider id
      # "iteracompute" → Zed reads the key from ITERACOMPUTE_API_KEY (set by
      # the zeditor wrapper above). Model role assignments stay per-user.
      # Sets api_url and one model (name, display_name, max_tokens,
      # max_output_tokens, capabilities); also deletes the legacy
      # language_model_providers.openai_compatible block.
      home.activation.zedIteraComputeProvider =
        lib.hm.dag.entryAfter [ "zedInjectOpenRouterKey" ] ''
          _cfg="$HOME/.config/zed/settings.json"
          if [ -r /run/agenix/iteracompute-api-key ] && [ -f "$_cfg" ]; then
            _tmp=$(${pkgs.gnused}/bin/sed '/^[[:space:]]*\/\//d' "$_cfg" \
              | ${lib.getExe pkgs.jq} \
                  'del(.language_model_providers.openai_compatible)
                   | .language_models.openai_compatible.iteracompute = {
                     api_url: "https://api.iteracompute.com/v1",
                     available_models: [{
                       name: "qwen/qwen3.8-27b",
                       display_name: "Qwen 3.8 27B (free)",
                       max_tokens: 128000,
                       max_output_tokens: 8192,
                       capabilities: { tools: true, images: true, parallel_tool_calls: false, prompt_cache_key: false }
                     }]
                   }')
            printf '%s\n' "$_tmp" > "$_cfg"
            unset _tmp
          fi
          unset _cfg
        '';
    })
  ];
}
