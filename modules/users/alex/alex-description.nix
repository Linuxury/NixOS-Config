# ===========================================================================
# modules/users/alex/alex-description.nix — Set alex's display name via agenix
#
# Same pattern as linuxury/linuxury-description.nix — decrypts the full name
# (GECOS field) at activation time and applies it with usermod after the users
# script, so the field is not blank after a rebuild.
#
# Imported by: Alex-Desktop, Alex-Laptop
# Requires the host's SSH key to be a recipient of the secret (secrets/secrets.nix,
# re-key with agenix -r), otherwise decryption fails at activation.
# Secret: secrets/users/alex/description.age
# To turn off: remove the import from the host file.
# ===========================================================================

{ config, pkgs, ... }:

{
  # agenix secret holding the display name; decrypted to config.age.secrets.description-alex.path.
  # Other options: owner, group, mode (default 0400 root), path, symlink.
  age.secrets.description-alex = {
    file = ../../../secrets/users/alex/description.age;
  };

  # Activation script: deps order it after the secret is decrypted ("agenix")
  # and the account exists/updated ("users").
  system.activationScripts.alex-description = {
    deps = [ "agenix" "users" ];
    text = ''
      ${pkgs.shadow}/bin/usermod \
        --comment "$(cat ${config.age.secrets.description-alex.path})" \
        alex
    '';
  };
}
