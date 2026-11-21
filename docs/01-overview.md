# Overview

This repository is a multi-host NixOS flake. `flake.nix` defines one `nixosConfigurations` entry per host. Shared behavior lives in `modules/`, and each host chooses what it uses.

## Hosts

| Host | Role | Desktop | GPU | Home Manager user |
|---|---|---|---|---|
| ThinkPad | Laptop (LUKS, TLP power management) | COSMIC | AMD | linuxury |
| Ryzen5900x | Desktop | Umbriel compositor + Noctalia shell | AMD | linuxury |
| Ryzen5800x | Desktop | KDE Plasma | AMD | babylinux |
| Asus-A15 | Gaming laptop (LUKS, hybrid graphics) | KDE Plasma | AMD (Nvidia dGPU not configured yet) | babylinux |
| Alex-Desktop | Desktop, child account | COSMIC | AMD | alex |
| Alex-Laptop | Laptop, child account | COSMIC | AMD | alex |
| Media-Server | Headless: Plex, Arr stack, Immich, FreshRSS, Samba | none | AMD | none |
| MinisForum | Headless: Crafty Controller and game servers | none | Intel | none |
| Radxa-X4 | Headless: torrents behind WireGuard | none | Intel | none |

- linuxury is the admin on every host. Child-account and babylinux hosts hide linuxury from the login screen (`hiddenUsers`).
- Servers have no Home Manager and are administered over SSH by linuxury.
- Hyprland, Niri and GNOME modules exist but no host imports them (available, not used by any host).

## Repository layout

| Path | Contents |
|---|---|
| `flake.nix` | Inputs, the `mkHost` helper, one entry per host |
| `flake.lock` | Pinned input versions |
| `hosts/` | One folder per host |
| `modules/` | Shared NixOS and Home Manager modules |
| `pkgs/` | Local packages and overlays |
| `scripts/` | Update helpers (`host-specs.sh`, `plex-bump`, `mailcraft-bump`, `zennotes-bump`, `vscodium-ext-bump`) |
| `secrets/` | agenix-encrypted secrets and `secrets.nix` |
| `docs/` | This documentation |

### `modules/` categories

| Directory | What lives there |
|---|---|
| `components/` | Desktop parts: bar, launcher, notifications |
| `compositors/` | Hyprland, Niri and Umbriel |
| `desktops/` | COSMIC, GNOME and KDE Plasma |
| `development/` | AI tools, editors (Neovim, VS Code, VSCodium, Zed), languages (Python, Rust) |
| `gaming/` | Gaming stack, controller support, dmemcg-booster |
| `greeters/` | Login screens (Noctalia greeter, SDDM) |
| `hardware/` | GPU drivers, OpenRGB, peripherals |
| `services/` | Auto-update, Samba, Syncthing, Snapper, ntfy, KDE Connect, VPN for qBittorrent, wallpaper slideshow, ZenNotes |
| `shells/` | Desktop shells: Noctalia, wayle |
| `system/` | Core settings, remote builder, build capacity, server shell, and `graphical/` (apps and settings for graphical hosts) |
| `themes/` | GTK and matugen theming |
| `users/` | Per-user modules (`alex`, `babylinux`, `linuxury`), UID pinning, wallpapers |

Some modules exist but no host imports them. Check a host's imports before assuming a module is active.

## How a host is assembled

1. `flake.nix` calls `mkHost` with the host name, its host file, a primary user, and optionally a Home Manager config, `wallpaperDir` and `hypridleProfile`.
2. `mkHost` builds the system from the host file plus common modules: agenix, Home Manager, the UID pin module, the hardware modules and the package overlays.
3. The host file `hosts/<host>/<host>.nix` has an `imports` list. Turning a module on or off means adding or commenting out its line.
4. `hosts/<host>/disk.nix` holds disks, swap, LUKS and the boot loader. The NixOS-Installer writes it (see [02-install.md](02-install.md)).
5. For desktop hosts, `mkHost` also loads one Home Manager config, `modules/users/<user>/<user>-home.nix`. Servers set none.

Most host folders also hold `specs.nix`, the measured CPU and RAM used by `modules/system/build-capacity.nix` (written by `scripts/host-specs.sh`). Media-Server has extra files for its services (`freshrss.nix`, `plex.json`).

## Per-host vs shared

| Kind | Where |
|---|---|
| Host name, GPU, which desktop, which modules | `hosts/<host>/<host>.nix` |
| Disks, boot loader, encryption, swap | `hosts/<host>/disk.nix` |
| Anything used by more than one host | `modules/<category>/` |
| Per-user settings and dotfiles | `modules/users/<user>/` |
| Local packages | `pkgs/` |
| Encrypted secrets | `secrets/` |

Next: [05-flake-and-modules.md](05-flake-and-modules.md) for the flake in detail, [06-secrets.md](06-secrets.md) for secrets.
