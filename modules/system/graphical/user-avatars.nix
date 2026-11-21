# ===========================================================================
# modules/system/graphical/user-avatars.nix — user avatar setup
#
# Sets each user's login avatar. Imported by graphical.nix, so it runs on
# every graphical host; remove that import to turn it off.
#
#   services.accounts-daemon.enable       AccountsService D-Bus daemon
#   system.activationScripts.user-avatars copies each avatar on every
#                                         activation (rebuild and boot)
#
# Each avatar is written to two places so every greeter can find it:
#
#   1. /var/lib/sddm-faces/${username}.face.icon
#      SDDM's FacesDir lookup, which needs no AccountsService. NixOS builds
#      SDDM without libaccountsservice, so this is the only path SDDM's
#      UserModel reads. The sddm module sets FacesDir to this directory. The
#      name must end in .face.icon for SDDM, and hypr-sddm's QML regex
#      (patched to accept .icon) then loads it.
#
#   2. /var/lib/AccountsService/icons/${username}.${ext}
#      plus /var/lib/AccountsService/users/${username} pointing at it.
#      Used by cosmic-greeter, gdm, and any D-Bus client reading
#      org.freedesktop.Accounts.User.IconFile.
#
# Avatar source layout (Avatar/ in the Assets input, flake input "assets"):
#   linuxury.jpg     → linuxury
#   babylinux.jpeg   → babylinux
#   alexander.jpg    → alex
#
# Paths point straight into the Assets input, not the Home Manager
# ~/Pictures/Avatar symlink: system activation scripts run before Home
# Manager activation, so on a fresh install that symlink does not exist yet.
# The input is a store path and is always present.
# Only users defined as normal users on the host are handled, and the
# [ -f ] guard skips any user whose avatar file is missing.
# ===========================================================================

{ config, pkgs, lib, inputs, ... }:

let
  # Username -> avatar file in the Assets flake input (read directly, see
  # the header for why).
  avatarMap = {
    linuxury  = "${inputs.assets}/Avatar/linuxury.jpg";
    babylinux = "${inputs.assets}/Avatar/babylinux.jpeg";
    alex      = "${inputs.assets}/Avatar/alexander.jpg";
  };

  # Only act on users that are defined as normal users on this host
  activeUsers = lib.filterAttrs
    (name: _:
      config.users.users ? ${name} &&
      config.users.users.${name}.isNormalUser)
    avatarMap;

in
{
  services.accounts-daemon.enable = true;

  system.activationScripts.user-avatars = {
    text = ''
      mkdir -p /var/lib/sddm-faces
      chmod 755 /var/lib/sddm-faces
      mkdir -p /var/lib/AccountsService/icons /var/lib/AccountsService/users

      ${lib.concatStrings (lib.mapAttrsToList (username: avatarPath:
        let ext  = lib.last (lib.splitString "." (builtins.baseNameOf avatarPath));
            # SDDM FacesDir: looks for ${username}.face.icon (no accountsservice needed)
            sddm = "/var/lib/sddm-faces/${username}.face.icon";
            # AccountsService: for cosmic-greeter, gdm, D-Bus clients
            acct = "/var/lib/AccountsService/icons/${username}.${ext}";
        in ''
        if [ -f "${avatarPath}" ]; then
          cp "${avatarPath}" "${sddm}"
          chmod 644 "${sddm}"
          cp "${avatarPath}" "${acct}"
          chmod 644 "${acct}"
          printf '[User]\nIcon=${acct}\nSystemAccount=false\n' \
            > "/var/lib/AccountsService/users/${username}"
          chmod 644 "/var/lib/AccountsService/users/${username}"
        fi
      '') activeUsers)}
    '';
  };
}
