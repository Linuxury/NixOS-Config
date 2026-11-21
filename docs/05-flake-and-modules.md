# Flake and modules

`flake.nix` has three jobs: pin the inputs, define the `mkHost` helper, and list one `nixosConfigurations` entry per host. Everything else is a module that a host file imports.

## Flake inputs

`flake.lock` pins every input to an exact commit. Inputs marked "follows nixpkgs" reuse this flake's `nixpkgs`, so there is only one copy.

### Core

| Input | What it is for |
|---|---|
| `nixpkgs` | Package collection and NixOS modules, branch `nixos-unstable`, on every host |
| `home-manager` | Per-user configuration and dotfiles in Nix (follows nixpkgs) |
| `nixos-hardware` | Community hardware profiles for specific laptops and boards |
| `agenix` | Secret management with age encryption; decrypts with the host SSH key at activation (follows nixpkgs). See [06-secrets.md](06-secrets.md) |

### Applications and gaming

| Input | What it is for |
|---|---|
| `nixpkgs-goose` | Pinned older nixpkgs revision. `goose-cli` on unstable misses build dependencies, so goose comes from here (`modules/development/ai-tools/goose.nix`). The input and the override can go once unstable builds it |
| `affinity-nix` | Affinity v3 through a patched Wine. Its overlay is added only when `programs.affinity.enable` is set. No `follows`: it needs its own nixpkgs |
| `millennium` | Steam client mod that injects themes. Fetched only on hosts with `programs.steam.millennium.enable` (`modules/gaming/gaming.nix`). Pinned to a revision because newer ones fail the LuaJIT architecture check. No `follows` |
| `helium-browser` | Helium browser (Chromium-based, built-in ad blocking). Not in nixpkgs. Used by `modules/system/graphical/helium.nix` |
| `zen-browser` | Zen browser (Firefox-based). Not in nixpkgs. A host turns it on by importing `modules/system/graphical/zen-browser.nix` (follows nixpkgs) |
| `bedrock-on-linux` | Minecraft Bedrock launcher. Follows nixpkgs so its Mesa matches the system GPU driver. Pinned to a release tag because `main` can ask for a downloader that is not published |

### Desktop

| Input | What it is for |
|---|---|
| `noctalia` | Noctalia Shell, tracked directly instead of through nixpkgs release tags. Pinned to a revision because a newer upstream commit does not compile against nixpkgs' `sdbus-c++` (follows nixpkgs) |
| `noctalia-greeter` | greetd-based login greeter for Noctalia. Tracks the default branch (follows nixpkgs) |
| `umbriel` | Wayland compositor from the Noctalia authors. Tracks the default branch. The flake's own `nixosModules` and `homeModules` are used because nixpkgs has no `programs.umbriel` (follows nixpkgs) |

### Plain files (not flakes)

These have `flake = false`. They are fetched as source trees and read at build time.

| Input | What it holds |
|---|---|
| `zsh` | Shell config (`conf.d/*.zsh` including `nru`), starship and fastfetch configs |
| `assets` | Wallpapers, avatars, fastfetch art, SteamGridDB images, the Hytale bundle |
| `dotfiles` | Per-app configs (Hyprland, Neovim, Kitty and others). Build-time reads use this pin; live links use a clone at `~/dotfiles` (made by `home.activation.dotfilesClone` in linuxury's home config) |
| `upstream-skills` | Agent skill library (`github:sickn33/agentic-awesome-skills`), wired up in `modules/development/ai-tools/claude.nix` |
| `impeccable` | Design vocabulary skill (`github:pbakaus/impeccable`) |
| `claude-code-playground` | Claude Code plugin marketplace (`github:anthropics/claude-code-playground`) |

Update one input with `nix flake update <name>`, all of them with `nix flake update`. `nru` does the update for you, see [07-maintenance.md](07-maintenance.md).

## mkHost

Every host is built by one helper, `mkHost`, so the shared module list exists once.

| Argument | Meaning | Default |
|---|---|---|
| `hostname` | Network name, also passed to modules as `hostname` | required |
| `hostConfig` | Path to `hosts/<Host>/<Host>.nix` | required |
| `user` | Primary user on the machine | required |
| `userConfig` | Path to the user's Home Manager config. Servers pass none | `null` |
| `wallpaperDir` | Wallpaper folder from the `assets` input, linked to `~/Pictures/Wallpapers`. Values in use: `4k`, `3440x1440`, `PikaOS` | `"4k"` |
| `hypridleProfile` | `desktop` (no suspend) or `laptop` (suspend) | `"laptop"` |
| `extraModules` | Extra modules for one host (Asus-A15 adds `nixos-hardware.nixosModules.asus-battery`) | `[]` |

`mkHost` builds the system from these modules, in order:

1. The host platform (`x86_64-linux`).
2. The host file (`hostConfig`).
3. The `agenix` module, which provides `age.secrets.*`.
4. `modules/hardware/openrgb.nix` and `modules/hardware/peripherals/lemokey-keychron.nix`. Both are imported on every host and stay off until the host sets `hardware.openrgb.enable` or `hardware.lemokey-keychron.enable`.
5. `modules/users/uid-pin/uid-pin.nix`, which gives each person the same UID on every host and migrates an existing wrong UID at boot.
6. The Home Manager NixOS module.
7. The overlays (see below).
8. Home Manager settings: `useGlobalPkgs = true`, `useUserPackages = true`, `extraSpecialArgs` with `inputs`, `wallpaperDir` and `hypridleProfile`, and the user's config when `userConfig` is set.
9. `extraModules`.

`specialArgs` carries `inputs` and `hostname`, so any module can read an input or look up per-host data (`modules/system/build-capacity.nix` reads `hosts/<hostname>/specs.nix` this way).

### Hosts

| Host | user | userConfig | wallpaperDir | hypridleProfile |
|---|---|---|---|---|
| ThinkPad | linuxury | linuxury-home.nix | 4k | laptop |
| Ryzen5900x | linuxury | linuxury-home.nix | 3440x1440 | desktop |
| Ryzen5800x | babylinux | babylinux-home.nix | 4k | default |
| Asus-A15 | babylinux | babylinux-home.nix | 4k | default |
| Alex-Desktop | alex | alex-home.nix | PikaOS | default |
| Alex-Laptop | alex | alex-home.nix | PikaOS | default |
| Media-Server | linuxury | none | default | default |
| MinisForum | linuxury | none | default | default |
| Radxa-X4 | linuxury | none | default | default |

"default" means the argument is not set and `mkHost` uses its default.

### Checks

`checks.x86_64-linux.uid-migrate` is a VM test of the UID migration:

```sh
nix build -L .#checks.x86_64-linux.uid-migrate
```

## Overlays and `pkgs/`

`mkHost` adds two overlays to every host:

- Local packages built with `callPackage`: `ponytrail`, `ant-dark-kde`, `breeze-chameleon-dark-icons`, `breezex-cursors`.
- Hash fixes from `pkgs/hash-fixes.nix`. Each entry overrides one stale dependency hash (`pnpmDeps`, `npmDeps`, `cargoDeps`, `goModules`). `nru` adds and removes entries; see [07-maintenance.md](07-maintenance.md). The file is `{ }` when no fix is needed.

Other packages are added by the module that uses them, so a host that does not import the module never builds the package.

| Package in `pkgs/` | What it is | Added by |
|---|---|---|
| `ponytrail` | CLI that records why files changed, with local snapshot history and revert | `flake.nix` |
| `ant-dark-kde` | Ant-Dark KDE theme (Aurorae, Plasma theme, colour scheme, Kvantum style) | `flake.nix` |
| `breeze-chameleon-dark-icons` | Icon theme with adaptive folder colours for KDE Plasma | `flake.nix` |
| `breezex-cursors` | BreezeX cursor theme, a Breeze variant with larger sizes | `flake.nix` |
| `claude-desktop` | Claude Desktop for Linux, built from Anthropic's `.deb` | `modules/system/graphical/claude-desktop.nix` |
| `craft-apps` | The Craft application suites, built from upstream release tarballs | `modules/system/graphical/craft-apps.nix` |
| `mailcraft` | Desktop mail, calendar, contacts and tasks client. Version and hash in `mailcraft.json` | `modules/system/graphical/mailcraft.nix` |
| `proton-ge-custom` | GloriousEggroll's Proton build for Steam | `modules/gaming/gaming.nix` |
| `proton-cachyos` | CachyOS Proton build (nixpkgs has none) | `modules/gaming/gaming.nix` |
| `proton-wineland` | Proton Wineland, a CachyOS-based Proton with Wayland improvements | `modules/gaming/gaming.nix` |
| `dux-files` | Only `icon-refresh.patch`, applied to the nixpkgs `dux-files` package on Ryzen5900x | `hosts/Ryzen5900x/Ryzen5900x.nix` |
| `hash-fixes.nix` | The hash overrides described above | `flake.nix` |

The Proton tags and hashes live in `modules/gaming/gaming.nix`; `nru` rewrites them. See [10-gaming.md](10-gaming.md).

## How modules are turned on

A host file, `hosts/<Host>/<Host>.nix`, has an `imports` list. A module is on when its line is in the list and off when the line is removed or commented out:

```nix
imports = [
  ./disk.nix
  ../../modules/system/core.nix
  ../../modules/system/graphical/graphical.nix
  ../../modules/hardware/drivers.nix
  ../../modules/desktops/cosmic/cosmic.nix
  #../../modules/system/graphical/zen-browser.nix
];
```

Some modules also have options. The ones a host sets:

| Option | Defined in | Effect |
|---|---|---|
| `hardware.gpu` | `modules/hardware/drivers.nix` | `"amd"`, `"intel"` or `"nvidia-hybrid"`. No default: every host must set it, or evaluation fails |
| `hardware.openrgb.enable`, `hardware.lemokey-keychron.enable` | imported by `mkHost` | Turn on RGB lighting control or Lemokey/Keychron keyboard tools |
| `services.nixos-auto-update.*` | `modules/services/auto-update/auto-update.nix` | `enable`, `primaryUser`, `isPrimary`, `nixosConfigPath`, `schedule` |
| `services.vpn-qbittorrent.*` | `modules/services/vpn-qbittorrent.nix` | `enable`, `user`, `failoverServers`, `watchedFolder` and more |
| `craftApps.suites` | `modules/system/graphical/craft-apps.nix` | Which Craft app suites to install |
| `programs.affinity.enable` | `modules/system/graphical/affinity.nix` | Affinity v3 through Wine |
| `programs.steam.millennium.enable` | `modules/gaming/gaming.nix` | Millennium Steam mod |
| `programs.firefox.deSlop.enable` and the Zen and Helium equivalents | the browser modules | Managed privacy policy, default on |

`programs.hytale.enable` is a Home Manager option, set in the user's config rather than the host file (see below).

Some modules exist that no host imports (Hyprland, Niri, GNOME, Zen browser and others). Check a host's imports before assuming a module is active.

## Home Manager per user

Each desktop host gets one Home Manager config, from `userConfig` in its `mkHost` entry: `modules/users/<user>/<user>-home.nix`. The three files are `linuxury-home.nix`, `babylinux-home.nix` and `alex-home.nix`. Servers set none.

Home Manager modules are imported at the top of the user's home file. For example, all three users import `modules/system/graphical/hytale.nix` and set:

```nix
programs.hytale.enable = true;
```

The home file receives `wallpaperDir` and `hypridleProfile` from `extraSpecialArgs`. Some modules inject Home Manager config for linuxury from the system side, for example `modules/development/editors/neovim/neovim.nix` through `home-manager.users.linuxury.imports`.

Other per-user modules sit next to the home file:

| File | Purpose |
|---|---|
| `<user>-ssh.nix` | Deploys the user's authorized key from an agenix secret |
| `<user>-description.nix` | Sets the account's display name from an agenix secret; for linuxury and babylinux it also declares the git email secret. See [06-secrets.md](06-secrets.md) |
| `alex/screen-time.nix` | Login hours for the child account |

## Adding a new host

1. Create `hosts/<Host>/<Host>.nix`. Copy a similar host and change `networking.hostName`, `hardware.gpu` and the imports. Import `./disk.nix`.
2. Create `hosts/<Host>/disk.nix`. The NixOS-Installer writes it ([02-install.md](02-install.md)); by hand, see [03-install-manual.md](03-install-manual.md). Run `git add -N` on both files, because flakes ignore untracked files.
3. Add the entry to `flake.nix` under `nixosConfigurations`:

   ```nix
   NewHost = mkHost {
     hostname     = "NewHost";
     hostConfig   = ./hosts/NewHost/NewHost.nix;
     user         = "linuxury";
     userConfig   = ./modules/users/linuxury/linuxury-home.nix;
     wallpaperDir = "4k";
   };
   ```

4. Register the host key and add the host to the recipient lists of the secrets it needs: `add-host`, see [06-secrets.md](06-secrets.md).
5. Optionally run `scripts/host-specs.sh` on the machine and commit `hosts/<Host>/specs.nix`. Without it the host gets the lowest build-parallelism tier ([07-maintenance.md](07-maintenance.md)).
6. Check that it evaluates and builds, then install ([02-install.md](02-install.md)):

   ```sh
   nixos-rebuild dry-build --flake .#NewHost
   ```

## Where a package goes

| Scope | Where |
|---|---|
| Every graphical host | `environment.systemPackages` in `modules/system/graphical/graphical.nix` |
| One host | `environment.systemPackages` in `hosts/<Host>/<Host>.nix` |
| One user | `home.packages` in `modules/users/<user>/<user>-home.nix` |

Apply a change with `nr` (rebuild and switch) or `nrt` (activate without making it the boot default). Both come from the ZSH input ([07-maintenance.md](07-maintenance.md)).

Next: [06-secrets.md](06-secrets.md).
