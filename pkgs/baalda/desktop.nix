{
  lib,
  stdenv,
  fetchurl,
  dpkg,
  autoPatchelfHook,
  wrapGAppsHook3,
  webkitgtk_4_1,
  gtk3,
  glib,
  libsoup_3,
  openssl,
  dbus,
  librsvg,
  gdk-pixbuf,
  cairo,
  pango,
  libayatana-appindicator,
}:
# Baalda desktop (https://github.com/naveedharri/baalda), straight from the upstream
# .deb: one Tauri binary, patched for Nix store paths only.
#
# version + hash live in baalda.json, shared with the server module and rewritten
# by scripts/baalda-bump (run by nru on the lock writer). Do not edit them by hand.
let
  pin = builtins.fromJSON (builtins.readFile ./baalda.json);
in
stdenv.mkDerivation {
  pname = "baalda";
  inherit (pin) version;

  src = fetchurl {
    url = "https://github.com/naveedharri/baalda/releases/download/v${pin.version}/Baalda_${pin.version}_amd64.deb";
    inherit (pin) hash;
  };

  nativeBuildInputs = [ dpkg autoPatchelfHook wrapGAppsHook3 ];
  buildInputs = [
    webkitgtk_4_1 gtk3 glib libsoup_3 openssl dbus librsvg gdk-pixbuf cairo pango
    libayatana-appindicator stdenv.cc.cc.lib
  ];

  unpackPhase = "dpkg-deb -x $src .";

  # Upstream names the binary and icons "desktop"; rename so PATH and the icon theme stay clean.
  installPhase = ''
    runHook preInstall
    install -Dm755 usr/bin/desktop $out/bin/baalda
    cp -r usr/share $out/share
    for f in $out/share/icons/hicolor/*/apps/desktop.png; do
      mv "$f" "$(dirname "$f")/baalda.png"
    done
    substituteInPlace $out/share/applications/Baalda.desktop \
      --replace-fail 'Exec=desktop' 'Exec=baalda' \
      --replace-fail 'Icon=desktop' 'Icon=baalda' \
      --replace-fail 'StartupWMClass=desktop' 'StartupWMClass=baalda'
    runHook postInstall
  '';

  meta = {
    description = "Local-first Markdown notes app with CRDT sync";
    homepage = "https://github.com/naveedharri/baalda";
    license = lib.licenses.asl20; # core; upstream's ee/ directory has its own license
    platforms = [ "x86_64-linux" ];
    mainProgram = "baalda";
  };
}
