# ===========================================================================
# modules/users/babylinux/babylinux-description.nix — Set babylinux's display name via agenix
#
# Same pattern as linuxury/linuxury-description.nix — decrypts the real name at
# activation time and applies it with usermod after the users script.
#
# Imported by: Ryzen5800x, Asus-A15
# NOTE: Only import after real SSH host keys are collected for these machines
#       and secrets/users/babylinux/description.age has been re-keyed to include them.
# Secret: secrets/users/babylinux/description.age
# ===========================================================================

{ config, pkgs, ... }:

{
  age.secrets.description-babylinux = {
    file = ../../../secrets/users/babylinux/description.age;
  };

  # Git identity ([user] email), read by git via programs.git.includes in babylinux-home.nix.
  age.secrets.git-email-babylinux = {
    file  = ../../../secrets/users/babylinux/git-email.age;
    owner = "babylinux";
    mode  = "0400";
  };

  system.activationScripts.babylinux-description = {
    deps = [ "agenix" "users" ];
    text = ''
      ${pkgs.shadow}/bin/usermod \
        --comment "$(cat ${config.age.secrets.description-babylinux.path})" \
        babylinux
    '';
  };
}
