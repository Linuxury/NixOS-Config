# ===========================================================================
# modules/users/babylinux/babylinux-description.nix — Set babylinux's display name via agenix
#
# Same pattern as linuxury/linuxury-description.nix — decrypts the full name
# (GECOS field) at activation time and applies it with usermod after the users
# script, so the field is not blank after a rebuild. Also declares the git
# email secret for babylinux.
#
# Imported by: Ryzen5800x, Asus-A15
# Requires the host's SSH key to be a recipient of the secrets (secrets/secrets.nix,
# re-key with agenix -r), otherwise decryption fails at activation.
# Secrets: secrets/users/babylinux/description.age, secrets/users/babylinux/git-email.age
# To turn off: remove the import from the host file.
# ===========================================================================

{ config, pkgs, ... }:

{
  # Display name, decrypted to config.age.secrets.description-babylinux.path.
  # Other options: owner, group, mode (default 0400 root), path, symlink.
  age.secrets.description-babylinux = {
    file = ../../../secrets/users/babylinux/description.age;
  };

  # Git identity ([user] email), read by git via programs.git.includes in babylinux-home.nix.
  #   owner  the user that runs git, so it can read the file
  #   mode   0400: owner read only
  age.secrets.git-email-babylinux = {
    file  = ../../../secrets/users/babylinux/git-email.age;
    owner = "babylinux";
    mode  = "0400";
  };

  # Activation script: deps order it after the secrets are decrypted ("agenix")
  # and the account exists/updated ("users").
  system.activationScripts.babylinux-description = {
    deps = [ "agenix" "users" ];
    text = ''
      ${pkgs.shadow}/bin/usermod \
        --comment "$(cat ${config.age.secrets.description-babylinux.path})" \
        babylinux
    '';
  };
}
