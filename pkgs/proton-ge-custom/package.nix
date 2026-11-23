{ lib, stdenvNoCC, tag, proton-ge-src }:
# GE-Proton prebuilt for Steam's compatibility tools.
#
# This file never needs to be edited. The version is the release tag passed in
# from modules/gaming/gaming.nix, where the URL and hash also live —
# nru updates them automatically via _nru_update_proton_ge.
stdenvNoCC.mkDerivation rec {
  pname = "proton-ge-custom";
  # The tag, e.g. "GE-Proton11-14". Not read from the tarball's version file:
  # that would be import-from-derivation (570 MB download during eval).
  version = tag;

  src = proton-ge-src;

  # Prebuilt binary — skip all NixOS fixup steps.
  # GE-Proton ships bundled libraries and runs inside Steam's
  # pressure-vessel container; patchelf/strip would break it.
  dontBuild   = true;
  dontStrip   = true;
  dontFixup   = true;

  installPhase = ''
    cp -r . "$out"

    # Patch compatibilitytool.vdf with static names so Steam games never need
    # reassigning when the version updates. Steam stores the VDF key as the
    # internal tool identifier — keeping it fixed across releases means all
    # per-game assignments survive nru updates automatically.
    chmod +w "$out/compatibilitytool.vdf"
    sed -i \
      -e 's|"[^"]*" // Internal|"proton_ge_latest" // Internal|' \
      -e 's|"display_name" "[^"]*"|"display_name" "GE-Proton (Latest)"|' \
      "$out/compatibilitytool.vdf"

    # GE-Proton11-1 ships with require_tool_appid "4185400" (arm64 SteamRT4).
    # umu-launcher maps 4185400 → steamrt4-arm64 (aarch64), which can't run on
    # x86_64. The correct appid for x86_64 SteamRT4 is 4183110.
    chmod +w "$out/toolmanifest.vdf"
    sed -i 's|"require_tool_appid" "4185400"|"require_tool_appid" "4183110"|' \
      "$out/toolmanifest.vdf"
  '';

  meta = with lib; {
    description = "GloriousEggroll's custom Proton build for Steam games";
    homepage    = "https://github.com/GloriousEggroll/proton-ge-custom";
    platforms   = [ "x86_64-linux" ];
    license     = licenses.unfreeRedistributable;
  };
}
