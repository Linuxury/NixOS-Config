# Applications

What is installed, and where it comes from. A host gets an application when its host file imports the module, so the tables below list imports per host. Gaming is in [10-gaming.md](10-gaming.md), desktops in [12-desktops.md](12-desktops.md), and themes in [13-theming.md](13-theming.md).

## Which host imports what

| Host | Browsers | Fluxer | Craft apps | Other graphical apps |
|---|---|---|---|---|
| ThinkPad | Firefox | yes | all suites except `ai` | Thunderbird, ZenNotes, Claude Desktop, MailCraft, KDE Connect |
| Ryzen5900x | Firefox | yes | all suites except `ai` | Thunderbird, ZenNotes, Claude Desktop, MailCraft, KDE Connect |
| Ryzen5800x | Firefox, Helium | yes | all suites except `ai` | ZenNotes, KDE Connect |
| Asus-A15 | Firefox, Helium | yes | `office`, `photo`, `graphics`, `3d` | KDE Connect |
| Alex-Desktop | Firefox | yes | none | none |
| Alex-Laptop | Firefox | yes | `office` | none |

Servers import none of these. Hytale is enabled per user, not per host (see below).

| Host | Development modules |
|---|---|
| Ryzen5900x | AI tools (Claude Code, OpenCode, Goose), Neovim, VSCodium, VS Code, Zed, Python, Rust |
| ThinkPad | AI tools (Claude Code, OpenCode), Zed, Python |
| Ryzen5800x | AI tools (Claude Code, OpenCode), Zed |
| Media-Server, MinisForum, Radxa-X4 | AI tools base and Claude Code |
| Asus-A15, Alex-Desktop, Alex-Laptop | none |

## Graphical base

`modules/system/graphical/graphical.nix` is imported by every desktop and laptop host and by no server. It does not depend on the desktop environment. It provides:

- Flatpak, the Flathub remote and the update timers (see Flatpak below).
- GVfs for browsing network shares, plus `samba` client tools.
- Packages: Kitty (primary terminal), Showtime (video), Gapless (music), Loupe (images), Papers (documents), Neovim (fallback editor), Mission Center (system monitor), `wl-clipboard`, `xdg-utils`, `eza` and `tuios`.
- Default applications through Home Manager: Nautilus for folders, Loupe for images, Showtime for video, Gapless for audio, Papers for PDF and e-books, Neovim in Kitty for text files.
- Shared keybinds (`keybinds.nix`), login avatars from the `assets` input (`user-avatars.nix`), a fast-fail check for the Torrents CIFS automount (`torrents-precheck.nix`) and the inactive Affinity module (`affinity.nix`, see below).

Not imported by it, so chosen per host: Firefox, Helium, Fluxer, OpenRGB, KDE Connect, Lemokey/Keychron, Zen browser, Zed and LM Studio.

## Browsers

| Browser | Module | Source | Hosts |
|---|---|---|---|
| Firefox | `firefox.nix` | nixpkgs | All desktop and laptop hosts |
| Helium | `helium.nix` | `helium-browser` flake input (Chromium-based, not in nixpkgs) | Ryzen5800x, Asus-A15 |
| Zen | `zen-browser.nix` | `zen-browser` flake input (Firefox-based, for linuxury) | No host imports it |

Firefox, Zen and Helium each have a `deSlop` option, on by default, that applies a managed policy from the `dotfiles` input: telemetry off, built-in AI and the password manager off, uBlock Origin and Proton Pass force-installed, uBlock preloaded with a hardened filter list and a YouTube Shorts hider. Set `programs.firefox.deSlop.enable = false` (or the Zen or Helium equivalent) to opt out.

Firefox also gets a pywalfox native messaging manifest and the dotfiles `userChrome.css`. The Helium desktop entry passes `--password-store=gnome-libsecret` so Helium uses the unlocked keyring. Helium may not read the standard Chromium policy path; check `chrome://policy` and `chrome://extensions` after enabling it.

The uBlock list in `dotfiles/chromium/policies.json` and the Firefox policy must be kept in sync by hand.

## Fluxer

`fluxer.nix` installs `pkgs.fluxer-canary-bin` from nixpkgs, a self-hostable chat client. It is the canary (pre-release) channel, the only Fluxer package in nixpkgs, and it moves with the flake inputs. The stable channel exists only on Flathub as `app.fluxer.Fluxer`. Every desktop and laptop host imports it.

## Hytale

`modules/system/graphical/hytale.nix` is a Home Manager module. Hytale is not on Flathub, so a user service installs the launcher on first login:

1. It downloads `hytale-launcher-latest.flatpak` from `launcher.hytale.com`, retrying for about a minute while the network comes up.
2. It installs it with `flatpak install --user` (Flathub is added as a user remote for the runtime) and deletes the download.
3. It skips itself once `com.hypixel.HytaleLauncher` is installed. The launcher then updates itself.

On every rebuild the module sets Flatpak overrides: `ELECTRON_OZONE_PLATFORM_HINT=x11` (avoids a blank window on COSMIC), `--device=input` for controllers, and `--filesystem=/run/udev:ro` for SDL2.

Enable it per user in the home file:

```nix
imports = [ ../../system/graphical/hytale.nix ];
programs.hytale.enable = true;
```

linuxury, babylinux and alex all enable it. Hytale detects Xbox, PlayStation and Switch pads but not a Steam Controller, because it has no Steam Input translation.

## Craft apps

`craft-apps.nix` installs the Craft application suites. They are not in nixpkgs; `pkgs/craft-apps/package.nix` builds them from upstream release tarballs, and `nru` bumps the versions ([07-maintenance.md](07-maintenance.md)). The suites mirror Microsoft and Adobe tools:

| Suite | Apps |
|---|---|
| `office` | WordCraft, GridCraft, DeckCraft, PdfCraft |
| `photo` | PhotoCraft, LightCraft |
| `graphics` | VectorCraft, DesignCraft, FigCraft |
| `3d` | TextureCraft, MaterialCraft |
| `video` | FilmCraft, EffectCraft, AniCraft |
| `audio` | SoundCraft |
| `cad` | CADCraft |
| `ai` | ArtCraft, Craft Anything (opt in only) |

The option is `craftApps.suites`. The default is every suite except `ai`. Alex-Laptop sets `[ "office" ]`, and Asus-A15 sets `[ "office" "photo" "graphics" "3d" ]`.

On hosts that also import `claude-desktop.nix`, each installed app's `<app>-cli mcp` server is added to Claude Desktop's config. Each app reads only its own type folder (`~/Pictures`, `~/Documents`, `~/Videos` or `~/Music`) and writes only to a `Craft/` folder inside it, so originals cannot be overwritten. LightCraft, FilmCraft, GridCraft, CADCraft and Craft Anything take no root flags and are unconfined; their folder only decides where `Craft/` is created.

## Affinity

`affinity.nix` (imported by `graphical.nix`) is off by default. Set `programs.affinity.enable = true` on a host to install Affinity v3 through Wine, using the `affinity-nix` input. No host sets it.

## MailCraft

`mailcraft.nix` installs MailCraft, a mail, calendar, contacts and tasks client that supports Microsoft accounts. `pkgs/mailcraft` builds it from the upstream release. The version and hash are in `mailcraft.json`, bumped by `scripts/mailcraft-bump`. Imported by ThinkPad and Ryzen5900x.

## Thunderbird

`thunderbird.nix` installs Thunderbird and makes it the default handler for mail, calendar, contacts, feeds and news. It is imported by ThinkPad and Ryzen5900x, and the defaults exist only where it is installed.

## Claude Desktop

`claude-desktop.nix` installs Claude Desktop from Anthropic's `.deb` (`pkgs/claude-desktop`). Sign-in needs a Secret Service provider, and the Hyprland, Niri, Umbriel and COSMIC modules enable `gnome-keyring`. For linuxury, a filesystem MCP server named `vault` is added to Claude Desktop's config, giving chat read access to `~/Jarvis`, `~/.agents/Shared` and `~/.agents/memory`, and not to the rest of `~/.agents`. Imported by ThinkPad and Ryzen5900x.

## ZenNotes client

`app-zennotes.nix` installs `zennotes-desktop`, a keyboard-first Markdown notes app. Connect it with Settings, Connect to Remote Vault, `http://Media-Server:7879`, and the token from the `zennotes-auth-token` secret. The server is described in [08-servers.md](08-servers.md). Imported by ThinkPad, Ryzen5900x and Ryzen5800x.

## Editors and development tools

All under `modules/development/`, imported per host.

| Module | What it does |
|---|---|
| `editors/neovim/neovim.nix` | Neovim for linuxury through Home Manager (`neovim-hm.nix`) |
| `editors/vscodium/vscodium.nix` | VSCodium for linuxury. Extensions are pinned in `extensions.json` and bumped by `scripts/vscodium-ext-bump` |
| `editors/vscode/vscode.nix` | VS Code (Microsoft build) with the same base settings. The flow-icons licence key comes from a secret |
| `editors/zed.nix` | Zed, with the `iteracompute-api-key` secret and `nixd` |
| `languages/python.nix` | Python environment with common development packages |
| `languages/rust.nix` | `rustup`; run `rustup default stable` after the first rebuild |
| `ai-tools/ai-tools.nix` | Base for the AI tools: `nix-ld`, `uv`, `ffmpeg`, the `iteracompute-api-key` secret |
| `ai-tools/claude.nix` | Claude Code CLI and the agent skill setup for every Home Manager user on the host |
| `ai-tools/opencode.nix` | OpenCode, a terminal coding agent |
| `ai-tools/goose.nix` | Goose, driving Claude Code through an adapter. Built from the pinned `nixpkgs-goose` input |

Kitty is the primary terminal and Neovim the primary editor. Ryzen5900x uses Luciole (`modules/system/graphical/luciole.nix`) as its default file manager and file picker (the only file manager installed there).

Modules that exist but no host imports: `ai-tools/local-llm.nix` (Ollama on demand), `ai-tools/lm-studio.nix`.

## Flatpak

Flatpak is enabled by `graphical.nix` on every graphical host.

- **Remote.** A system activation script adds the `flathub` remote and repairs a Flathub remote that lacks its signing key.
- **Updates.** `nixos-flatpak-update --user|--system` is the shared updater. `nru` runs it, and two timers run it every Sunday at 04:00, one per scope (`Persistent`, so a missed run happens at the next boot).
- **Hytale.** The Hytale launcher is skipped by the updater, because the install deletes its origin remote. It updates itself.
- **Child-account hosts.** Alex-Desktop and Alex-Laptop keep the `flatpak` command but remove every system remote on each rebuild, so the app store is empty. Updates skip where Flathub is absent.

Next: [10-gaming.md](10-gaming.md).
