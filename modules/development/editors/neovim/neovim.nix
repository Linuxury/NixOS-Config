# ===========================================================================
# modules/development/editors/neovim/neovim.nix — Neovim (NixOS entry point)
#
# Injects the Neovim Home Manager config (neovim-hm.nix) into linuxury's HM
# profile via home-manager.users.linuxury.imports. All packages, LSPs, and the
# activation script live in neovim-hm.nix.
#
# Import this module in the host config to activate Neovim for linuxury;
# remove the import to turn it off.
# ===========================================================================

{ ... }:

{
  home-manager.users.linuxury.imports = [ ./neovim-hm.nix ];
}
