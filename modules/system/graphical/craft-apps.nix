# ===========================================================================
# modules/system/graphical/craft-apps.nix — storytold Craft apps
#
# (https://getartcraft.com/apps). Not in nixpkgs yet; packaged
# from upstream's prebuilt release tarballs in pkgs/craft-apps/package.nix
# (versions + hashes live there).
#
# Grouped into suites mirroring Microsoft/Adobe. Hosts pick with:
#   craftApps.suites = [ "office" ];   # default: every suite except ai
#
#   office   — WordCraft, GridCraft, DeckCraft, PdfCraft  (Word/Excel/PowerPoint/Acrobat)
#   photo    — PhotoCraft, LightCraft                     (Photoshop/Lightroom)
#   graphics — VectorCraft, DesignCraft, FigCraft         (Illustrator/InDesign/Figma)
#   3d       — TextureCraft, MaterialCraft                (Substance Designer/Painter)
#   video    — FilmCraft, EffectCraft, AniCraft           (Premiere/After Effects/Animate)
#   audio    — SoundCraft                                 (Audition)
#   cad      — CADCraft                                   (AutoCAD)
#   ai       — ArtCraft, Craft Anything                   (AI-driven; opt-in only)
#
# Overlay is scoped here, so only hosts importing this module fetch them.
#
# Claude Desktop: on hosts that also import claude-desktop, each installed
# app's `<app>-cli mcp` (headless stdio MCP server) is merged into
# ~/.config/Claude/claude_desktop_config.json. Each app reads only its type
# folder (~/Pictures, ~/Documents, ~/Videos, ~/Music) and writes only to that
# folder's Craft/ subfolder: new files land there and originals can't be
# overwritten. The CLIs take one read and one write root each (repeats are
# refused). LightCraft/FilmCraft/GridCraft/CADCraft have no root flags
# (unconfined); their dir only decides which Craft/ folder gets created.
# TextureCraft/MaterialCraft take the roots but refuse all writes without them.
# ===========================================================================

{ config, lib, pkgs, ... }:

let
  suites = with pkgs.craft-apps; {
    office   = [ wordcraft gridcraft deckcraft pdfcraft ];
    photo    = [ photocraft lightcraft ];
    graphics = [ vectorcraft designcraft figcraft ];
    "3d"     = [ texturecraft materialcraft ];
    video    = [ filmcraft effectcraft anicraft ];
    audio    = [ soundcraft ];
    cad      = [ cadcraft ];
    ai       = [ artcraft craft-anything ];
  };
  installed = lib.concatMap (s: suites.${s}) config.craftApps.suites;
  # Apps absent from `mcp` (AniCraft, ArtCraft) get no MCP server.
  mcpApps = lib.filter (a: mcp ? ${a.pname}) installed;

  # Type folder under ~ + args after `<app>-cli`. "roots" = read <dir>,
  # write <dir>/Craft.
  mcp = {
    photocraft  = { dir = "Pictures";  args = [ "mcp" "roots" ]; };
    lightcraft  = { dir = "Pictures";  args = [ "mcp" "--compact" ]; };           # 393 tools → 17
    vectorcraft = { dir = "Pictures";  args = [ "mcp" "--headless" "roots" ]; };  # default tries the GUI on :7979 first
    figcraft    = { dir = "Pictures";  args = [ "mcp" "roots" ]; };
    texturecraft = { dir = "Pictures"; args = [ "mcp" "roots" ]; };               # unconfined = no writes at all, so it needs roots
    materialcraft = { dir = "Pictures"; args = [ "mcp" "roots" ]; };              # same --automation-*-root flags as texturecraft
    wordcraft   = { dir = "Documents"; args = [ "mcp" "roots" ]; };
    pdfcraft    = { dir = "Documents"; args = [ "mcp" "--compact" "roots" ]; };   # 179 tools → 17
    deckcraft   = { dir = "Documents"; args = [ "mcp" "roots" ]; };
    designcraft = { dir = "Documents"; args = [ "mcp" "roots" ]; };
    gridcraft   = { dir = "Documents"; args = [ "mcp" ]; };
    cadcraft    = { dir = "Documents"; args = [ "mcp" ]; };
    effectcraft = { dir = "Videos";    args = [ "mcp" "roots" ]; };
    filmcraft   = { dir = "Videos";    args = [ "mcp" ]; };
    soundcraft  = { dir = "Music";     args = [ "mcp" "roots" ]; };
    # No root flags (unconfined). Default mode asks before running code or acting
    # on the device; --allow-run would skip that, so it's deliberately left off.
    craft-anything = { dir = "Documents"; args = [ "mcp" ]; };
  };
in
{
  options.craftApps.suites = lib.mkOption {
    type        = lib.types.listOf (lib.types.enum (lib.attrNames suites));
    default     = lib.remove "ai" (lib.attrNames suites);
    description = "Which Craft app suites to install.";
  };

  config = {
    nixpkgs.overlays = [
      (final: prev: {
        craft-apps = prev.callPackage ../../../pkgs/craft-apps/package.nix {};
      })
    ];

    environment.systemPackages = installed;

    # The claude-desktop overlay is scoped to its module, so this is exactly
    # the hosts that have Claude Desktop.
    home-manager.sharedModules = lib.mkIf (pkgs ? claude-desktop) [
      ({ config, lib, pkgs, ... }: let
        home = config.home.homeDirectory;
        craftDir = app: "${home}/${mcp.${app.pname}.dir}/Craft";
        servers = lib.listToAttrs (map (app: let m = mcp.${app.pname}; in lib.nameValuePair app.pname {
          command = "${app}/bin/${app.pname}-cli";
          args = lib.concatMap (a: if a == "roots"
            then [ "--automation-read-root" "${home}/${m.dir}" "--automation-write-root" (craftDir app) ]
            else [ a ]) m.args;
        }) mcpApps);
        craftDirs = lib.escapeShellArgs (lib.unique (map craftDir mcpApps));
        serversJson = pkgs.writeText "craft-mcp-servers.json" (builtins.toJSON servers);
        # Every Craft server name, installed or not, so the merge removes
        # exactly these keys and never a hand-added server like "minecraft".
        craftNames = lib.escapeShellArg (builtins.toJSON (lib.attrNames mcp));
      in {
        # The app rewrites this file itself, so merge instead of symlinking.
        # Craft keys are replaced wholesale: a dropped suite drops its servers.
        # Writes go through `run` (no-op under --dry-run) and land via
        # tmp + mv, so a failed or interrupted switch never truncates it.
        home.activation.registerCraftMcp = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run mkdir -p ${craftDirs} "${home}/.config/Claude"
          _cfg="${home}/.config/Claude/claude_desktop_config.json"
          _cur=$(cat "$_cfg" 2>/dev/null || printf '{}')
          if _new=$(printf '%s' "$_cur" | ${lib.getExe pkgs.jq} \
              --slurpfile s ${serversJson} --argjson names ${craftNames} \
              '.mcpServers = ((.mcpServers // {} | with_entries(select(.key as $k | $names | index($k) | not))) + $s[0])'); then
            if [ "$_new" != "$_cur" ]; then
              printf '%s\n' "$_new" | run tee "$_cfg.hm-tmp" > /dev/null
              run mv "$_cfg.hm-tmp" "$_cfg"
            fi
          else
            warnEcho "registerCraftMcp: $_cfg is not valid JSON; left untouched"
          fi
          unset _cfg _cur _new
        '';
      })
    ];
  };
}
