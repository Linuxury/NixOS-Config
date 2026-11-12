{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  alsa-lib,
  dbus,
  libGL,
  libx11,
  libxcursor,
  libxi,
  libxrandr,
  libxkbcommon,
  vulkan-loader,
  wayland,
}:
# storytold Craft apps (https://getartcraft.com/apps) — prebuilt Linux release tarballs.
#
# Returns an attrset of derivations (pkgs.craft-apps.photocraft, …).
# Each tarball is a plain FHS tree (bin/, share/{applications,icons,mime,metainfo}),
# so copying it to $out gives the menu entry, icons and file associations.
#
# nru bumps these on Ryzen5900x (_nru_update_craft_apps in the ZSH repo).
# Manual bump: edit version + hash below. Hashes come from upstream's SHA256SUMS.txt:
#   curl -sL https://github.com/storytold/<app>/releases/download/v<ver>/SHA256SUMS.txt \
#     | grep linux-x86_64.tar.gz   # then: nix hash convert --hash-algo sha256 --to sri <hex>
#
# Drop an app from here once it lands in nixpkgs.
let
  apps = {
    photocraft  = { version = "0.23.1"; hash = "sha256-Q4Ou9noHzDcK0lCm7WABUgXT5sRj+vP/Sw9nuBeMz8g="; description = "Image editor"; };
    pdfcraft    = { version = "0.21.1"; hash = "sha256-wpGekETv/eMY5mgHrSohu7dKlVWzwLmfmtDEDPYc4l4="; description = "PDF workbench"; };
    lightcraft  = { version = "0.21.1"; hash = "sha256-sSPeFpFYCaeeZLpO467p4c3tbvI7c3wG+Bzcfi8obWI="; description = "Photo library and raw developer"; };
    vectorcraft = { version = "0.24.1"; hash = "sha256-oJBRQlL94UVJWsb8Zdb/ExHWmJmOV7pDTV0IlsPR+/o="; description = "Vector illustration"; };
    filmcraft   = { version = "0.20.1"; hash = "sha256-Pk/qPLjUc+aPGJoKh5K6RhYPq1B62rOriSAHP9QfJPo="; description = "Video editor"; };
    effectcraft = { version = "0.24.1"; hash = "sha256-XOA5NpAUQif6kYboIwitY4pu9tn5dsmW5tA7W1G2Wns="; description = "Motion graphics and VFX"; };
    designcraft = { version = "0.20.1"; hash = "sha256-6RYw1M31eMyx4vOfiOJOhSDxSC1RrkcUZX7kceIjf0Q="; description = "Page layout and publishing"; };
    wordcraft   = { version = "0.18.1"; hash = "sha256-MSoFfUbdgFl8EtzP0Ql84l7epAuqrrULy28BrBrrrbU="; description = "Word processor"; };
    gridcraft   = { version = "0.19.1"; hash = "sha256-jZe7otW7AP1p7VUGSFLB/ZFN5A1ezVXKAcjfgbgolG0="; description = "Spreadsheet"; };
    deckcraft   = { version = "0.18.1"; hash = "sha256-W659VWZjhiRBHvlo8lMqszWNwoCIQURYPkl8VjHbiiY="; description = "Presentations"; };
    soundcraft  = { version = "0.20.1"; hash = "sha256-yu/PhcTxE4cX1ZLTHOW+B/L8phbsNtY/rGdgze++KKk="; description = "Digital audio workstation"; };
    cadcraft    = { version = "0.20.1"; hash = "sha256-V7bxtBtPPFQqgvEDIC7Rp3lEDl/40lwI72ar2hqMsbk="; description = "CAD and drafting"; };
    figcraft    = { version = "0.18.1"; hash = "sha256-gnbSrFXG939686QRqbAEFdP+sLWWB6VFIzETQOZT/Bk="; description = "Interface design and prototyping"; };
    texturecraft = { version = "0.6.1"; hash = "sha256-4X0Uoeu59hHaRhcIwpiIdQ+YL91/DNEeFpDsSoQGhgA="; description = "Procedural texture designer"; };
    materialcraft = { version = "0.4.1"; hash = "sha256-QxFfjT4v7o+fKbwHsDyYTC6PbQTg4ZWUOdc+xc32gw4="; description = "Material and shader authoring"; };
    anicraft    = { version = "0.2.1"; hash = "sha256-o6h5W9aupLS8XKDybCJqByMw04/pP07fVSY2Dr9xVv0="; description = "2D vector animation studio"; };
  };

  mk = pname: app: stdenv.mkDerivation {
    inherit pname;
    inherit (app) version;

    src = fetchurl {
      url = "https://github.com/storytold/${pname}/releases/download/v${app.version}/${pname}-${app.version}-linux-x86_64.tar.gz";
      inherit (app) hash;
    };

    nativeBuildInputs = [ autoPatchelfHook ];
    buildInputs = [ stdenv.cc.cc.lib alsa-lib ];

    # dlopen'd at runtime, invisible to autoPatchelf's link scan. X11 libs: DesignCraft
    # forces winit's X11 backend (file drag-and-drop), so it runs under XWayland.
    # dbus.lib (the library lives in the `lib` output, not `out`): rfd dlopens
    # libdbus-1.so for the xdg file-chooser portal; without it
    # "Open" silently does nothing (falls back to zenity, which isn't installed).
    runtimeDependencies = [ libGL libxkbcommon vulkan-loader wayland libx11 libxcursor libxi libxrandr dbus.lib ];

    installPhase = ''
      runHook preInstall
      cp -r . "$out"
      runHook postInstall
    '';

    # Nothing is compiled here — untar a prebuilt tree, then autoPatchelf it.
    # Without this, a remote builder gets picked and the transfer dwarfs the
    # work: ~60-106 MB tarball up, ~127-195 MB output back, per app, times 13.
    # On a wifi host (ThinkPad) that turned a seconds-long unpack into minutes.
    preferLocalBuild = true;

    meta = {
      description = "${app.description} (storytold Craft app)";
      homepage = "https://github.com/storytold/${pname}";
      license = lib.licenses.asl20;
      platforms = [ "x86_64-linux" ];
      mainProgram = pname;
    };
  };
in
lib.mapAttrs mk apps
