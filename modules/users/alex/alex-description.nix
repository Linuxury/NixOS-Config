# ===========================================================================
# modules/users/alex/alex-description.nix — Set alex's display name via agenix
#
# Same pattern as linuxury/linuxury-description.nix — decrypts the real name at
# activation time and applies it with usermod after the users script.
#
# Imported by: Alex-Desktop, Alex-Laptop
# NOTE: Only import after real SSH host keys are collected for these machines
#       and secrets/users/alex/description.age has been re-keyed to include them.
# Secret: secrets/users/alex/description.age
# ===========================================================================

{ config, pkgs, ... }:

{
  age.secrets.description-alex = {
    file = ../../../secrets/users/alex/description.age;
  };

  system.activationScripts.alex-description = {
    deps = [ "agenix" "users" ];
    text = ''
      ${pkgs.shadow}/bin/usermod \
        --comment "$(cat ${config.age.secrets.description-alex.path})" \
        alex
    '';
  };
}
