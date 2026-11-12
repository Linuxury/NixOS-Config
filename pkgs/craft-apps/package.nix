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
    photocraft  = { version = "0.23.0"; hash = "sha256-mFjuI0hU98OQ8+q0c0rqUxAMyRLCyNzqoClCe3XdIvg="; description = "Image editor"; };
    pdfcraft    = { version = "0.21.0"; hash = "sha256-eajHbiOtbmcd47hWpHaTavwAD4qn/v/xkNQ95i+jW6E="; description = "PDF workbench"; };
    lightcraft  = { version = "0.21.0"; hash = "sha256-fn2lU96hACaKBY8TXHxK0fT7drTYJC4U9w8W7YkllYA="; description = "Photo library and raw developer"; };
    vectorcraft = { version = "0.24.0"; hash = "sha256-nGFxygB6b4NcNotZL+nukMmF1lBX7cnc0rxMTvxQrSs="; description = "Vector illustration"; };
    filmcraft   = { version = "0.20.0"; hash = "sha256-NUZdcb3hifUMrK8+T9icTKY3f6+OtI6qLwZbjlRZMjY="; description = "Video editor"; };
    effectcraft = { version = "0.24.0"; hash = "sha256-l7Ws6bjL44qF/k7dAuR+vfQnKTML0oC6IHTAiblrUCI="; description = "Motion graphics and VFX"; };
    designcraft = { version = "0.20.0"; hash = "sha256-b3IQO2+iPct3vteUt6MBGJoqd6SMtjBadtvTMWmm6N4="; description = "Page layout and publishing"; };
    wordcraft   = { version = "0.18.0"; hash = "sha256-8paT5gNt6UFWzvQrzb1kR4oa7C85akwqFaf3JT51kiY="; description = "Word processor"; };
    gridcraft   = { version = "0.19.0"; hash = "sha256-47HPSpJuKvp+isIukIt833uvYQO7RE+Za/oLw9iJrbY="; description = "Spreadsheet"; };
    deckcraft   = { version = "0.18.0"; hash = "sha256-0fEpr4wS8SULzBfbzbqsOAkAyROByEpK2m7ntICk2wY="; description = "Presentations"; };
    soundcraft  = { version = "0.20.0"; hash = "sha256-zoR0Rz4+f+sidq8E/yBzLtY5EFXxiJE3eYNPUU7hpkg="; description = "Digital audio workstation"; };
    cadcraft    = { version = "0.20.0"; hash = "sha256-UAWDN6wl9UL87yyDQxg1dtDEIKocfdYjEQvtiZ4sSOk="; description = "CAD and drafting"; };
    figcraft    = { version = "0.18.0"; hash = "sha256-jHZKpXlYqkY0w/0taHk6f4jQsyZtH0pIe3inB607JRM="; description = "Interface design and prototyping"; };
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
