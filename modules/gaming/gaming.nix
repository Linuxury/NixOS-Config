# ===========================================================================
# modules/gaming/gaming.nix — Gaming stack
#
# Everything needed for Linux gaming: Steam, gamescope, Proton, controller
# support, the Big Picture launcher and Minecraft launcher. It follows
# nixpkgs-unstable so Proton, Mesa and driver updates arrive quickly.
#
# Enable by importing this module on any host where gaming is needed (all
# graphical hosts: linuxury, babylinux and alex machines). Remove the import
# to turn it off. Headless servers do not import it.
# ===========================================================================
{
  inputs,
  config,
  pkgs,
  lib,
  ...
}:
let
  # =========================================================================
  # steam-bpm — Big Picture Mode launcher
  #
  # Shuts down Desktop Mode Steam (if running), detects the active monitor's
  # native resolution and refresh rate, then launches Steam Big Picture Mode
  # wrapped inside a gamescope nested session.
  #
  # Why gamescope here: Steam's BPM uses gamescope --steam internally, which
  # expects to own a display (standalone compositor mode). Wrapping it in our
  # own gamescope runs it nested, as a window inside Hyprland. gamescope flags:
  # -W/-H output size, -w/-h game size, -r refresh rate, -e Steam integration.
  #
  # Trigger: SUPER+CTRL+B keybind → lands on WS 2 via the gamescope window rule.
  # =========================================================================
  steamBpm = pkgs.writeShellScriptBin "steam-bpm" ''
    # Shut down Desktop Mode Steam if it's already running
    if pgrep steam > /dev/null 2>&1; then
      steam -shutdown 2>/dev/null || true
      sleep 2
    fi

    # Detect active monitor's native resolution and refresh rate
    if [ -n "$HYPRLAND_INSTANCE_SIGNATURE" ]; then
      read -r W H R < <(hyprctl monitors -j | python3 -c "
import json, sys
monitors = json.load(sys.stdin)
m = next((m for m in monitors if m['focused']), monitors[0])
print(m['width'], m['height'], round(m['refreshRate']))
")
    else
      read -r W H R < <(xrandr --current | python3 -c "
import sys, re
content = sys.stdin.read()
primary = re.search(r'(\d+)x(\d+)\+0\+0', content)
if primary:
    W, H = primary.group(1), primary.group(2)
    after = content[primary.start():]
    hz = re.search(r'(\d+\.\d+)\*', after)
    if hz:
        print(W, H, round(float(hz.group(1))))
")
    fi

    exec gamescope -W "$W" -H "$H" -w "$W" -h "$H" -r "$R" -e -- steam -gamepadui
  '';

  # =========================================================================
  # prismlauncher — wrapped to strip Steam's overlay injection
  #
  # Steam sets LD_PRELOAD to its gameoverlayrenderer.so (32-bit and 64-bit
  # paths) in the session environment. Prism inherits it when launched from
  # the same session and passes it through to the JVM unchanged; the 32-bit
  # overlay fails to load (ELFCLASS32 on a 64-bit JVM) but the 64-bit one
  # succeeds and hooks a rendering pipeline it was not designed for, which
  # drops Minecraft's frame rate. symlinkJoin + makeWrapper --unset LD_PRELOAD
  # makes Prism start without the inherited variable.
  # =========================================================================
  prismLauncherClean = pkgs.symlinkJoin {
    name = "prismlauncher";
    paths = [ pkgs.prismlauncher ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/prismlauncher --unset LD_PRELOAD
    '';
  };
in
{
  imports = [
    ./dmemcg-booster.nix
    ./controller.nix
    { options.programs.steam.millennium.enable = lib.mkOption {
        type = lib.types.bool;
        default = config.programs.steam.enable; # on wherever Steam is; set false per host to opt out
        description = "Millennium Steam client mod (theme injection)";
      }; }
  ];

  # =========================================================================
  # Gaming-only overlays — scoped here so headless hosts never fetch these
  # source tarballs during evaluation.
  #
  # Three Proton builds, each an inline pkgs.fetchzip (not a flake input) of a
  # prebuilt release, wrapped by a package in ../../pkgs/:
  #   proton-ge-custom  GloriousEggroll's Proton-GE
  #   proton-wineland   Proton Wineland (prebuilt releases come only from
  #                     nanomatters/proton-salkim)
  #   proton-cachyos    CachyOS Proton (nixpkgs has no package for it)
  # The tag/url/hash lines carry "# proton-*-nru/-url/-hash" markers: nru
  # rewrites those lines when it bumps a release, so keep the markers.
  #
  # HDR launch options are per-game, not global: Steam Linux Runtime (the
  # pressure-vessel/bubblewrap container most modern Proton titles run in)
  # sanitizes the sandbox environment, so programs.steam.package.extraEnv never
  # reaches the game — only the per-game launch-options field does.
  #
  # proton-cachyos and proton-ge-custom each have their own PROTON_ADD_CONFIG
  # implementation with a different recognized-key table, so the two are not
  # interchangeable. Unrecognized keys are silently dropped, not an error: check
  # the installed build's source (grep utilities.py / proton for the token) and
  # the actual HDR/monitor state, not just the game's HDR toggle.
  #   - proton-cachyos: _config_envvars maps wow64, dlss, xess, fsr3, fsr4,
  #     ffx3, ffx4, optiscaler; "hdr" and "wayland" are not recognized.
  #   - proton-ge-custom: wider key set including hdr, wayland, fsr4, fsr4rdna3,
  #     wow64, optiscaler, sdlinput. "hdr" only sets DXVK_HDR=1; it does not
  #     imply PROTON_ENABLE_WAYLAND, which is the separate "wayland" key.
  #
  # Working HDR setup with proton-ge-custom (Diablo IV, Umbriel, verified
  # 2026-11-21; HDR and the Steam Controller back paddles both work):
  #   PROTON_ADD_CONFIG=fsr4,fsr4rdna3,wow64,hdr,wayland gamemoderun %command%
  #   - Needs `hdr = "auto"` on the output in umbriel modules/outputs.toml.
  #     With "off" the compositor never advertises HDR and the game's HDR
  #     checkbox stays greyed out, whatever the launch options say.
  #   - Earlier notes said native Wayland (the "wayland" key) breaks the
  #     paddles; that did not hold on this setup.
  # =========================================================================
  nixpkgs.overlays = [
    (final: prev:
    let
      protonCachyosTag = "cachyos-11.0-20261015-slr"; # proton-cachyos-nru
      protonGeTag = "GE-Proton11-12"; # proton-ge-nru
      protonWinelandTag = "wineland-11.0-20261119"; # proton-wineland-nru
    in
    {
      proton-ge-custom = prev.callPackage ../../pkgs/proton-ge-custom/package.nix {
        proton-ge-src = pkgs.fetchzip {
          url  = "https://github.com/GloriousEggroll/proton-ge-custom/releases/download/${protonGeTag}/${protonGeTag}-x86_64.tar.gz"; # proton-ge-url
          hash = "sha256-i20g9lDz7bR0SXWmvHZHztN4m8AHkcD0/OVGSC4ZzI8="; # proton-ge-hash
        };
      };

      # Proton Wineland: prebuilt x86_64 releases are published only by the
      # author's own repo (nanomatters/proton-salkim).
      proton-wineland = prev.callPackage ../../pkgs/proton-wineland/package.nix {
        tag = protonWinelandTag;
        proton-wineland-src = pkgs.fetchzip {
          url  = "https://github.com/nanomatters/proton-salkim/releases/download/${protonWinelandTag}/proton-${protonWinelandTag}-x86_64.tar.xz"; # proton-wineland-url
          hash = "sha256-Mt1wrZR8K6SvZulk3Axw9SPRiCCbiDYvEweCI5fDkPw="; # proton-wineland-hash
        };
      };

      proton-cachyos = prev.callPackage ../../pkgs/proton-cachyos/package.nix {
        tag = protonCachyosTag;
        proton-cachyos-src = pkgs.fetchzip {
          url  = "https://github.com/CachyOS/proton-cachyos/releases/download/${protonCachyosTag}/proton-${protonCachyosTag}-x86_64.tar.xz"; # proton-cachyos-nru
          hash = "sha256-Vb1AvDQLIpgxr3ABPMstM3DFRN1tfUD+6OnhQirMnAQ="; # proton-cachyos-hash
        };
      };
    })
  ];

  # Home Manager modules applied to every user (home-manager.sharedModules):
  #   1. Millennium seed (only where programs.steam.millennium.enable)
  #   2. Proton tool registry: one directory for every launcher. Steam, Faugus,
  #      Heroic and ProtonPlus all scan ~/.local/share/Steam/compatibilitytools.d.
  #      Dir names are fixed "<Name> Latest" so per-game choices survive version
  #      bumps. force = true lets HM replace an existing file at the path; other
  #      entries in the directory are untouched.
  home-manager.sharedModules = [
    # Millennium seed-once (hosts with programs.steam.millennium.enable): copies
    # settings, plugins, theme and Quick CSS from the dotfiles pin, only when
    # absent, because Millennium rewrites config.json and noctalia writes
    # matugen.css into the theme dir, so these must be real writable files.
    # Refresh after changing things in Steam (then push dotfiles + bump the input):
    #   cp ~/.config/millennium/{config.json,quick.css} ~/dotfiles/millennium/
    #   cp -r ~/.local/share/Steam/millennium/themes/QOL-Toggles-Steam ~/dotfiles/millennium/themes/
    # steam-easygrid is deliberately absent: it crashed the UI (React #130).
    ({ lib, ... }: lib.mkIf config.programs.steam.millennium.enable {
      home.activation.millenniumSeed = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        _src="${inputs.dotfiles}/millennium"
        _cfg="$HOME/.config/millennium"
        _pl="$HOME/.local/share/millennium/plugins"
        _th="$HOME/.local/share/Steam/millennium/themes"
        mkdir -p "$_cfg" "$_pl" "$_th"
        [ -f "$_cfg/config.json" ] || cp --no-preserve=mode "$_src/config.json" "$_cfg/"
        for _p in "$_src"/plugins/*; do
          [ -d "$_pl/$(basename "$_p")" ] || cp -r --no-preserve=mode "$_p" "$_pl/"
        done
        for _t in "$_src"/themes/*; do
          [ -d "$_th/$(basename "$_t")" ] || cp -r --no-preserve=mode "$_t" "$_th/"
        done
        # JetBrainsMono via Quick CSS; Millennium creates a comment-only file on
        # first run, so seed unless ours is already in.
        # ponytail: clobbers other hand-added quick.css rules lacking "JetBrains"; keep them in the dotfiles copy.
        grep -q JetBrains "$_cfg/quick.css" 2>/dev/null || cp --no-preserve=mode "$_src/quick.css" "$_cfg/"
      '';
    })
    # HM-side `lib` (has lib.hm), not the NixOS-module lib captured above.
    ({ lib, ... }: {
      # HM can swap a file/symlink but not a real directory ("cannot overwrite
      # directory"). Remove only those three names, and only when they are real
      # dirs, so the links below can be created (entryBefore checkLinkTargets).
      home.activation.protonCompatMigrate = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
        for n in "Proton-GE Latest" "Proton-CachyOS Latest" "Proton-Wineland Latest"; do
          d="$HOME/.local/share/Steam/compatibilitytools.d/$n"
          if [ -d "$d" ] && [ ! -L "$d" ]; then
            chmod -R u+w "$d" 2>/dev/null || true
            rm -rf "$d"
          fi
        done
      '';

      home.file = lib.mapAttrs' (name: pkg:
        lib.nameValuePair ".local/share/Steam/compatibilitytools.d/${name}" {
          source = pkg;
          force = true;
        }) {
        "Proton-GE Latest" = pkgs.proton-ge-custom;
        "Proton-CachyOS Latest" = pkgs.proton-cachyos;
        "Proton-Wineland Latest" = pkgs.proton-wineland;
      };
    })
  ];

  # VRAM cgroup priority daemon (modules/gaming/dmemcg-booster.nix).
  services.dmemcg-booster.enable = true;

  # =========================================================================
  # Steam
  #
  # Steam needs special handling in NixOS because it's a 32-bit app that
  # manages its own runtime. The NixOS Steam module handles all of this
  # cleanly — don't try to just add steam to systemPackages.
  # =========================================================================
  programs.steam = {
    enable = true;

    # Other programs.steam options: gamescopeSession.enable (boot into a Big
    # Picture session), localNetworkGameTransfers.openFirewall, extraCompatPackages,
    # extest.enable, protontricks.enable.
    #
    # Opens firewall ports for Steam Remote Play and In-Home Streaming
    remotePlay.openFirewall = true;

    # Opens firewall ports for Steam's game server browser
    dedicatedServer.openFirewall = true;

    # No extraCompatPackages: it only reaches Steam. Proton tools are linked
    # into ~/.local/share/Steam/compatibilitytools.d instead (home-manager
    # sharedModules above) so Faugus and other launchers see the same copy and
    # don't download their own.

    # package: Steam's FHS wrapper, extended with extra libraries (extraPkgs)
    # so Steam's own runtime libraries work on NixOS's non-standard filesystem
    # layout; extraEnv sets environment variables inside that wrapper.
    #
    # Millennium: upstream's steam.nix wraps steam with its loader libs.
    # callPackage'd with this repo's pkgs so the FHS env tracks our nixpkgs; only
    # the millennium lib comes from its pin. Turning Millennium off leaves
    # dangling ubuntu12_{32,64}/libXtst.so.6 symlinks in ~/.local/share/Steam;
    # delete them and Steam restores its own.
    package = (if config.programs.steam.millennium.enable
      then pkgs.callPackage "${inputs.millennium}/steam.nix" {
        inherit (inputs.millennium.packages.${pkgs.stdenv.hostPlatform.system}) millennium;
      }
      else pkgs.steam).override {
      extraPkgs = steamPkgs:
        with steamPkgs; [
          alsa-lib
          libxcursor
          libxi
          libxinerama
          libxscrnsaver
          libpng
          libpulseaudio
          libvorbis
          libglvnd
          stdenv.cc.cc.lib
          libkrb5
          keyutils
          SDL2
        ];

      # Lemokey Link keyboard (362d:d030) exposes a HID interface that
      # Steam's controller scanner misreads as a gamepad, showing up as
      # "Lemokey Link — Begin Setup" on the Controller page. Both SDL
      # hints are needed: GAMECONTROLLER_IGNORE_DEVICES for the classic
      # SDL_GameController scan, HIDAPI_IGNORE_DEVICES for Steam's own
      # hidraw-based controller scan (what populates that page).
      #
      # PROTON_ADD_CONFIG is not set here: it does not reach games run inside
      # Steam Linux Runtime's container (see the HDR comment in the overlays
      # block). Set it per-game in Steam launch options instead.
      extraEnv = {
        SDL_GAMECONTROLLER_IGNORE_DEVICES = "0x362d/0xd030";
        SDL_HIDAPI_IGNORE_DEVICES = "0x362d/0xd030";
      };
    };
  };

  # =========================================================================
  # GameMode — Performance optimizer (programs.gamemode below: enable,
  # settings.general, settings.gpu; the polkit rule lets group "gamemode" use
  # the helper binaries without a password)
  #
  # GameMode is a daemon that temporarily optimizes system performance
  # when a game starts. It does things like:
  #   - Switch CPU governor to performance mode
  #   - Increase process priority for the game
  #   - Disable power saving features temporarily
  #
  # Games can request it automatically, or you can launch with:
  #   gamemoderun <game>
  # Steam launch options: gamemoderun %command%
  # =========================================================================
  # GameMode polkit rule — allow members of the "gamemode" group to run
  # gamemoded's helper binaries (cpugovctl, gpuclockctl, cpucorectl,
  # procsysctl) without a password prompt.
  #
  # On NixOS the gamemode package can end up at two different store paths
  # (one for the system polkit actions, one for the user service closure).
  # When the binary path doesn't match the annotation in the .policy file,
  # polkit falls back to the generic org.freedesktop.policykit.exec action
  # instead of com.feralinteractive.GameMode.*. Matching by helper name
  # (not store path) avoids this hash-mismatch problem.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      var helpers = ["cpugovctl", "gpuclockctl", "cpucorectl", "procsysctl"];
      if (action.id === "org.freedesktop.policykit.exec" &&
          subject.isInGroup("gamemode")) {
        var prog = action.lookup("program") || "";
        for (var i = 0; i < helpers.length; i++) {
          if (prog.indexOf(helpers[i]) !== -1) {
            return polkit.Result.YES;
          }
        }
      }
    });
  '';

  programs.gamemode = {
    enable = true;
    settings = {
      general = {
        renice = 10; # Boost game process priority
        softrealtime = "auto"; # Enable soft realtime scheduling if possible
      };
      gpu = {
        apply_gpu_optimisations = "accept-responsibility";
        gpu_device = 0; # Primary GPU (change to 1 for secondary)
        amd_performance_level = "high"; # AMD GPU performance mode during gaming
      };
    };
  };

  # =========================================================================
  # MangoHud — In-game performance overlay
  #
  # Shows FPS, GPU/CPU usage, temperatures, and frame times as an
  # overlay inside games. Very useful for monitoring performance.
  #
  # Enable per game in Steam launch options with:
  #   MANGOHUD=1 %command%
  # Or from a shell with: mangohud <game>
  # There is no NixOS programs.mangohud option; the mangohud package is in
  # systemPackages below, and its config file is linked by the user's home
  # config (~/.config/MangoHud).
  # =========================================================================

  # =========================================================================
  # Gaming packages
  # =========================================================================
  environment.systemPackages = with pkgs; [
    # -----------------------------------------------------------------------
    # Launchers — for games outside of Steam
    # -----------------------------------------------------------------------
    # lutris — universal game launcher with community install scripts; not
    # installed (unused; its FHS env pulls a broken gtk2).
    faugus-launcher # Lightweight launcher for Windows games via UMU/Proton

    # -----------------------------------------------------------------------
    # Proton / Wine — Windows game compatibility layers
    # -----------------------------------------------------------------------
    wine-staging # Latest Wine with extra patches for better compatibility
    winetricks # Installs Windows libraries/runtimes needed by some games
    protontricks # Winetricks wrapper for Steam/Proton — handles the Proton
    # runtime paths automatically so you don't have to

    # -----------------------------------------------------------------------
    # Gamescope — Valve's gaming microcompositor
    #
    # Runs games in a nested compositor session. Lets you:
    #   - Force a game to render at a lower resolution and upscale
    #   - Cap framerate independently per game
    #   - Enable HDR output on supported displays
    #
    # Steam launch option: gamescope -W 2560 -H 1440 -- %command%
    # -----------------------------------------------------------------------
    gamescope

    # -----------------------------------------------------------------------
    # Utilities
    # -----------------------------------------------------------------------
    gamemode # CLI access to GameMode (already enabled above)
    mangohud # CLI access to MangoHud (already enabled above)
    sgdboop # SteamGridDB asset manager — apply custom banners/icons
    # to Steam games from SteamGridDB with one click

    vulkan-tools # vulkaninfo — useful for checking Vulkan is working
    mesa-demos # glxinfo, glxgears — check OpenGL info and verify drivers

    # -----------------------------------------------------------------------
    # Graphics compatibility / post-processing
    # -----------------------------------------------------------------------
    vkbasalt # Vulkan post-processing layer — FSR1, CAS sharpening, SMAA,
    # FXAA applied to any Vulkan game without touching launch options.

    gamescope-wsi # Vulkan WSI layer that ships separately from the gamescope
    # binary. Required for gamescope HDR and frame-timing features to work
    # inside running games on Wayland.

    # -----------------------------------------------------------------------
    # Launchers — non-Steam storefronts
    # -----------------------------------------------------------------------
    # heroic — Epic Games + GOG launcher (wraps Proton/Wine, uses UMU
    # internally); not installed.

    umu-launcher # Valve's universal compatibility tool (umu-run <exe>).
    # Faugus-launcher pulls this in transitively, but having it explicitly
    # lets you run any non-Steam EXE with Proton from the CLI.

    steam-run # Run arbitrary Linux binaries inside Steam's FHS sandbox.
    # Some game launchers and tools require a standard FHS layout which
    # NixOS doesn't provide by default — this wraps any binary cleanly.

    # Steam Big Picture Mode launcher (gamescope-wrapped, see let block above)
    steamBpm

    # -----------------------------------------------------------------------
    # Minecraft — Java Edition (Prism) and Bedrock (BedrockOnLinux)
    # -----------------------------------------------------------------------
    prismLauncherClean # Java Minecraft launcher, wrapped to unset LD_PRELOAD
    # (strips Steam's overlay injection — see let-block comment above)
    # Each user signs in with their own Mojang account in Prism
    jdk17 # Java 17 runtime — required for Minecraft 1.17 and newer
    # Prism manages older Java versions internally for legacy versions
    inputs.bedrock-on-linux.packages.${pkgs.stdenv.hostPlatform.system}.default
    # BedrockOnLinux — Minecraft Bedrock (Windows/GDK) through Wine. The flake
    # input follows this repo's nixpkgs so its steam-run/Mesa match the GPU
    # driver. Game + worlds live in ~/.local/share/bedrock-on-linux;
    # `bedrock-on-linux doctor` diagnoses problems.
    #
    # Alternative for Bedrock: the Flatpak io.mrarm.mcpelauncher (bundles its own
    # libraries; the nixpkgs mcpelauncher conflicts with NixOS's non-FHS library
    # paths). Install with: flatpak install flathub io.mrarm.mcpelauncher
    # (Flathub is configured by the system/graphical/graphical.nix activation script.)
  ];

  # =========================================================================
  # ntsync — NT synchronization primitives (kernel 6.14+)
  #
  # boot.kernelModules loads the module; the udev rule below tags /dev/ntsync
  # "uaccess" so the logged-in seat user (non-root) can use it.
  # Wine-staging and Proton-GE pick this up automatically for much lower
  # CPU overhead on synchronization-heavy Windows games.
  # No Steam launch option needed — Wine/Proton auto-detects it.
  # =========================================================================
  # pressure-vessel (Valve's container runtime used by umu-launcher / Faugus)
  # probes bubblewrap by exec-ing `true`. On NixOS /bin/true doesn't exist —
  # this activation script (after "users") creates a symlink to coreutils' true,
  # which satisfies the probe without touching the global FHS compat layer.
  system.activationScripts.bwrapBinTrue = lib.stringAfter [ "users" ] ''
    mkdir -p /bin
    [ -e /bin/true ] || ln -sf ${pkgs.coreutils}/bin/true /bin/true
  '';

  boot.kernelModules = [ "ntsync" ];
  services.udev.extraRules = ''
    KERNEL=="ntsync", TAG+="uaccess"
  '';

  # =========================================================================
  # Kernel parameters for better gaming performance
  #
  # vm.max_map_count raises the per-process memory-map limit; some games
  # fail to start or crash when it is too low.
  # =========================================================================
  boot.kernel.sysctl = {
    # Maximum memory map areas per process; some games (notably DOTA 2) need
    # a high value
    "vm.max_map_count" = 2147483642;
  };
}
