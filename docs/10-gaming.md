# Gaming

`modules/gaming/gaming.nix` is the whole gaming stack: Steam, gamescope, GameMode, MangoHud, three bundled Proton builds, controller support and the Minecraft launchers. Launch options for each Proton build are in [11-proton-launch-options.md](11-proton-launch-options.md).

## Which hosts have it

The module is imported on every desktop and laptop host. Servers do not import it.

| Host | Gaming | Notes |
|---|---|---|
| ThinkPad | yes | |
| Ryzen5900x | yes | |
| Ryzen5800x | yes | |
| Asus-A15 | yes | Hybrid GPU: the Nvidia side is not configured yet (see below) |
| Alex-Desktop | yes | Child account. Login hours are limited by `modules/users/alex/screen-time.nix` |
| Alex-Laptop | yes | Child account. Same screen-time module |
| Media-Server, MinisForum, Radxa-X4 | no | Headless |

To turn gaming off on a host, remove the import from its host file. See [05-flake-and-modules.md](05-flake-and-modules.md) for how imports work.

## What `gaming.nix` sets up

| Part | What it does |
|---|---|
| Steam | `programs.steam.enable`, Remote Play and dedicated-server firewall ports open. Steam's FHS wrapper gets extra libraries (SDL2, libkrb5, pulse, X11 libs). `extraEnv` hides one keyboard from Steam's controller scan (Lemokey Link, `362d:d030`) |
| Millennium | Steam client mod, on wherever Steam is on (`programs.steam.millennium.enable`, set it to `false` per host to opt out). Settings, plugins, theme and Quick CSS are copied from the `dotfiles` input only when absent, so they stay writable |
| `steam-bpm` | Command that closes desktop Steam, reads the monitor size and refresh rate, and starts Big Picture inside a nested gamescope |
| gamescope | In `systemPackages`, plus `gamescope-wsi` (needed for HDR and frame timing inside games on Wayland) |
| GameMode | `programs.gamemode.enable`. `renice = 10`, soft realtime `auto`, AMD GPU performance level `high` on GPU 0. A polkit rule lets the `gamemode` group use its helpers without a password |
| MangoHud | Package only. Turn it on per game (see below) |
| `dmemcg-booster` | Valve's VRAM cgroup priority daemon (`modules/gaming/dmemcg-booster.nix`, enabled here). It needs a kernel with the `dmemcg` controller: 7.0 or newer |
| Controllers | `modules/gaming/controller.nix`: 8BitDo Ultimate (udev rules), Steam Controller via `sc-controller` and the `hid_steam` and `uinput` modules, Anbernic RG P01 (custom udev rule). `sc-controller` does not autostart: run `systemctl --user start scc-daemon`. The Steam Controller Puck is not handled here; Steam Input covers it |
| Wine tools | `wine-staging`, `winetricks`, `protontricks`, `umu-launcher`, `faugus-launcher`, `steam-run` |
| Vulkan tools | `vulkan-tools`, `mesa-demos`, `vkbasalt` |
| ntsync | Kernel module loaded and `/dev/ntsync` opened to the seat user. Wine and Proton pick it up with no launch option |
| Kernel | `vm.max_map_count` raised so games that need many memory maps start |

### Per-game wrappers

Put these in Steam launch options (Properties, General, Launch Options):

| Goal | Launch option |
|---|---|
| GameMode | `gamemoderun %command%` |
| MangoHud overlay | `MANGOHUD=1 %command%` |
| gamescope at 2560x1440 | `gamescope -W 2560 -H 1440 -- %command%` |

Variables set in Nix never reach a Proton game, because Steam Linux Runtime cleans the environment. Only launch options do. That is why no Proton option is set globally.

## Proton builds

Four Proton builds can run a game.

| Build | Where it comes from | Shown in Steam as |
|---|---|---|
| Valve Proton | Steam downloads it (Proton Experimental, Proton Hotfix, numbered releases) | its own name |
| Proton-GE | Home Manager, from `pkgs/proton-ge-custom` | `GE-Proton (Latest)` |
| Proton-CachyOS | Home Manager, from `pkgs/proton-cachyos` | `Proton-CachyOS (Latest)` |
| Proton-Wineland | Home Manager, from `pkgs/proton-wineland` | `Proton-Wineland (Latest)` |

The three bundled builds are prebuilt releases fetched with `fetchzip` in the overlay in `gaming.nix` and wrapped by `pkgs/proton-*/package.nix`. Home Manager links each one into `~/.local/share/Steam/compatibilitytools.d/` under a fixed folder name: `Proton-GE Latest`, `Proton-CachyOS Latest` and `Proton-Wineland Latest`. The names carry no version, so a per-game choice survives an update. The `display_name` Steam shows comes from each package (the third column above).

Every user on a gaming host gets the same three links. Faugus and other launchers that scan that folder see the same copies and do not download their own.

### Pinned versions

| Build | Pinned release | Upstream |
|---|---|---|
| Proton-GE | `GE-Proton11-12` | github.com/GloriousEggroll/proton-ge-custom |
| Proton-CachyOS | `cachyos-11.0-20261015-slr` | github.com/CachyOS/proton-cachyos |
| Proton-Wineland | `wineland-11.0-20261119` | github.com/nanomatters/proton-salkim (the only source of prebuilt releases) |

The tag, URL and hash lines in `gaming.nix` carry `proton-*-nru`, `-url` and `-hash` markers. `nru` rewrites those lines when it bumps a release, so keep the markers ([07-maintenance.md](07-maintenance.md)).

### What each build is and when to pick it

| Build | What it is | Pick it when |
|---|---|---|
| Valve Proton | Valve's own build. Fewest extras and the build Steam tests games against | A game is on the Steam list as Verified or Playable, or any custom build breaks a game |
| Proton-GE | GloriousEggroll's custom Proton for Steam games. Adds many extra options: HDR, native Wayland, FSR4 and DLSS upgrades, OptiScaler, Nvidia library switches | Valve Proton fails on a game, or you want HDR, Wayland or the upscaler upgrades with the widest option set |
| Proton-CachyOS | CachyOS's custom Proton for Steam games. Turns on the `pipewire` and `fsr4` options by default, and uses the `dxvksarek` DXVK fork by default when the GPU lacks Vulkan 1.3 | You want a performance-tuned build with the CachyOS patches and low-latency DXVK and vkd3d switches |
| Proton-Wineland | CachyOS-based Proton with Wayland improvements. Native Wayland is on by default (`PROTON_ENABLE_WAYLAND` defaults to 1). Has a built-in HUD presets option, a Steam overlay bridge for Wayland and a config file | You play on a Wayland desktop and want the Wineland Wayland work |

"Pick it when" is a starting point. If a game misbehaves, change one build at a time and compare.

### Choose a build in Steam

For one game:

1. Right-click the game, Properties, Compatibility.
2. Tick "Force the use of a specific Steam Play compatibility tool".
3. Pick the build from the list.

For all games: Steam, Settings, Compatibility, "Enable Steam Play for all other titles", then choose the default tool. Restart Steam after a rebuild if a new build does not show in the list.

The per-game choice overrides the default. Switching builds on an existing game keeps its prefix, so a prefix made by one build may need to be reset when a game breaks after a switch.

## Minecraft

`gaming.nix` installs Prism Launcher (Java Edition) and `jdk17`. Prism is wrapped to unset `LD_PRELOAD`, because Steam's overlay hooks the JVM and drops the frame rate. Each user signs in to Prism with their own Mojang account.

For Bedrock it installs BedrockOnLinux from the `bedrock-on-linux` flake input. The game and worlds live in `~/.local/share/bedrock-on-linux`. Run `bedrock-on-linux doctor` to diagnose a problem.

Hytale is a Home Manager module enabled per user: see [09-applications.md](09-applications.md).

## Host notes

### Asus-A15

The hybrid GPU is not finished. `hardware.gpu` is `amd`, and the Nvidia PRIME block in `hosts/Asus-A15/Asus-A15.nix` is commented out until the bus IDs are filled in ([04-first-boot.md](04-first-boot.md)). Until then games run on the AMD GPU only.

### Child-account hosts

Alex-Desktop and Alex-Laptop import `modules/users/alex/screen-time.nix`, which limits login hours with `pam_time` and logs the user out at the cutoff. Games stop when the session ends.
