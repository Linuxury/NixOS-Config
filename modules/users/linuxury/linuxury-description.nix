# ===========================================================================
# modules/users/linuxury/linuxury-description.nix — Set linuxury's display name via agenix
#
# NixOS resets the GECOS (full name) field to blank on every nixos-rebuild
# because users.users.linuxury.description is not set in the config.
# This module decrypts the real name at activation time and applies it with
# usermod — running after both agenix (secret decrypted) and users (account
# updated) so the GECOS field is never blank after a switch. Also declares the
# git email secret for linuxury.
#
# Imported by: ThinkPad, Ryzen5900x
# Secrets: secrets/users/linuxury/description.age, secrets/users/linuxury/git-email.age
# To turn off: remove the import from the host file.
# ===========================================================================

{ config, pkgs, ... }:

{
  # Display name, decrypted to config.age.secrets.description-linuxury.path.
  # Other options: owner, group, mode (default 0400 root), path, symlink.
  age.secrets.description-linuxury = {
    file = ../../../secrets/users/linuxury/description.age;
  };

  # Git identity ([user] email), read by git via programs.git.includes in linuxury-home.nix.
  #   owner  the user that runs git, so it can read the file
  #   mode   0400: owner read only
  age.secrets.git-email-linuxury = {
    file  = ../../../secrets/users/linuxury/git-email.age;
    owner = "linuxury";
    mode  = "0400";
  };

  # Activation script: deps order it after the secrets are decrypted ("agenix")
  # and the account exists/updated ("users").
  system.activationScripts.linuxury-description = {
    deps = [ "agenix" "users" ];
    text = ''
      ${pkgs.shadow}/bin/usermod \
        --comment "$(cat ${config.age.secrets.description-linuxury.path})" \
        linuxury
    '';
  };

}
