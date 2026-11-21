# ponytrail — prebuilt Bun CLI bundle plus its agent skill files. Exposed as
# pkgs.ponytrail by the overlay in flake.nix; installed and wired up by
# modules/development/ai-tools/claude.nix (remove it there).
# Bump: change version + hash below.
{
  lib,
  stdenv,
  fetchurl,
  makeBinaryWrapper,
  bun,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "ponytrail";
  version = "0.0.1-beta.0";

  src = fetchurl {
    url = "https://registry.npmjs.org/ponytrail/-/ponytrail-${finalAttrs.version}.tgz";
    hash = "sha256-jYVJtwy8FUA3RgXieeKwZbhMevbVTsJHltOeqyJX+F8=";
  };

  nativeBuildInputs = [ makeBinaryWrapper ];

  unpackPhase = ''
    tar -xzf $src
  '';

  installPhase = ''
    # CLI — Bun-compiled bundle, needs bun at runtime
    install -Dm644 package/dist/cli.js $out/lib/ponytrail/dist/cli.js
    makeWrapper ${bun}/bin/bun $out/bin/ponytrail \
      --add-flags "$out/lib/ponytrail/dist/cli.js"

    # Bundled agent skill files — installed into the agent's skills dir
    # by modules/development/ai-tools/claude.nix
    mkdir -p $out/share/ponytrail/skills
    cp -r package/bundled-skills/pony-trail $out/share/ponytrail/skills/pony-trail
  '';

  meta = {
    description = "CLI for recording why files changed — local snapshot history and revert for AI coding sessions";
    homepage = "https://github.com/0xroylee/ponytrail";
    license = lib.licenses.unfree;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
    mainProgram = "ponytrail";
  };
})
