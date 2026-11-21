# ===========================================================================
# modules/users/uids.nix — fixed UID per person, identical on every host
#
# Plain attrset { <username> = <uid>; } imported (not a module) by
# modules/users/uid-pin, which sets users.users.<name>.uid from it, and read by
# the installer. Without pins NixOS assigns UIDs alphabetically per host
# (alex < babylinux < linuxury), so one person could differ between machines.
# To add a person: add a line here; to change a UID, see uid-pin.nix (existing
# home directories need a migration).
# ===========================================================================
{
  linuxury  = 1000;
  babylinux = 1001;
  alex      = 1002;
}
