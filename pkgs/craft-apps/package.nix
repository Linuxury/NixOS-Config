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
    photocraft  = { version = "0.22.0"; hash = "sha256-7t6vpGdd+9HyNR5r+kuC9URTaU6zbaG71cqLv19U8gI="; description = "Image editor"; };
    pdfcraft    = { version = "0.21.0"; hash = "sha256-eajHbiOtbmcd47hWpHaTavwAD4qn/v/xkNQ95i+jW6E="; description = "PDF workbench"; };
    lightcraft  = { version = "0.20.0"; hash = "sha256-jLXu2CWy3Z4PpCaAEp0+WqcY8HGW1nzF0FdB8OapzCU="; description = "Photo library and raw developer"; };
    vectorcraft = { version = "0.23.0"; hash = "sha256-B8JKYJT7RXxmW5WEjVW/vQVGA1S8DqybTsn5RnqLHjE="; description = "Vector illustration"; };
    filmcraft   = { version = "0.20.0"; hash = "sha256-NUZdcb3hifUMrK8+T9icTKY3f6+OtI6qLwZbjlRZMjY="; description = "Video editor"; };
    effectcraft = { version = "0.24.0"; hash = "sha256-l7Ws6bjL44qF/k7dAuR+vfQnKTML0oC6IHTAiblrUCI="; description = "Motion graphics and VFX"; };
    designcraft = { version = "0.20.0"; hash = "sha256-b3IQO2+iPct3vteUt6MBGJoqd6SMtjBadtvTMWmm6N4="; description = "Page layout and publishing"; };
    wordcraft   = { version = "0.17.0"; hash = "sha256-nHRMDDGjziXfgmgPx15kXWgoRvrMvhA/T5GnWLGfNoc="; description = "Word processor"; };
    gridcraft   = { version = "0.19.0"; hash = "sha256-47HPSpJuKvp+isIukIt833uvYQO7RE+Za/oLw9iJrbY="; description = "Spreadsheet"; };
    deckcraft   = { version = "0.18.0"; hash = "sha256-0fEpr4wS8SULzBfbzbqsOAkAyROByEpK2m7ntICk2wY="; description = "Presentations"; };
    soundcraft  = { version = "0.19.0"; hash = "sha256-iaKb9Iwpnu5ZPXzWhLIchIPKKHq8GWZXrj+Vmh68GK0="; description = "Digital audio workstation"; };
    cadcraft    = { version = "0.20.0"; hash = "sha256-UAWDN6wl9UL87yyDQxg1dtDEIKocfdYjEQvtiZ4sSOk="; description = "CAD and drafting"; };
    figcraft    = { version = "0.17.0"; hash = "sha256-68i/pNoCaGDP+CHSAk1vUXBKxpR4lp9bKWEdu5am5GQ="; description = "Interface design and prototyping"; };
    texturecraft = { version = "0.6.0"; hash = "sha256-kxhlhG6mqCArs8JYl75h4K+vjtMmTCaNXVutqXP9dy4="; description = "Procedural texture designer"; };
    materialcraft = { version = "0.4.0"; hash = "sha256-rGp0I4apLErb0UUtVTDwwkSQeP3J4HAzPoM+bSvfjPc="; description = "Material and shader authoring"; };
    anicraft    = { version = "0.2.0"; hash = "sha256-/fGVjqSF/Kbliz704/WRc+1MCdTKAFZ7aSRM2TzMgcs="; description = "2D vector animation studio"; };
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
