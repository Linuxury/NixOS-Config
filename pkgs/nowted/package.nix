{ appimageTools, fetchurl, lib }:
# Nowted notes app. Upstream ships only AppImage/deb/rpm; the release URL is
# public and versioned, so bump with scripts/nowted-bump (reads nowted.com/changelog).
let
  pname = "nowted";
  version = "0.2.4";
  src = fetchurl {
    url = "https://updates.nowted.com/releases/${version}/Nowted_${version}_amd64.AppImage";
    hash = "sha256-XyFsDLI79hRoUvtRKVxTSxZQ5O9HS6y1/Iyj+1BcdPY=";
  };
  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # The bundled .desktop already has Exec=nowted and Icon=nowted.
  extraInstallCommands = ''
    install -Dm444 ${contents}/Nowted.desktop $out/share/applications/nowted.desktop
    cp -r ${contents}/usr/share/icons $out/share/icons
  '';

  meta = {
    description = "Private, offline notes app";
    homepage = "https://nowted.com";
    platforms = [ "x86_64-linux" ];
    mainProgram = "nowted";
  };
}
