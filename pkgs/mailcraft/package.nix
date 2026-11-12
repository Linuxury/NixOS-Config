{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  dbus,
  libglvnd,
  libxkbcommon,
  vulkan-loader,
  wayland,
  libx11,
  libxcb,
  libxcursor,
  libxi,
}:
# MailCraft (https://mailcraft.work/personal), MIT, straight from the upstream
# GitHub release tarball. No repack: binaries are patched for Nix store paths only.
#
# version + hash live in mailcraft.json, rewritten by scripts/mailcraft-bump
# (run by nru on the lock writer). Do not edit them by hand.
let
  pin = builtins.fromJSON (builtins.readFile ./mailcraft.json);
in
stdenv.mkDerivation {
  pname = "mailcraft";
  inherit (pin) version;

  src = fetchurl {
    url = "https://github.com/UCS-Care-Group/mailcraft/releases/download/v${pin.version}/mailcraft-${pin.version}-linux-x86_64.tar.gz";
    inherit (pin) hash;
  };

  nativeBuildInputs = [ autoPatchelfHook ];
  buildInputs = [ stdenv.cc.cc.lib ];

  # dlopen'd at runtime (winit/wgpu/dbus), invisible to autoPatchelf's link scan.
  runtimeDependencies = [
    dbus libglvnd libxkbcommon vulkan-loader wayland
    libx11 libxcb libxcursor libxi
  ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -a bin share $out/
    runHook postInstall
  '';

  meta = {
    description = "Desktop mail, calendar, contacts and tasks client";
    homepage = "https://mailcraft.work/personal/";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "mailcraft";
  };
}
