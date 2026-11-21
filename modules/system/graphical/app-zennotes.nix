# ===========================================================================
# modules/system/graphical/app-zennotes.nix — ZenNotes desktop client
#
# Installs ZenNotes, a keyboard-first Markdown notes app with Vim motions,
# live math and diagrams, and MCP integration. Turn it on by importing this
# file from a host; remove the import to turn it off.
#
#   environment.systemPackages   pkgs.zennotes-desktop; the package ships its
#                                own .desktop entry, icon and MIME types
#
# After install, connect to the self-hosted server:
#   Settings → Connect to Remote Vault → http://Media-Server:7879
#   Enter the auth token from secrets/services/zennotes-auth-token.age
#
# Server module: modules/services/zennotes/service-zennotes.nix (Media-Server)
# ===========================================================================

{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.zennotes-desktop ];
}
