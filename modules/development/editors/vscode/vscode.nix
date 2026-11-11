# modules/development/editors/vscode/vscode.nix — VS Code (Microsoft build), vanilla.
# No extensions/settings managed; tweak after trying it.
{ pkgs, ... }:

{
  environment.systemPackages = [ pkgs.vscode ];
}
