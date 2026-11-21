# ===========================================================================
# modules/development/ai-tools/claude.nix — Claude Code + AI Skills
#
# Installs the claude-code CLI and wires the full AI skill environment for
# every HM user on this host via sharedModules — no per-host or per-user
# additions needed. Import this module once, all users get everything;
# remove the import to turn it off.
#
#   ~/.agents/skills      — agent harness skill library: one folder per skill,
#                           built below from the flake inputs upstream-skills
#                           and impeccable, plus pony-trail from pkgs.ponytrail.
#                           Pinned in flake.lock and read-only; the pins move
#                           with nru. To add a skill set: add a flake input
#                           (flake = false) and one link line inside agentsSkillsDir
#                           (let block).
#
#   ~/.agents/skills-catalog.md — the upstream catalog: a searchable index of
#                           every skill, so Claude can find the ones it does
#                           not load up front.
#
#   ~/.claude/skills/     — Claude Code skill pony-trail, installed via
#                           activation (a home.file link would conflict where
#                           ~/.claude is itself a symlink).
#
#   ~/.claude/settings.json — the plugins and marketplaces in claudePlugins
#                           (let block) are merged in via activation, so all
#                           users have them without wiping their existing settings.
#
# The VSCodium extension setting claudeCode.claudeProcessWrapper (written by
# editors/vscodium/vscodium-hm.nix) points at the bash wrapper so the extension
# uses the same Nix-installed binary.
#
# Requires: modules/development/ai-tools/ai-tools.nix (nix-ld)
# ===========================================================================

{ pkgs, lib, inputs, ... }:

let
  # One folder per skill, as ~/.agents/skills expects. Later links win on a
  # name clash.
  agentsSkillsDir = pkgs.runCommand "agent-skills" { } ''
    mkdir -p $out
    link() { ln -sfn "$1" "$out/$(basename "$1")"; }
    for d in ${inputs.upstream-skills}/skills/*/; do
      d="''${d%/}"; n=$(basename "$d")
      case $n in *superpowers*) continue ;; esac  # excluded on purpose
      if [[ $n =~ ^[a-z0-9-]+$ ]] || [ ! -f "$d/SKILL.md" ]; then link "$d"; continue; fi
      # Zed only loads names of lowercase letters, digits and hyphens: copy and rename.
      m=$(printf %s "$n" | tr 'A-Z_' 'a-z-')
      mkdir "$out/$m"; cp -r --no-preserve=mode "$d"/. "$out/$m"/
      sed -i "s/^name:.*/name: $m/" "$out/$m/SKILL.md"
    done
    link ${inputs.impeccable}/.agents/skills/impeccable
    link ${pkgs.ponytrail}/share/ponytrail/skills/pony-trail
  '';

  # Plugins to enable for every user, and the marketplaces they come from.
  #   enabledPlugins  "<plugin>@<marketplace>" = true/false (false = known but off)
  #   marketplaces    name -> source: { source = "github"; repo = ...; } or
  #                   { source = "directory"; path = ...; }
  # The official marketplace (lua-lsp, typescript-lsp) is built in.
  claudePlugins = {
    enabledPlugins = {
      "ponytail@DietrichGebert" = true;
      "ribbon@robonuggets" = false;
      "savvy-progress@claude-kit" = true;
      "cache-tax@claude-code-mods" = true;
      "blast-radius@claude-code-playground-mods" = true;
      "replay-theater@claude-code-playground-mods" = false;
      "lua-lsp@claude-plugins-official" = true;
      "typescript-lsp@claude-plugins-official" = true;
      # Essentials bundle: planning, git pushing, lint, debugging, TDD skills.
      "agentic-bundle-essentials@agentic-awesome-skills" = true;
    };
    marketplaces = {
      DietrichGebert.source = { source = "github"; repo = "DietrichGebert/ponytail"; };
      robonuggets.source = { source = "github"; repo = "robonuggets/ribbon"; };
      claude-kit.source = { source = "github"; repo = "JohnnyVizz/claude-kit"; };
      claude-code-mods.source = { source = "github"; repo = "karanb192/claude-code-mods"; };
      # The upstream repo is itself a marketplace of skill bundles; only the
      # Essentials bundle is enabled above. Pinned through the flake input.
      agentic-awesome-skills.source = {
        source = "directory";
        path = "${inputs.upstream-skills}";
      };
      # In a subfolder of its repo, so it is a directory marketplace.
      claude-code-playground-mods.source = {
        source = "directory";
        path = "${inputs.claude-code-playground}/claude-code/mods";
      };
    };
  };
in

{
  # =========================================================================
  # System packages — CLI tools available to all users
  #   claude  wrapper script around pkgs.claude-code that sets SHELL to bash
  # =========================================================================
  environment.systemPackages = [
    # Bash wrapper: claude-code uses bash-specific features that break under sh.
    (pkgs.writeShellScriptBin "claude" ''
      exec env SHELL=${pkgs.bash}/bin/bash ${pkgs.claude-code}/bin/claude "$@"
    '')
  ];

  # =========================================================================
  # Home Manager — applied to every HM user on this host
  # (home-manager.sharedModules entries are merged into each user's config)
  # =========================================================================
  home-manager.sharedModules = [
    ({ pkgs, lib, config, ... }: {

      # =====================================================================
      # ponytrail — dev tool, only for HM users (headless hosts have no HM)
      # =====================================================================
      home.packages = [ pkgs.ponytrail ];

      # =====================================================================
      # ~/.agents/skills — full agent harness skill library
      #
      # Before linking, a real (non-symlink) directory at that path is moved to
      # ~/.agents/skills.bak so Home Manager can create the managed symlink.
      # =====================================================================
      home.activation.migrateAgentsSkills =
        lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
          _target="$HOME/.agents/skills"
          if [ -d "$_target" ] && [ ! -L "$_target" ]; then
            $VERBOSE_ECHO "Migrating $_target → $_target.bak (now managed by Nix)"
            mv "$_target" "$_target.bak"
          fi
          unset _target
        '';

      home.file.".agents/skills".source = agentsSkillsDir;

      # One line per skill (name, description, category) for every skill in the
      # library. Claude only loads a few skills up front; to find any other one:
      # grep -i <keyword> ~/.agents/skills-catalog.md, then read
      # ~/.agents/skills/<name>/SKILL.md.
      home.file.".agents/skills-catalog.md".source = "${inputs.upstream-skills}/CATALOG.md";

      # =====================================================================
      # ~/.claude/skills — Claude Code specific skills
      #
      # Installed via activation rather than home.file to avoid conflicts
      # where ~/.claude is a symlink (to ~/.agents/Claude/). Copied once; an
      # existing pony-trail folder is left alone.
      # =====================================================================
      home.activation.installClaudeSkills =
        lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          _base="$HOME/.claude/skills"
          mkdir -p "$_base"

          # pony-trail — bundled inside the ponytrail Nix package
          if [ ! -d "$_base/pony-trail" ]; then
            $VERBOSE_ECHO "Installing pony-trail skill"
            cp -r ${pkgs.ponytrail}/share/ponytrail/skills/pony-trail/. "$_base/pony-trail/"
          fi

          unset _base
        '';

      # =====================================================================
      # ~/.claude/settings.json — enable the plugins listed in claudePlugins
      # (let block) and register their marketplaces.
      #
      # Merges only the keys we own (enabledPlugins, extraKnownMarketplaces) into
      # an existing settings.json (created as {} when missing) so user-local
      # settings (permissions, MCP servers, theme, etc.) are preserved. Also works
      # where ~/.claude is a symlink, because the shell resolves it at write time.
      # =====================================================================
      home.activation.configureClaudeSettings =
        lib.hm.dag.entryAfter [ "installClaudeSkills" ] ''
          _cfg="$HOME/.claude/settings.json"
          if [ ! -f "$_cfg" ]; then
            printf '{}' > "$_cfg"
          fi
          _tmp=$(${lib.getExe pkgs.jq} --argjson c ${lib.escapeShellArg (builtins.toJSON claudePlugins)} '
              .enabledPlugins = ((.enabledPlugins // {}) + $c.enabledPlugins)
            | .extraKnownMarketplaces = ((.extraKnownMarketplaces // {}) + $c.marketplaces)
            ' "$_cfg")
          printf '%s\n' "$_tmp" > "$_cfg"
          unset _cfg _tmp
        '';

    })
  ];
}
