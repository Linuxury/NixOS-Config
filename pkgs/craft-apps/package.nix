{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  alsa-lib,
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
    photocraft  = { version = "0.22.0"; hash = "sha256-7t6vpGdd+9HyNR5r+kuC9URTaU6zbaG71cqLv19U8gI="; description = "Image editor"; };
    pdfcraft    = { version = "0.20.0"; hash = "sha256-Gg8px6auBJFhJiMdhDsuqDaiG42wny70FpUQFaQ36Lw="; description = "PDF workbench"; };
    lightcraft  = { version = "0.20.0"; hash = "sha256-jLXu2CWy3Z4PpCaAEp0+WqcY8HGW1nzF0FdB8OapzCU="; description = "Photo library and raw developer"; };
    vectorcraft = { version = "0.23.0"; hash = "sha256-B8JKYJT7RXxmW5WEjVW/vQVGA1S8DqybTsn5RnqLHjE="; description = "Vector illustration"; };
    filmcraft   = { version = "0.19.0"; hash = "sha256-dhSTQ8GXALpqyQX96KAZ4JF9BlB/QmpZODltl6HKISQ="; description = "Video editor"; };
    effectcraft = { version = "0.23.0"; hash = "sha256-E9mrI7db57inF3XMlALg+DIoCxZhR0ZyglV+nGoh09I="; description = "Motion graphics and VFX"; };
    designcraft = { version = "0.19.0"; hash = "sha256-UFVTH+n2Dk2mETdw/s8n37A5hPgx+k7XBzC+FWoxaGY="; description = "Page layout and publishing"; };
    wordcraft   = { version = "0.17.0"; hash = "sha256-nHRMDDGjziXfgmgPx15kXWgoRvrMvhA/T5GnWLGfNoc="; description = "Word processor"; };
    gridcraft   = { version = "0.18.0"; hash = "sha256-aSBf1y5I6D52PFPI9so+3AHTi6i6DRbisYSpyFikzV8="; description = "Spreadsheet"; };
    deckcraft   = { version = "0.17.0"; hash = "sha256-phoFCVpSqAmQqomQtEcQBVPpnI+m7ch1SqUnQKGm+bA="; description = "Presentations"; };
    soundcraft  = { version = "0.19.0"; hash = "sha256-iaKb9Iwpnu5ZPXzWhLIchIPKKHq8GWZXrj+Vmh68GK0="; description = "Digital audio workstation"; };
    cadcraft    = { version = "0.19.0"; hash = "sha256-plTfjD5EfGLEkMCoqtjEKp+vqwEMpNJbw1BO1Fs8j1E="; description = "CAD and drafting"; };
    figcraft    = { version = "0.17.0"; hash = "sha256-68i/pNoCaGDP+CHSAk1vUXBKxpR4lp9bKWEdu5am5GQ="; description = "Interface design and prototyping"; };
    texturecraft = { version = "0.5.0"; hash = "sha256-DVZP4n1iCFAhKpB3EfMHoAd+fUcdIneSRDHV6R1Au18="; description = "Procedural texture designer"; };
    materialcraft = { version = "0.3.0"; hash = "sha256-0UOdHwc+K6zY4YoSPXuMJMDEF0ORmzzK4yqTIYP3YoU="; description = "Material and shader authoring"; };
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
    runtimeDependencies = [ libGL libxkbcommon vulkan-loader wayland libx11 libxcursor libxi libxrandr ];

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
