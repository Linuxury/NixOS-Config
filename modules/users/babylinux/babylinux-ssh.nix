# ===========================================================================
# modules/users/babylinux/babylinux-ssh.nix — Deploy babylinux's SSH authorized key
#
# Import this into every host where babylinux needs SSH access.
# Mirrors linuxury/linuxury-ssh.nix — same mechanism, different key. NixOS's
# sshd reads /etc/ssh/authorized_keys.d/%u by default, so no sshd changes are
# needed. To turn off: remove the import from the host file.
#
# The encrypted secret lives at: secrets/users/babylinux/authorized-key.age
# At activation it decrypts to:  /etc/ssh/authorized_keys.d/babylinux
#
# Imported by: Ryzen5800x, Asus-A15
# ===========================================================================

{ ... }:

{
  age.secrets.babylinux-authorized-key = {
    file = ../../../secrets/users/babylinux/authorized-key.age; # encrypted public key
    path = "/etc/ssh/authorized_keys.d/babylinux";              # where sshd looks for this user's keys
    mode = "0444";                                              # public key, must be readable by sshd
  };
}
