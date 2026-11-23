# Proton launch options

Launch options per Proton build. Each build has its own section: what it does, its launch options, and the best launch line to start from. The lists come from each build's own launcher script (`proton` and its `*.py` helpers), not from upstream documentation. Builds and how to pick one: [10-gaming.md](10-gaming.md).

An option missing from a build's list may still be read by that build's Wine, DXVK or vkd3d-proton. This doc lists what the launcher script handles. Names that are internal plumbing (`STEAM_COMPAT_*`, `WINEPREFIX`, `WINEDLLPATH`, `WINELOADERNOEXEC`) are left out.

## Builds and versions

| Build | Version in this repo | Script read for this doc |
|---|---|---|
| Valve Proton | Proton Experimental as installed by Steam. Steam updates it | `steamapps/common/Proton - Experimental/proton` |
| Proton-GE | `GE-Proton11-14` | `proton`, `utilities.py` in the Nix store copy |
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

### What it does

Valve's own build, installed and updated by Steam. It has the fewest extras, and it is the build Steam tests games against. It reads only plain variables: no `PROTON_ADD_CONFIG`, no HDR, no native Wayland, no upscaler upgrades and no HUD preset. Use it as the baseline: when a custom build breaks a game, check here first whether the game works at all.

### Launch options

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

### Best launch option and why

```
gamemoderun %command%
```

- Valve has none of the extras the custom builds add, so there is nothing to tune. Leave the game on Valve's defaults, because those are the settings Steam tested.
- `gamemoderun` asks GameMode to switch the CPU governor to performance while the game runs.
- When a game crashes, add `PROTON_LOG=1` to get `~/steam-<appid>.log`. Remove it afterwards, because logging slows the game down.

## Proton-GE

### What it does

GloriousEggroll's custom Proton. It has the widest option set of the four builds: HDR, native Wayland, FSR4, DLSS and XeSS upgrades, OptiScaler, SDL input and Nvidia library switches. It is the only build here with an HDR option, so use it for HDR games.

### Launch options

Reads everything in "Options all four builds read", plus the options below. Each GE keyword goes into `PROTON_ADD_CONFIG`.

#### Display, Wayland and HDR

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_ENABLE_WAYLAND=1`, `PROTON_USE_WAYLAND=1` | `wayland` | Use Wine's native Wayland driver (`WINE_GRAPHICS_DRIVER=wayland`). Turns off the fullscreen hack and Xalia. If Steam Input is off for the game, it also stops the virtual controller |
| `PROTON_WAYLAND_MONITOR=<name>` | | Sets the primary monitor for the Wayland driver. If unset, the script tries to find one |
| `PROTON_ENABLE_HDR=1`, `PROTON_USE_HDR=1` | `hdr` | Sets `DXVK_HDR=1` only. It does not turn on Wayland. When one of the two variables is set to 0, HDR is turned off (`DXVK_NO_HDR=1`) |
| `PROTON_FORCE_HDR=1` | `forcehdr` | `DXVK_HDR=1` and `WAYLANDDRV_FORCE_HDR=1` |
| `DISABLE_WINE_HDR_COLORSPACE_LAYER=1` | | Turn off the HDR colorspace layer. On the Wayland path it is on by default: Wine passes HDR swapchains through to the driver while the Steam overlay and MangoHud still see the real HDR colorspace, so they draw with correct colours |
| `PROTON_NO_WM_DECORATION=1` | `nowmdecoration` | No window-manager decoration (`WAYLANDDRV_SSD=0`, `WINE_NO_WM_DECORATION=1`) |
| `WINE_DISABLE_FULLSCREEN_HACK`, `WINE_USE_EGL`, `WINE_NO_WM_DECORATION` | | Set by the Wayland path. The script reads them |
| (keyword only) | `noopwrx11` | Turns off Vulkan OPWR when not on Wayland |
| `DXVK_HDR`, `DXVK_NO_HDR` | | Set by the HDR options above |

The working HDR line is under "Best launch option and why" at the end of this section.

#### Upscaling

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_FSR4_UPGRADE=<1\|version>` | `fsr4` | Swap the game's FSR DLL for FSR4. Setting it also sets `FSR4_UPGRADE=1`, which the script calls extended GPU support: FSR4 is turned on even for GPUs where it is not on by default |
| `PROTON_FSR3_UPGRADE=1` | `fsr3` | FSR3 upgrade (in `utilities.py` the `fsr3` keyword sets the FSR4 variable) |
| `PROTON_FSR4_INDICATOR=1` | `fsr4hud` | Show an FSR4 indicator |
| `PROTON_DLSS_UPGRADE=<1\|version>` | `dlss` | Newer DLSS DLL |
| `PROTON_DLSS_INDICATOR=1` | `dlsshud` | Show a DLSS indicator |
| `PROTON_XESS_UPGRADE=<1\|version>` | `xess` | Newer XeSS DLL |
| `PROTON_STREAMLINE_UPGRADE=1` | `streamline` | Redirect the game's Streamline DLLs to a newer copy. Since 11-14 it only works together with `dlss` |
| `PROTON_USE_OPTISCALER=1` | `optiscaler` | Use OptiScaler. It also enables the `dlss`, `xess`, `fsr4`, `ffx3` and Streamline upgrades |
| `PROTON_MLFG_UPGRADE=1` | `mlfg` | Multi-frame generation (`MLFG_UPGRADE`) |
| `PROTON_NATIVE_AGS=1` | `nativeags` | Native AMD AGS DLLs (`atiadlxx`, `atidxx64`, `amd_ags_x64` overrides) |
| `ENABLE_VKBASALT=1` | `vkbasalt` | Load the bundled vkBasalt Vulkan layer |
| `LOW_LATENCY_LAYER=1` | `lowlatencylayer` | Load the low-latency Vulkan layer |
| `PYROVEIL=1` | `pyroveil` | Load the pyroveil layer. `PYROVEIL_CONFIG` picks its config |
| `PROTON_LOCAL_SHADER_CACHE=1` | `localshadercache` | Per-game shader cache folder (used when Steam shader pre-caching is off) |

#### Sync

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_NO_ESYNC=1` | `noesync` | Disable eventfd sync (`WINEESYNC=0`) |
| `PROTON_NO_NTSYNC=1` | `nontsync` | Do not set `WINENTSYNC`. It is otherwise on |

#### Direct3D 8 and older

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_NO_D8VK=1` | `nod8vk` | d3d8 uses DXVK by default (unless wined3d is on). This turns that off. `PROTON_DXVK_D3D8` / `dxvkd3d8` from the shared table are still read but no longer needed |
| `PROTON_NO_D7VK=1` | `nod7vk` | 32-bit ddraw (D3D7, 6, 5, 3) uses D7VK by default (unless wined3d is on). This turns that off. `PROTON_USE_D7VK` is no longer needed |

#### Audio

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_ENABLE_PIPEWIRE=1`, `PROTON_USE_PIPEWIRE=1` | `pipewire` | Talk to PipeWire directly (`WINE_AUDIO_DRIVER=pipewire,pulse,alsa`) instead of through pipewire-pulse. Off by default. An explicit `WINE_AUDIO_DRIVER` wins |
| `PROTON_NO_MIDI_SYNTH=1` | | Turn off the software MIDI synth. It is on by default and used only when the host has no MIDI device |
| `PROTON_MIDI_SOUNDFONT=<path>` | | Soundfont for the MIDI synth. Default: the bundled `GeneralUser-GS.sf2` |

#### Input

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_PREFER_SDL=1`, `PROTON_USE_SDL=1` | `sdlinput` | SDL input: turns off hidraw and Steam Input for the game |
| `PROTON_NO_STEAMINPUT=1` | | Turn Steam Input off |
| `PROTON_EMULATE_STEAMINPUT=1` | | Keep the Steam virtual gamepad info when SDL input is on |
| `PROTON_STEAMINPUT_FALLBACK=1`, `PROTON_STEAMINPUT_XINPUT_FALLBACK=1` | | Drop `sdlinput` and re-enable hidraw |
| `SDL_GAMECONTROLLER_ALLOW_STEAM_VIRTUAL_GAMEPAD`, `SDL_GAMECONTROLLER_IGNORE_DEVICES` | | SDL hints the script reads and may clear |
| `PROTON_ENABLE_WINEBTH=1` | `winebth` | Enable Wine's Bluetooth driver |

#### GPU and vendor

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
| `PROTON_ENABLE_NGX_UPDATER=1` | | Let the Nvidia driver's NGX updater (`nvngx_update.exe`) download newer DLSS versions, and make NGX use them instead of the game's DLLs |
| `WINE_SIMULATE_WRITECOPY=1`, `PROTON_USE_WRITECOPY=1` | `writecopy` | Simulate write-copy |
| `PROTON_USE_XALIA` | | See the shared table. Wayland turns it off |

#### Debugging

The shared options `PROTON_LOG`, `WINEDEBUG` and `PROTON_REMOTE_DEBUG_CMD` apply. GE adds nothing else for debugging that the script documents.

#### Set automatically for some games

The script sets these for certain app IDs: `PROTON_DEATH_STRANDING_CONTROLLER_EFFECTS`, `PROTON_DEATH_STRANDING_FORCE_ENVIRONMENT_EFFECTS`, `PROTON_ENABLE_MHWILDS_USB_AUDIO`, `PROTON_SONY_DUALSENSE_AS_DUALSHOCK4`, `PROTON_SONY_DUALSHOCK4_V2_AS_V1`, `PROTON_XINPUT_PERSISTENT_PLAYER1`, `PROTON_SONY_AUTO_XINPUT`, `PROTON_SONY_DUALSENSE_EDGE_AS_DUALSENSE` (Diablo IV, so the game recognizes a DualSense Edge), `PROTON_NATIVE_AGS` (Darktide on AMD-only systems), `WINE_IGNORE_STARTUP_SHOW_WINDOW`, `WINE_DISABLE_EXE_ASLR`, `PROTON_PIPEWIRE_ALSA_PLUGIN`. Setting them by hand is not needed.

### Best launch option and why

Verified on Diablo IV under Umbriel (2026-11-21). It gives true HDR, and the Steam Controller back paddles keep working:

```
PROTON_ADD_CONFIG=fsr4,wow64,hdr,wayland gamemoderun %command%
```

- `fsr4` swaps the game's FSR DLL for FSR4. It also sets `FSR4_UPGRADE=1`, so FSR4 runs even on GPUs where it is not on by default.
- The verified line also had `fsr4rdna3`. No script in GE 11-12 or 11-14 reads that keyword, so GE dropped it without an error. Removing it changes nothing.
- `wow64` runs the prefix as WoW64, with no separate 32-bit Wine. If an old 32-bit game fails to start, remove it.
- `hdr` only sets `DXVK_HDR=1`. It does not turn on Wayland, so `wayland` has to be there too, because HDR needs the native Wayland driver.
- The compositor must advertise HDR as well: set `hdr = "auto"` on the output in Umbriel's `outputs.toml`. With `off`, the game's HDR checkbox stays greyed out whatever the launch options say.
- Add `fsr4hud` to the list to see an on-screen indicator that FSR4 is active.

The reasoning is in `modules/gaming/gaming.nix`.

## Proton-CachyOS

### What it does

CachyOS's performance-tuned Proton. Without any launch options it already turns on PipeWire audio, the `s:` game drive and the FSR4 upgrade. It adds low-latency DXVK and vkd3d builds, a frame-rate cap and the `dxvk-sarek` fork for GPUs without Vulkan 1.3. It has no HDR option, so use GE for HDR games. Its native Wayland mode turns Steam Input off by default.

### Launch options

Reads everything in "Options all four builds read", plus the options below. Checked against `cachyos-11.0-20261015-slr`.

How CachyOS reads `PROTON_ADD_CONFIG`:

- Every keyword in the list goes into the compat config, so any keyword in the tables below works there, `wayland` included.
- Only `wow64`, `dlss`, `xess`, `fsr3`, `fsr4`, `ffx3`, `ffx4` and `optiscaler` also take a value (`fsr4=4.0.0`) and set their variable.
- There is no `hdr` or `forcehdr` anywhere in the script, so `PROTON_ADD_CONFIG=hdr` does nothing.

Defaults the script turns on:

| Default | Turn it off with |
|---|---|
| `fsr4` (FSR4 upgrade) | `PROTON_FSR4_UPGRADE=0` |
| `pipewire` (PipeWire audio) | `PROTON_USE_PIPEWIRE=0`. Audio then uses `pulse,alsa` |
| `gamedrive` (game library as drive `s:`) | `PROTON_SET_GAME_DRIVE=0` |
| `dxvksarek`, only when the GPU lacks Vulkan 1.3 with `descriptorIndexing` | `PROTON_DXVK_SAREK=0` |

#### Display and Wayland

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_ENABLE_WAYLAND=1`, `PROTON_USE_WAYLAND=1` | `wayland` | Native Wayland Wine driver, only when `WAYLAND_DISPLAY` is set. Also turns off the fullscreen hack and Xalia, turns on `WINE_MOVE_HACK`, and **sets `PROTON_NO_STEAMINPUT=1` by default**, because the script says Steam Input does not work on Wayland. Steam Controller paddles and Steam Input layouts stop working. `PROTON_NO_STEAMINPUT=0` overrides it, but the script expects it not to work |
| `PROTON_NO_WM_DECORATION=1` | `nowmdecoration` | No window-manager decoration (`WAYLANDDRV_SSD=0`, `WINE_NO_WM_DECORATION=1`) |
| (keyword only) | `noopwrx11` | Vulkan OPWR switch used on X11 |

#### Upscaling and frame pacing

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_FSR4_UPGRADE=<1\|version>` | `fsr4` | Swap the game's FSR DLL for FSR4. The script adds `fsr4` by default. Unlike GE, it never sets `FSR4_UPGRADE=1`, so FSR4 is not forced on GPUs where it is off by default |
| `FSR4_UPGRADE=1` | | Read by the bundled `amdxc64.dll`. Turns on FSR4 for GPUs where it is not on by default (GE calls this extended GPU support). Set it by hand here |
| `PROTON_FSR4_INDICATOR=1` | `fsr4hud` | Show FSR4 and frame-generation watermarks (`FSR_WATERMARK`, `FSR_FG_WATERMARK`) |
| `PROTON_FFX3_UPGRADE=1` | `ffx3` | FFX3 upgrade |
| `PROTON_FFX4_UPGRADE=1` | `ffx4` | FFX4 upgrade |
| `PROTON_DLSS_UPGRADE=<1\|version>` | `dlss` | Newer DLSS DLL |
| `PROTON_DLSS_INDICATOR=1` | `dlsshud` | Show a DLSS indicator |
| `PROTON_XESS_UPGRADE=<1\|version>` | `xess` | Newer XeSS DLL |
| `PROTON_USE_OPTISCALER=1` | `optiscaler` | Use OptiScaler. It also enables the `dlss`, `xess`, `fsr4` and `ffx3` upgrades |
| `PROTON_OPTISCALER_CONFIG=<Section.option=value;...>` | | Write values into `OptiScaler.ini`. Unknown options are logged and skipped |
| `PROTON_OPTISCALER_NAME=<dll>` | | DLL name OptiScaler loads as (default `dxgi.dll`) |
| `PROTON_OPTISCALER_STREAMLINE=<1\|version>` | | Also install a newer Streamline with OptiScaler |
| `PROTON_FRAME_RATE=<fps>` | | Frame-rate cap. Written to `DXVK_CONFIG` as `dxgi.maxFrameRate` and `d3d9.maxFrameRate`. `DXVK_FRAME_RATE` and `VKD3D_FRAME_RATE` do the same and win if set |
| `PROTON_NATIVE_AGS=1` | `nativeags` | Native AMD AGS DLLs |
| `ENABLE_VKBASALT=1` | `vkbasalt` | Bundled vkBasalt layer |
| `LOW_LATENCY_LAYER=1` | `lowlatencylayer` | Low-latency Vulkan layer |
| `PROTON_DXVK_LOWLATENCY=1` | `dxvklowlatency` | Use the low-latency DXVK build, turn async off (`dxvk.enableAsync=False`), and also turn on `dxvkllasync` |
| `PROTON_VKD3D_LOWLATENCY=1` | `vkd3dlowlatency` | Use the low-latency vkd3d-proton build |
| `PROTON_DXVK_SAREK=1` | `dxvksarek` | Use the `dxvk-sarek` build (default when the GPU lacks Vulkan 1.3) |
| (keyword only) | `dxvkllasync` | DXVK shader compiler threads set to the CPU core count minus 2, and graphics pipeline libraries on `Auto` |
| `DXVK_ASYNC` | | Set to 0 by the low-latency option |
| `PROTON_D7VK_DDRAW=1` | `d7vkddraw` | D7VK ddraw |
| `PROTON_LOCAL_SHADER_CACHE=1` | `localshadercache` | Per-game shader cache folder |
| `DXVK_FILTER_DEVICE_NAME`, `DXVK_FILTER_DEVICE_UUID` | | GPU filter. The script also uses it to test for Vulkan 1.3 |
| `DXVK_NO_UE4_WORKAROUND` | | Set with `nativeags` (meaning not documented in the script) |

#### Audio and media

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_USE_PIPEWIRE=1` | `pipewire` | PipeWire audio driver. Otherwise `WINE_AUDIO_DRIVER` defaults to `pulse,alsa` |
| `PROTON_ENABLE_MEDIACONV=1` | `mediaconv` | Turns on `PROTON_VIDEO_CONVERT`, `PROTON_AUDIO_CONVERT`, `PROTON_AUDIO_CONVERT_BIN` and `PROTON_DEMUX` |
| `PROTON_NATIVE_STEAM=1` | `nativesteam` | Use the native Steam client (drops the `steam.exe` override, sets `PROTON_DISABLE_LSTEAMCLIENT`) |

#### Input

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_PREFER_SDL=1`, `PROTON_USE_SDL=1` | `sdlinput` | SDL input: disables hidraw and Steam Input |
| `PROTON_NO_STEAMINPUT=1`, `PROTON_EMULATE_STEAMINPUT=1` | | Steam Input switches |
| `SDL_GAMECONTROLLER_ALLOW_STEAM_VIRTUAL_GAMEPAD`, `SDL_GAMECONTROLLER_IGNORE_DEVICES` | | SDL hints the script reads and may clear |

#### GPU and vendor

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_NVIDIA_LIBS`, `_NVCUDA`, `_NVENC`, `_NVML`, `_NVOPTIX`, `_LIBS_NO_32BIT` | `nvidialibs`, `nvcuda`, `nvenc`, `nvml`, `nvoptix`, `nvidialibsno32` | Nvidia libraries, as in the GE section |
| `PROTON_ZLUDA=1` | `zluda` | Use ZLUDA (CUDA on AMD) if present. Turns off the Nvidia libraries and NVAPI |
| `DXVK_NVAPI_VKREFLEX=1` | `vkreflex` | dxvk-nvapi Reflex layer |
| `DXVK_NVAPI_SET_NGX_DEBUG_OPTIONS` | | NGX debug options |
| `WINE_SIMULATE_WRITECOPY=1` | `writecopy` | Simulate write-copy |

#### Debugging

The shared options `PROTON_LOG`, `WINEDEBUG` and `PROTON_REMOTE_DEBUG_CMD` apply. No CachyOS-only debug option.

### Best launch option and why

Not tested yet on this setup:

```
FSR4_UPGRADE=1 gamemoderun %command%
```

- FSR4 and PipeWire are already on by default, so they do not need to be in the line.
- `FSR4_UPGRADE=1` is the part CachyOS leaves out compared with GE's `fsr4`. It turns FSR4 on for GPUs where it is not on by default. It does no harm on GPUs where FSR4 is already on. Add `PROTON_FSR4_INDICATOR=1` once to confirm FSR4 is active.
- Leave Wayland off. In CachyOS, Wayland turns Steam Input off by default, so the Steam Controller paddles and Steam Input layouts would stop working. It also brings no HDR, so there is little to gain.
- Leave HDR out. CachyOS has no HDR option, and `PROTON_ADD_CONFIG=hdr` is dropped without an error.
- For a frame-rate cap without MangoHud, add `PROTON_FRAME_RATE=<fps>`.
- If a game stutters or feels laggy, try `PROTON_DXVK_LOWLATENCY=1` for DirectX 9 to 11 games, or `PROTON_VKD3D_LOWLATENCY=1` for DirectX 12. Change one thing at a time.

## Proton-Wineland

### What it does

A CachyOS-based Proton focused on Wayland. Native Wayland is on by default. It adds a Steam overlay bridge for Wayland, DXVK HUD presets, an upscaler upgrade with an FSR4 lite model, a bundled patched RADV driver, and a config file that holds options per game. It has no HDR option.

### Launch options

Reads everything in "Options all four builds read", plus the options below. Native Wayland is on by default: the script runs `setdefault("PROTON_ENABLE_WAYLAND", "1")`. Turn it off with `PROTON_ENABLE_WAYLAND=0`. Wineland has no `hdr`, `forcehdr` or `fsr4` keywords in its launcher.

#### Display, Wayland and overlay

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_ENABLE_WAYLAND=0` | `wayland` | On by default. `0` returns to the X11 path |
| `PROTON_NO_WM_DECORATION=1` | `nowmdecoration` | No window-manager decoration |
| `PROTON_WAYLAND_STEAM_OVERLAY=0` | | Turn off the Steam overlay bridge for Wayland (default on under Wayland). The script also turns it off when the native overlay or the translation layer is missing |
| `PROTON_WAYLAND_OPENGL_OVERLAY=1` | | Opt in per game to the EGL adapter for Steam's native OpenGL overlay |
| `PROTON_WAYLAND_VULKAN_LAYER_ORDER` | | Set by the script after it puts the Steam overlay first, then the Wineland translation layer. Not meant to be set by hand |

#### HUD

| Option | What it does |
|---|---|
| `PROTON_HUD=<1-5>[,<extra>]` | DXVK HUD preset. `1`: fps and fps lows. `2`: adds GPU and CPU load, power and temperature, driver and API. `3`: adds clocks, VRAM, version and present mode. `4`: adds present latency. `5`: full HUD without system info. Text after the comma is added to `DXVK_HUD`. An explicit `DXVK_HUD` wins |
| `DXVK_HUD=<items>` | DXVK's own HUD list |
| `PROTON_UPSCALER_INFO=1` (`upscalerinfo`) | Show upscaler and frame-generation watermarks (`FSR_WATERMARK`, `FSR_FG_WATERMARK`, NGX indicator options) |

#### Upscaling

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

#### Sync

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_NO_ESYNC=1` | `noesync` | Disable eventfd sync (`WINEESYNC=0`; otherwise 1) |
| `WINEESYNC` | | Set by the script |

#### Audio and media

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_USE_PIPEWIRE=1` | `pipewire` | PipeWire audio. Otherwise `WINE_AUDIO_DRIVER` defaults to `pulse,alsa` |
| `PROTON_ENABLE_MEDIACONV=1` | `mediaconv` | Media conversion switches |
| `PROTON_NATIVE_STEAM=1` | `nativesteam` | Use the native Steam client |

#### Input

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_PREFER_SDL=1`, `PROTON_USE_SDL=1` | `sdlinput` | SDL input |
| `PROTON_NO_STEAMINPUT=1`, `PROTON_EMULATE_STEAMINPUT=1` | | Steam Input switches |
| `SDL_GAMECONTROLLER_ALLOW_STEAM_VIRTUAL_GAMEPAD`, `SDL_GAMECONTROLLER_IGNORE_DEVICES` | | SDL hints |

#### GPU and vendor

| Option | Keyword | What it does |
|---|---|---|
| `PROTON_RADV=1` | | Use the bundled patched RADV Mesa driver (x86-64 only). The script logs the Mesa version and patch count and sets `PROTON_RADV_VERSION` |
| `PROTON_NVIDIA_LIBS`, `_NVCUDA`, `_NVENC`, `_NVML`, `_NVOPTIX`, `_LIBS_NO_32BIT` | `nvidialibs`, `nvcuda`, `nvenc`, `nvml`, `nvoptix`, `nvidialibsno32` | Nvidia libraries. NVML is on by default on Nvidia |
| `DXVK_NVAPI_VKREFLEX=1` | `vkreflex` | dxvk-nvapi Reflex layer |
| `DXVK_NVAPI_SET_NGX_DEBUG_OPTIONS` | | NGX debug options |
| `WINE_SIMULATE_WRITECOPY=1` | `writecopy` | Simulate write-copy |
| `WINE_GRAPHICS_DRIVER`, `WINE_USE_EGL` | | Set by the Wayland path |

#### Config file

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

#### Debugging

The shared options `PROTON_LOG`, `WINEDEBUG` and `PROTON_REMOTE_DEBUG_CMD` apply, plus `PROTON_HUD` and `DXVK_HUD` above.

### Best launch option and why

Not tested yet on this setup:

```
PROTON_UPSCALER_UPGRADE=1 WINE_FSR4_LITE=1 PROTON_UPSCALER_INFO=1 gamemoderun %command%
```

- Wayland is already on, so it does not need to be in the line.
- `PROTON_UPSCALER_UPGRADE=1` swaps the game's FSR, FFX, DLSS and XeSS components for newer ones. It only works if FSR is also selected in the game's own graphics menu.
- `WINE_FSR4_LITE=1` uses the lighter FSR4 model. It has no keyword, so it has to be set as a variable. The script already turns it on for some AMD GPUs, so on those cards it is redundant but does no harm.
- `PROTON_UPSCALER_INFO=1` shows a watermark when the upgraded upscaler is running. Use it to confirm the swap worked, then remove it.
- Add `PROTON_HUD=1` for an fps counter, or put these variables in `~/.config/proton/config.ini` so you don't have to repeat them for every game.

## What was left out

- Variables that only pass through to Wine or DXVK without the script acting on them are noted as such where they appear in a table.
- Per-game workarounds that the script sets for specific Steam app IDs are not listed, except in the GE section.
- The option lists read `proton` and the top-level `*.py` files. Wineland's `upscalers/` folder was read separately, which is why `PROTON_UPSCALER_UPGRADE` and the `WINE_*_PROVIDER` names appear only in the Wineland section.
