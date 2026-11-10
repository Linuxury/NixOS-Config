# ===========================================================================
# modules/development/editors/neovim/neovim.nix — Neovim (NixOS entry point)
#
# Injects the Neovim Home Manager config (hm.nix) into linuxury's HM profile.
# All packages, LSPs, and the activation script live in hm.nix.
#
# Import this module in the host config to activate Neovim for linuxury.
# ===========================================================================

{ ... }:

{
  home-manager.users.linuxury.imports = [ ./neovim-hm.nix ];
}
