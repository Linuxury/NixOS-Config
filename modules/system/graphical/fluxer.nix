# ===========================================================================
# modules/system/graphical/fluxer.nix — Fluxer chat client
#
# Installs Fluxer, a self-hostable chat and community app (voice, video,
# servers), from nixpkgs. Turn it on per host by importing this file in
# hosts/<name>/<name>.nix; remove the import to turn it off.
#
#   pkgs.fluxer-canary-bin  the only Fluxer package in nixpkgs: the canary
#                           (pre-release) channel, updated with the flake
#                           inputs. The stable channel exists only as the
#                           Flathub app app.fluxer.Fluxer.
# ===========================================================================
{ pkgs, ... }:
{
  environment.systemPackages = [ pkgs.fluxer-canary-bin ];
}
