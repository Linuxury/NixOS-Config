# Proton launch options

Launch options per Proton build. Each option below says which build reads it. The lists come from each build's own launcher script (`proton` and its `*.py` helpers), not from upstream documentation. Builds and how to pick one: [10-gaming.md](10-gaming.md).

An option missing from a build's list may still be read by that build's Wine, DXVK or vkd3d-proton. This doc lists what the launcher script handles. Names that are internal plumbing (`STEAM_COMPAT_*`, `WINEPREFIX`, `WINEDLLPATH`, `WINELOADERNOEXEC`) are left out.

## Builds and versions

| Build | Version in this repo | Script read for this doc |
|---|---|---|
| Valve Proton | Proton Experimental as installed by Steam. Steam updates it | `steamapps/common/Proton - Experimental/proton` |
| Proton-GE | `GE-Proton11-12` | `proton`, `utilities.py` in the Nix store copy |
| Proton-CachyOS | `cachyos-11.0-20261015-slr` | `proton`, `utilities.py` |
| Proton-Wineland | `wineland-11.0-20261119` | `proton`, `proton_config.py`, `mesa.py`, `vulkan_layers.py`, `utilities.py`, `config.sample.ini` |

The three bundled versions are pinned in `modules/gaming/gaming.nix` and bumped by `nru`. When a version changes, an option can appear or vanish. Check the script of the installed build.

## How to set options

1. Right-click the game in Steam, Properties, General, Launch Options.
2. Write variables first, then `%command%`.

```
PROTON_LOG=1 %command%
```

Combine variables and wrappers on one line. Wrappers go before `%command%`, after the variables:

```
PROTON_USE_WINED3D=1 PROTON_LOG=1 gamemoderun %command%
MANGOHUD=1 gamemoderun %command%
```

Values `0` and empty turn an option off; any other value turns it on. Options set in Nix (`programs.steam.package.extraEnv`) never reach the game, because Steam Linux Runtime cleans the environment. Only the launch options field works.

### `PROTON_ADD_CONFIG` keywords

Proton-GE, Proton-CachyOS and Proton-Wineland read `PROTON_ADD_CONFIG`, a comma-separated list of keywords. Many options exist both as a variable and as a keyword (`PROTON_NO_FSYNC=1` and `nofsync` do the same).

```
PROTON_ADD_CONFIG=wow64,fsr4,optiscaler %command%
```

- A keyword only works if that build knows it. The tables below list the keyword next to each option. Unknown keywords are dropped without an error.
- A few keywords also take a value (`fsr4=4.0.0`). GE and CachyOS map `wow64`, `dlss`, `xess`, `fsr3`, `fsr4`, `ffx3`, `ffx4` and `optiscaler` to their variables this way.
- Valve Proton does not read `PROTON_ADD_CONFIG`. Use the variable forms there.

## Common options

`yes` means that build's script reads the option. `-` means it does not.

| Option | Valve | GE | CachyOS | Wineland | What it does |
|---|---|---|---|---|---|
| `PROTON_LOG=1` | yes | yes | yes | yes | Write a log to `~/steam-<appid>.log` |
| `PROTON_USE_WINED3D=1` | yes | yes | yes | yes | OpenGL-based wined3d instead of DXVK |
| `PROTON_NO_D3D11=1` | yes | yes | yes | yes | Disable d3d11 |
| `PROTON_NO_FSYNC=1` | yes | yes | yes | yes | Disable futex-based sync |
| `PROTON_NO_ESYNC=1` | - | yes | - | yes | Disable eventfd-based sync |
| `PROTON_USE_WOW64=1` | yes | yes | yes | yes | Run the prefix as WoW64 (no 32-bit Wine) |
| `PROTON_FORCE_NVAPI=1` | yes | yes | yes | yes | Expose NVAPI even on non-Nvidia GPUs |
| `PROTON_DISABLE_NVAPI=1` | yes | yes | yes | yes | Turn NVAPI off |
| `PROTON_HIDE_NVIDIA_GPU=1` | yes | yes | yes | yes | Hide an Nvidia GPU from the game |
| `PROTON_ENABLE_WAYLAND=1` | - | yes | yes | yes | Native Wayland Wine driver |
| `PROTON_ENABLE_HDR=1` | - | yes | - | - | HDR (sets `DXVK_HDR`) |
| `PROTON_FSR4_UPGRADE=1` | - | yes | yes | - | Replace the game's upscaler DLL with FSR4 |
| `PROTON_DLSS_UPGRADE=1` | - | yes | yes | - | Replace the game's DLSS DLL with a newer one |
| `PROTON_XESS_UPGRADE=1` | - | yes | yes | - | Replace the game's XeSS DLL with a newer one |
| `PROTON_USE_OPTISCALER=1` | - | yes | yes | yes | Use OptiScaler |
| `PROTON_PREFER_SDL=1` | - | yes | yes | yes | Use SDL input instead of Steam Input |
| `PROTON_NVIDIA_LIBS=1` | - | yes | yes | yes | Nvidia CUDA, NVENC, NVML and OptiX libraries |
| `PROTON_USE_PIPEWIRE=1` | - | - | yes | yes | Use the PipeWire audio driver |
| `PROTON_HUD=<1-5>` | - | - | - | yes | DXVK HUD preset |
| `PROTON_RADV=1` | - | - | - | yes | Use the bundled patched RADV Mesa driver |
| `PROTON_UPSCALER_UPGRADE=1` | - | - | - | yes | Upgrade FSR4, FFX, DLSS and XeSS components |
| `PROTON_DXVK_LOWLATENCY=1` | - | - | yes | yes | Low-latency DXVK build |
| `PROTON_MLFG_UPGRADE=1` | - | yes | - | yes | Multi-frame generation switch |
| `DXVK_HUD=...` | - | - | - | yes | DXVK HUD items (read by the script itself) |

Notes on the table:

- `PROTON_USE_OPTISCALER`, `PROTON_ENABLE_WAYLAND` and the Nvidia options are not in Valve's script.
- `PROTON_ENABLE_WAYLAND` is on by default in Proton-Wineland. In GE and CachyOS it is off.
- `PROTON_UPSCALER_UPGRADE` and `PROTON_RADV` are read by Wineland's helper modules. The Wineland-only names below the table come from the same scripts.
- Every Valve column entry marked `yes` also works in the other three builds.

## Options all four builds read

These are read by Valve Proton, Proton-GE, Proton-CachyOS and Proton-Wineland. Each section below starts from this list.

| Option | Keyword | What it does (from the script) |
|---|---|---|
| `PROTON_LOG=1` | | Write the log. `PROTON_LOG_DIR` sets the folder (default `$HOME`). A value other than `1` is added to `WINEDEBUG` as channels |
| `PROTON_LOG_DIR=<dir>` | | Folder for the log file |
| `WINEDEBUG=<channels>` | | Wine debug channels |
| `PROTON_CRASH_REPORT_DIR=<dir>` | | Passed to Wine as `WINE_CRASH_REPORT_DIR` |
| `PROTON_USE_WINED3D=1` | `wined3d` | wined3d (OpenGL) instead of DXVK |
| `PROTON_USE_WINED3D11=1` | `wined3d` | Same effect as `PROTON_USE_WINED3D` |
| `PROTON_NO_D3D11=1` | `nod3d11` | Disable d3d11 |
| `PROTON_NO_D3D10=1` | `nod3d10` | Disable d3d10 and d3d10_1 |
| `PROTON_DXVK_D3D8=1` | `dxvkd3d8` | Use DXVK for d3d8 |
| `PROTON_NO_FSYNC=1` | `nofsync` | Disable futex-based sync (`WINEFSYNC` is otherwise set to 1) |
| `PROTON_FORCE_LARGE_ADDRESS_AWARE=1` | `forcelgadd` | Large-address-aware (on by default). The keyword `noforcelgadd` turns it off |
| `PROTON_LIMIT_ADDRESS_SPACE=1` | | Limit the address space. The script sets it only for a few app IDs; otherwise it is read as given |
| `PROTON_LIMIT_RESOLUTIONS=<n>` | | The script sets 16 or 32 for some app IDs. Otherwise the value is passed on (meaning not documented in the script) |
| `PROTON_OLD_GL_STRING=1` | `oldglstr` | Short, old OpenGL extension string (`MESA_EXTENSION_MAX_YEAR=2003`, `__GL_ExtensionStringVersion=17700`) |
| `PROTON_HEAP_DELAY_FREE=1` | `heapdelayfree` | Wine `WINE_HEAP_DELAY_FREE=1` |
| `PROTON_HEAP_ZERO_MEMORY=1` | `heapzeromemory` | Wine `WINE_HEAP_ZERO_MEMORY=1` |
| (keyword only) | `heaptopdown` | Wine `WINE_HEAP_TOP_DOWN=1` |
| `PROTON_HIDE_NVIDIA_GPU=1` | `hidenvgpu` | `WINE_HIDE_NVIDIA_GPU=1`, unless `forcenvapi` is set |
| `PROTON_HIDE_INTEL_GPU=1` | `hideintelgpu` | `WINE_HIDE_INTEL_GPU=1` |
| `PROTON_HIDE_APU=1` | `hideapu` | `WINE_HIDE_APU=1` |
| `PROTON_HIDE_VANGOGH_GPU=1` | `hidevggpu` | `WINE_HIDE_VANGOGH_GPU=1` |
| `PROTON_FORCE_NVAPI=1` | `forcenvapi` | Turn on DXVK-NVAPI with `DXVK_NVAPI_ALLOW_OTHER_DRIVERS=1`, driver version `99999`, and hide the AMD GPU |
| `PROTON_DISABLE_NVAPI=1` | `disablenvapi` | No NVAPI. Without it, `DXVK_ENABLE_NVAPI=1` is set |
| `PROTON_SET_GAME_DRIVE=1` | `gamedrive` | Map the game's library folder as drive `s:` |
| `PROTON_SET_STEAM_DRIVE=1` | `steamdrive` | Map the Steam folder as drive `t:` |
| `PROTON_NO_XIM=1` | `noxim` | Turn off XIM (X input method) |
| `PROTON_USE_XALIA=0` | `noxalia`, `xalia` | Xalia controller UI. On by default for supported games only; `xalia` removes that limit; `noxalia` turns it off |
| `PROTON_DISABLE_HIDRAW=<ids>` | | Disable hidraw for the listed device IDs. The script sets it for one game on the Steam Deck |
| `PROTON_SPOOF_STEAMINPUT_VIDPID=1` | | Passed on for a few app IDs (meaning not documented in the script) |
| `PROTON_CPU_TOPOLOGY=<spec>` | | Passed to Wine as `WINE_CPU_TOPOLOGY` |
| `PROTON_MEDIACONV_NO_VIDEO=1` | | Skip video conversion. Set by the script for some app IDs |
| `PROTON_DLL_COPY=<list>` | | DLLs copied from the built-in set into the prefix (default list is built in) |
| `PROTON_REMOTE_DEBUG_CMD=<cmd>` | | Run the game under a debugger command |
| `WINEDLLOVERRIDES=<list>` | | DLL override list, merged with the script's own |
| `VKD3D_FEATURE_LEVEL=<level>` | `vkd3dfl12` | Direct3D feature level. The keyword sets `12_0` |
| `MESA_EXTENSION_MAX_YEAR=<year>` | | Mesa extension year limit |
| `DXVK_ENABLE_NVAPI=1`, `DXVK_NVAPI_ALLOW_OTHER_DRIVERS`, `DXVK_NVAPI_DRIVER_VERSION` | | Set by the NVAPI options above; honoured if you set them |
| `WINE_DISABLE_VULKAN_OPWR=1` | `noopwr` | Turn off Vulkan OPWR |
| `WINE_DISABLE_HARDWARE_SCHEDULING=1` | `nohardwarescheduling` | Turn off hardware scheduling |
| `WINE_DO_NOT_CREATE_DXGI_DEVICE_MANAGER=1` | `nomfdxgiman` | Do not create the DXGI device manager |
| `WINE_DISABLE_GAMESCOPE_MAX_SIZE_HACK=1` | | Turn off the gamescope max-size hack |
| (keyword only) | `vkd3dbindlesstb` | Adds `force_bindless_texel_buffer` to `VKD3D_CONFIG` |
| (keyword only) | `nativevulkanloader` | Use the native `vulkan-1` |
| (keyword only) | `usenativexinput13` | Use the native `xinput1_3` |
| (keyword only) | `disablelibglesv2` | Disable `libglesv2` |
| (keyword only) | `fnad3d11` | Force FNA3D to use D3D11 |
| `WINE_LARGE_ADDRESS_AWARE`, `WINE_HEAP_*`, `WINE_HIDE_*`, `WINE_CPU_TOPOLOGY`, `WINEFSYNC` | | The Wine variables the options above set. The script reads them |

In Valve Proton the keyword column is not usable from launch options, because Valve does not read `PROTON_ADD_CONFIG`. Valve reads keywords only from `STEAM_COMPAT_CONFIG`, which Steam fills. Use the variable form.

## Valve Proton

Reads everything in "Options all four builds read", plus:

| Option | What it does |
|---|---|
| `PROTON_USE_WOW64=1` | WoW64 prefix (`WINEARCH=wow64`). The script sets it for some app IDs. Same name in the three custom builds |
| `PROTON_USE_ARM64` | Selects the ARM64 PE tree on ARM hosts. Not relevant on x86_64 |
| `WINE_IGNORE_STARTUP_SHOW_WINDOW=1` | Wine startup-window behaviour. The script sets it for some app IDs (meaning not documented in the script) |
| `WINE_GST_REGISTRY_DIR` | GStreamer registry folder (set by the script per prefix) |
| `WINEARCH` | Reset by the script. Set `PROTON_USE_WOW64` instead |
| `WINE_HIDE_AMD_CPU`, `WINE_HIDE_AMD_GPU` | Wine hide options. The script sets them for some app IDs |

Valve Proton has no `PROTON_ADD_CONFIG`, no HDR option, no Wayland option, no upscaler upgrade options, no Nvidia library switches and no HUD preset. Its `user_settings.sample.py` documents `PROTON_LOG`, `DXVK_HUD`, `PROTON_USE_WINED3D`, `PROTON_NO_D3D11`, `PROTON_NO_ESYNC` and `PROTON_NO_FSYNC`. Copy it to `user_settings.py` to apply settings to every game, but that folder is owned by Steam and is overwritten on update.

## Proton-GE

Reads everything in "Options all four builds read", plus the options below. Each GE keyword goes into `PROTON_ADD_CONFIG`.

### Display, Wayland and HDR

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_ENABLE_WAYLAND=1`, `PROTON_USE_WAYLAND=1` | `wayland` | Use Wine's native Wayland driver (`WINE_GRAPHICS_DRIVER=wayland`). Turns off the fullscreen hack and Xalia. If Steam Input is off for the game, it also stops the virtual controller |
| `PROTON_WAYLAND_MONITOR=<name>` | | Sets the primary monitor for the Wayland driver. If unset, the script tries to find one |
| `PROTON_ENABLE_HDR=1`, `PROTON_USE_HDR=1` | `hdr` | Sets `DXVK_HDR=1` only. It does not turn on Wayland. When one of the two variables is set to 0, HDR is turned off (`DXVK_NO_HDR=1`) |
| `PROTON_FORCE_HDR=1` | `forcehdr` | `DXVK_HDR=1` and `WAYLANDDRV_FORCE_HDR=1` |
| `PROTON_NO_WM_DECORATION=1` | `nowmdecoration` | No window-manager decoration (`WAYLANDDRV_SSD=0`, `WINE_NO_WM_DECORATION=1`) |
| `WINE_DISABLE_FULLSCREEN_HACK`, `WINE_USE_EGL`, `WINE_NO_WM_DECORATION` | | Set by the Wayland path. The script reads them |
| (keyword only) | `noopwrx11` | Turns off Vulkan OPWR when not on Wayland |
| `DXVK_HDR`, `DXVK_NO_HDR` | | Set by the HDR options above |

Working setup (Diablo IV, Umbriel, 2026-11-21): `PROTON_ADD_CONFIG=fsr4,fsr4rdna3,wow64,hdr,wayland gamemoderun %command%` gives true HDR and the Steam Controller back paddles keep working. The compositor must advertise HDR: set `hdr = "auto"` on the output in Umbriel's `outputs.toml`, otherwise the in-game HDR checkbox stays greyed out. The `hdr` keyword on its own does not enable Wayland, so keep `wayland` too. The reasoning is in `modules/gaming/gaming.nix`.

### Upscaling

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_FSR4_UPGRADE=<1\|version>` | `fsr4` | Swap the game's FSR DLL for FSR4 |
| `PROTON_FSR3_UPGRADE=1` | `fsr3` | FSR3 upgrade (in `utilities.py` the `fsr3` keyword sets the FSR4 variable) |
| `PROTON_FSR4_INDICATOR=1` | `fsr4hud` | Show an FSR4 indicator |
| `PROTON_DLSS_UPGRADE=<1\|version>` | `dlss` | Newer DLSS DLL |
| `PROTON_DLSS_INDICATOR=1` | `dlsshud` | Show a DLSS indicator |
| `PROTON_XESS_UPGRADE=<1\|version>` | `xess` | Newer XeSS DLL |
| `PROTON_STREAMLINE_UPGRADE=1` | `streamline` | Redirect the game's Streamline DLLs to a newer copy (only without OptiScaler) |
| `PROTON_USE_OPTISCALER=1` | `optiscaler` | Use OptiScaler. It also enables `dlss`, `xess`, `fsr4` and `ffx3` upgrades |
| `PROTON_MLFG_UPGRADE=1` | `mlfg` | Multi-frame generation (`MLFG_UPGRADE`) |
| `PROTON_NATIVE_AGS=1` | `nativeags` | Native AMD AGS DLLs (`atiadlxx`, `atidxx64`, `amd_ags_x64` overrides) |
| `ENABLE_VKBASALT=1` | `vkbasalt` | Load the bundled vkBasalt Vulkan layer |
| `LOW_LATENCY_LAYER=1` | `lowlatencylayer` | Load the low-latency Vulkan layer |
| `PYROVEIL=1` | `pyroveil` | Load the pyroveil layer. `PYROVEIL_CONFIG` picks its config |
| `PROTON_LOCAL_SHADER_CACHE=1` | `localshadercache` | Per-game shader cache folder (used when Steam shader pre-caching is off) |

### Sync

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_NO_ESYNC=1` | `noesync` | Disable eventfd sync (`WINEESYNC=0`) |
| `PROTON_NO_NTSYNC=1` | `nontsync` | Do not set `WINENTSYNC`. It is otherwise on |

### Input

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_PREFER_SDL=1`, `PROTON_USE_SDL=1` | `sdlinput` | SDL input: turns off hidraw and Steam Input for the game |
| `PROTON_NO_STEAMINPUT=1` | | Turn Steam Input off |
| `PROTON_EMULATE_STEAMINPUT=1` | | Keep the Steam virtual gamepad info when SDL input is on |
| `PROTON_STEAMINPUT_FALLBACK=1`, `PROTON_STEAMINPUT_XINPUT_FALLBACK=1` | | Drop `sdlinput` and re-enable hidraw |
| `SDL_GAMECONTROLLER_ALLOW_STEAM_VIRTUAL_GAMEPAD`, `SDL_GAMECONTROLLER_IGNORE_DEVICES` | | SDL hints the script reads and may clear |
| `PROTON_ENABLE_WINEBTH=1` | `winebth` | Enable Wine's Bluetooth driver |

### GPU and vendor

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_NVIDIA_LIBS=1` | `nvidialibs` | Turn on all four below |
| `PROTON_NVIDIA_NVCUDA=1` | `nvcuda` | Nvidia CUDA library |
| `PROTON_NVIDIA_NVENC=1` | `nvenc` | Nvidia NVENC |
| `PROTON_NVIDIA_NVML=1` | `nvml` | Nvidia NVML |
| `PROTON_NVIDIA_NVOPTIX=1` | `nvoptix` | Nvidia OptiX |
| `PROTON_NVIDIA_LIBS_NO_32BIT=1` | `nvidialibsno32` | Skip the 32-bit Nvidia libraries |
| `DXVK_NVAPI_VKREFLEX=1` | `vkreflex` | dxvk-nvapi Reflex layer (Nvidia driver only) |
| `DXVK_NVAPI_SET_NGX_DEBUG_OPTIONS` | | NGX debug options passed to dxvk-nvapi |
| `PROTON_USE_D7VK=1` | | Use D7VK for ddraw |
| `WINE_SIMULATE_WRITECOPY=1`, `PROTON_USE_WRITECOPY=1` | `writecopy` | Simulate write-copy |
| `PROTON_USE_XALIA` | | See the shared table. Wayland turns it off |

### Debugging

The shared options `PROTON_LOG`, `WINEDEBUG` and `PROTON_REMOTE_DEBUG_CMD` apply. GE adds nothing else for debugging that the script documents.

### Set automatically for some games

The script sets these for certain app IDs: `PROTON_DEATH_STRANDING_CONTROLLER_EFFECTS`, `PROTON_DEATH_STRANDING_FORCE_ENVIRONMENT_EFFECTS`, `PROTON_ENABLE_MHWILDS_USB_AUDIO`, `PROTON_SONY_DUALSENSE_AS_DUALSHOCK4`, `PROTON_SONY_DUALSHOCK4_V2_AS_V1`, `PROTON_XINPUT_PERSISTENT_PLAYER1`, `WINE_DISABLE_EXE_ASLR`, `PROTON_PIPEWIRE_ALSA_PLUGIN`. Setting them by hand is not needed.

## Proton-CachyOS

Reads everything in "Options all four builds read", plus the options below. CachyOS recognises only a small table of `PROTON_ADD_CONFIG` keys for value mapping (`wow64`, `dlss`, `xess`, `fsr3`, `fsr4`, `ffx3`, `ffx4`, `optiscaler`). It has no `hdr` and no `forcehdr`, so `PROTON_ADD_CONFIG=hdr` does nothing here. The script does read `wayland` as a compat keyword and as `PROTON_ENABLE_WAYLAND`.

Defaults the script turns on: `pipewire`, `gamedrive`, `fsr4`, and `dxvksarek` when the GPU does not support Vulkan 1.3 with `descriptorIndexing`.

### Display and Wayland

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_ENABLE_WAYLAND=1`, `PROTON_USE_WAYLAND=1` | `wayland` | Native Wayland Wine driver |
| `PROTON_NO_WM_DECORATION=1` | `nowmdecoration` | No window-manager decoration |
| (keyword only) | `noopwrx11` | Vulkan OPWR switch used on X11 |

### Upscaling and frame pacing

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_FSR4_UPGRADE=<1\|version>` | `fsr4` | Swap the game's FSR DLL for FSR4. The script adds `fsr4` by default |
| `PROTON_FSR4_INDICATOR=1` | `fsr4hud` | Show an FSR4 indicator |
| `PROTON_FFX3_UPGRADE=1` | `ffx3` | FFX3 upgrade |
| `PROTON_FFX4_UPGRADE=1` | `ffx4` | FFX4 upgrade |
| `PROTON_DLSS_UPGRADE=<1\|version>` | `dlss` | Newer DLSS DLL |
| `PROTON_DLSS_INDICATOR=1` | `dlsshud` | Show a DLSS indicator |
| `PROTON_XESS_UPGRADE=<1\|version>` | `xess` | Newer XeSS DLL |
| `PROTON_USE_OPTISCALER=1` | `optiscaler` | Use OptiScaler |
| `PROTON_NATIVE_AGS=1` | `nativeags` | Native AMD AGS DLLs |
| `ENABLE_VKBASALT=1` | `vkbasalt` | Bundled vkBasalt layer |
| `LOW_LATENCY_LAYER=1` | `lowlatencylayer` | Low-latency Vulkan layer |
| `PROTON_DXVK_LOWLATENCY=1` | `dxvklowlatency` | Use the low-latency DXVK build, and turn async off |
| `PROTON_VKD3D_LOWLATENCY=1` | `vkd3dlowlatency` | Use the low-latency vkd3d-proton build |
| `PROTON_DXVK_SAREK=1` | `dxvksarek` | Use the `dxvk-sarek` build (default when the GPU lacks Vulkan 1.3) |
| (keyword only) | `dxvkllasync` | DXVK async with compiler threads and graphics pipeline libraries |
| `DXVK_ASYNC` | | Set to 0 by the low-latency option |
| `PROTON_D7VK_DDRAW=1` | `d7vkddraw` | D7VK ddraw |
| `PROTON_LOCAL_SHADER_CACHE=1` | `localshadercache` | Per-game shader cache folder |
| `DXVK_FILTER_DEVICE_NAME`, `DXVK_FILTER_DEVICE_UUID` | | GPU filter. The script also uses it to test for Vulkan 1.3 |
| `DXVK_NO_UE4_WORKAROUND` | | Set with `nativeags` (meaning not documented in the script) |

### Audio and media

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_USE_PIPEWIRE=1` | `pipewire` | PipeWire audio driver. Otherwise `WINE_AUDIO_DRIVER` defaults to `pulse,alsa` |
| `PROTON_ENABLE_MEDIACONV=1` | `mediaconv` | Turns on `PROTON_VIDEO_CONVERT`, `PROTON_AUDIO_CONVERT`, `PROTON_AUDIO_CONVERT_BIN` and `PROTON_DEMUX` |
| `PROTON_NATIVE_STEAM=1` | `nativesteam` | Use the native Steam client (drops the `steam.exe` override, sets `PROTON_DISABLE_LSTEAMCLIENT`) |

### Input

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_PREFER_SDL=1`, `PROTON_USE_SDL=1` | `sdlinput` | SDL input: disables hidraw and Steam Input |
| `PROTON_NO_STEAMINPUT=1`, `PROTON_EMULATE_STEAMINPUT=1` | | Steam Input switches |
| `SDL_GAMECONTROLLER_ALLOW_STEAM_VIRTUAL_GAMEPAD`, `SDL_GAMECONTROLLER_IGNORE_DEVICES` | | SDL hints the script reads and may clear |

### GPU and vendor

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_NVIDIA_LIBS`, `_NVCUDA`, `_NVENC`, `_NVML`, `_NVOPTIX`, `_LIBS_NO_32BIT` | `nvidialibs`, `nvcuda`, `nvenc`, `nvml`, `nvoptix`, `nvidialibsno32` | Nvidia libraries, as in the GE section |
| `PROTON_ZLUDA=1` | `zluda` | Use ZLUDA (CUDA on AMD) if present. Turns off the Nvidia libraries and NVAPI |
| `DXVK_NVAPI_VKREFLEX=1` | `vkreflex` | dxvk-nvapi Reflex layer |
| `DXVK_NVAPI_SET_NGX_DEBUG_OPTIONS` | | NGX debug options |
| `WINE_SIMULATE_WRITECOPY=1` | `writecopy` | Simulate write-copy |

### Debugging

The shared options `PROTON_LOG`, `WINEDEBUG` and `PROTON_REMOTE_DEBUG_CMD` apply. No CachyOS-only debug option.

## Proton-Wineland

Reads everything in "Options all four builds read", plus the options below. Native Wayland is on by default: the script runs `setdefault("PROTON_ENABLE_WAYLAND", "1")`. Turn it off with `PROTON_ENABLE_WAYLAND=0`. Wineland has no `hdr`, `forcehdr` or `fsr4` keywords in its launcher.

### Display, Wayland and overlay

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_ENABLE_WAYLAND=0` | `wayland` | On by default. `0` returns to the X11 path |
| `PROTON_NO_WM_DECORATION=1` | `nowmdecoration` | No window-manager decoration |
| `PROTON_WAYLAND_STEAM_OVERLAY=0` | | Turn off the Steam overlay bridge for Wayland (default on under Wayland). The script also turns it off when the native overlay or the translation layer is missing |
| `PROTON_WAYLAND_OPENGL_OVERLAY=1` | | Opt in per game to the EGL adapter for Steam's native OpenGL overlay |
| `PROTON_WAYLAND_VULKAN_LAYER_ORDER` | | Set by the script after it puts the Steam overlay first, then the Wineland translation layer. Not meant to be set by hand |

### HUD

| Option | What it does |
|---|---|
| `PROTON_HUD=<1-5>[,<extra>]` | DXVK HUD preset. `1`: fps and fps lows. `2`: adds GPU and CPU load, power and temperature, driver and API. `3`: adds clocks, VRAM, version and present mode. `4`: adds present latency. `5`: full HUD without system info. Text after the comma is added to `DXVK_HUD`. An explicit `DXVK_HUD` wins |
| `DXVK_HUD=<items>` | DXVK's own HUD list |
| `PROTON_UPSCALER_INFO=1` (`upscalerinfo`) | Show upscaler and frame-generation watermarks (`FSR_WATERMARK`, `FSR_FG_WATERMARK`, NGX indicator options) |

### Upscaling

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_UPSCALER_UPGRADE=1` | | Upgrade FSR4, FFX, DLSS and XeSS components for the GPU in use. Read by the `upscalers/` helpers, not by the main script |
| `PROTON_MLFG_UPGRADE=1` | `mlfg` | Multi-frame generation (`MLFG_UPGRADE`) |
| `PROTON_USE_OPTISCALER=1` | `optiscaler` | Use OptiScaler |
| `WINE_FSR4_PROVIDER`, `WINE_FFX_PROVIDER`, `WINE_DLSS_PROVIDER`, `WINE_XESS_PROVIDER` | | Point a provider at a specific DLL. Read by the `upscalers/` helpers |
| `WINE_FSR4_LITE=1` | | FSR4 lite model. The script turns it on for some AMD GPUs |
| `PROTON_NATIVE_AGS=1` | `nativeags` | Native AMD AGS DLLs |
| `ENABLE_VKBASALT=1` | `vkbasalt` | Bundled vkBasalt layer |
| `PYROVEIL=1` | `pyroveil` | Pyroveil layer |
| `PROTON_LOCAL_SHADER_CACHE=1` | `localshadercache` | Per-game shader cache folder |
| `PROTON_DXVK_LOWLATENCY=1` | `dxvklowlatency` | Low-latency DXVK, async off |
| `PROTON_DXVK_SAREK=1` | `dxvksarek` | The `dxvk-sarek` build |
| (keyword only) | `dxvkllasync` | DXVK async settings |
| `PROTON_D7VK_DDRAW=1` | `d7vkddraw` | D7VK ddraw |
| `DXVK_ASYNC` | | Set to 0 by the low-latency option |
| `DXVK_FILTER_DEVICE_NAME`, `DXVK_FILTER_DEVICE_UUID` | | GPU filter |

### Sync

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_NO_ESYNC=1` | `noesync` | Disable eventfd sync (`WINEESYNC=0`; otherwise 1) |
| `WINEESYNC` | | Set by the script |

### Audio and media

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_USE_PIPEWIRE=1` | `pipewire` | PipeWire audio. Otherwise `WINE_AUDIO_DRIVER` defaults to `pulse,alsa` |
| `PROTON_ENABLE_MEDIACONV=1` | `mediaconv` | Media conversion switches |
| `PROTON_NATIVE_STEAM=1` | `nativesteam` | Use the native Steam client |

### Input

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_PREFER_SDL=1`, `PROTON_USE_SDL=1` | `sdlinput` | SDL input |
| `PROTON_NO_STEAMINPUT=1`, `PROTON_EMULATE_STEAMINPUT=1` | | Steam Input switches |
| `SDL_GAMECONTROLLER_ALLOW_STEAM_VIRTUAL_GAMEPAD`, `SDL_GAMECONTROLLER_IGNORE_DEVICES` | | SDL hints |

### GPU and vendor

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_RADV=1` | | Use the bundled patched RADV Mesa driver (x86-64 only). The script logs the Mesa version and patch count and sets `PROTON_RADV_VERSION` |
| `PROTON_NVIDIA_LIBS`, `_NVCUDA`, `_NVENC`, `_NVML`, `_NVOPTIX`, `_LIBS_NO_32BIT` | `nvidialibs`, `nvcuda`, `nvenc`, `nvml`, `nvoptix`, `nvidialibsno32` | Nvidia libraries. NVML is on by default on Nvidia |
| `DXVK_NVAPI_VKREFLEX=1` | `vkreflex` | dxvk-nvapi Reflex layer |
| `DXVK_NVAPI_SET_NGX_DEBUG_OPTIONS` | | NGX debug options |
| `WINE_SIMULATE_WRITECOPY=1` | `writecopy` | Simulate write-copy |
| `WINE_GRAPHICS_DRIVER`, `WINE_USE_EGL` | | Set by the Wayland path |

### Config file

Wineland can store options in `~/.config/proton/config.ini` (or `$XDG_CONFIG_HOME/proton/config.ini`) instead of launch options. `proton_config.py` reads it. The store copy ships `config.sample.ini`.

```ini
[global]
PROTON_HUD = 3
PROTON_RADV = 1

[steam:292030]
PROTON_HUD = 4
```

- `[global]` applies to every game. `[steam:<appid>]` applies to one Steam game and overrides `[global]`. `[umu:<id>]` does the same for non-Steam games, using the `UMU_ID` the launcher supplies.
- Keys are environment variable names. A key that is not a valid name makes the whole file ignored, and the script logs why.
- It only fills variables that are absent. A launch option always wins.
- The file is created by you. Nothing in this repo writes it.

### Debugging

The shared options `PROTON_LOG`, `WINEDEBUG` and `PROTON_REMOTE_DEBUG_CMD` apply, plus `PROTON_HUD` and `DXVK_HUD` above.

## What was left out

- Variables that only pass through to Wine or DXVK without the script acting on them are noted as such where they appear in a table.
- Per-game workarounds that the script sets for specific Steam app IDs are not listed, except in the GE section.
- The matrix reads `proton` and the top-level `*.py` files. Wineland's `upscalers/` folder was read separately, which is why `PROTON_UPSCALER_UPGRADE` and the `WINE_*_PROVIDER` names appear only in the Wineland section.
