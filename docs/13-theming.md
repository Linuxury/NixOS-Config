# Theming

Where colours, cursors, icons, avatars and wallpapers come from. Desktops are in [12-desktops.md](12-desktops.md).

## Summary

| Host type | Colours come from | Tool |
|---|---|---|
| Ryzen5900x (Umbriel and Noctalia) | The current wallpaper | Noctalia templates, plus matugen for Kvantum |
| COSMIC hosts (ThinkPad, Alex-Desktop, Alex-Laptop) | The COSMIC wallpaper | matugen, via `wallpaper-slideshow.nix` |
| KDE hosts (Ryzen5800x, Asus-A15) | KDE's own settings | No wallpaper-driven theming in this repo |

Every host with a graphical session also gets the shared cursor, icons and GTK base from `modules/themes/gtk.nix`.

## Noctalia (Ryzen5900x)

`modules/shells/noctalia/shell-noctalia.nix` sets Noctalia to dark mode with colours taken from the wallpaper (`theme.source = "wallpaper"`). Noctalia's built-in templates theme most apps: kitty, GTK, Qt, starship, Umbriel, pywalfox and Papirus icons. Thunderbird follows through pywalfox.

Two templates are added by this repo:

| Template | What it does |
|---|---|
| `dux-files` | Renders Noctalia's palette into `~/.cache/dms/dms-colors.json` so the Dux Files app follows the wallpaper |
| `led-sync` | Only when `hardware.openrgb.enable` is set on the host. Renders the primary colour as a hex and runs `led-sync` |

### led-sync

`modules/shells/noctalia/color-sync/led-sync.sh` pushes the primary colour to RGB hardware:

- Every device the local OpenRGB server knows (port 6742).
- A wired Lemokey P1 HE keyboard over VIA raw HID.
- Material primaries are pale and look white on LEDs, so saturation is raised to at least `LED_MIN_SAT` (default 200 of 255) and brightness is set to maximum.
- Each step ignores errors, so a missing server or keyboard is skipped.

### Wallpaper handoff

Noctalia's `wallpaper_changed` hook writes `~/.local/share/current-wallpaper`. The matugen path unit in `theme-matugen.nix` watches that file.

## matugen for Kvantum (Umbriel)

`modules/themes/theme-matugen.nix` themes Kvantum, the one thing Noctalia has no template for.

| Unit | What it does |
|---|---|
| `matugen.service` | Reads the wallpaper path, takes a dominant colour (a hint file if present, otherwise ImageMagick), runs `matugen color hex`, copies the wallpaper to the SDDM background folder if it exists, and skips a wallpaper it already processed |
| `matugen.path` | Runs the service when `current-wallpaper` changes |
| `matugen.timer` | Runs it once 10 seconds after the session starts |

`~/.config/matugen/config.toml` has two Kvantum templates (config and SVG). The Qt side comes from `umbriel-themes.nix`: Kvantum plus `qt6ct`, with `qt6ct.conf` managed by Nix and pointing at Noctalia's colour file.

The log is `~/.local/share/wallpaper-service.log`.

## COSMIC: slideshow and matugen

`modules/services/wallpaper-slideshow.nix` is added to every user on a COSMIC host by `cosmic.nix`. It does not rotate wallpapers. COSMIC's own slideshow does that (COSMIC Settings, Desktop, Wallpaper). This module handles colours:

- `wallpaper-color-sync.path` watches `~/.config/cosmic/com.system76.CosmicBackground/v1`.
- `wallpaper-color-sync.timer` also runs it 30 seconds after boot and every 10 minutes.
- The service runs matugen on the current wallpaper. Templates for COSMIC, GTK, kitty, btop, Zed, starship and pywalfox are rendered, and each template's post-hook reloads its app.
- Templates are cloned from `InioX/matugen-themes` into `~/.config/matugen/templates` when the folder is missing.

`modules/desktops/cosmic/cosmic-themes.nix` adds COSMIC-specific parts on top of the GTK base: the window button layout, COSMIC toolkit icon and cursor files, COSMIC Files sidebar favourites for the network shares, and a hidden Blueman entry.

## GTK, cursor and icons

`modules/themes/gtk.nix` has no enable flag. The compositor and desktop theme modules import it, and removing the import turns it off.

| Part | Value |
|---|---|
| Cursor | BreezeX-Light, from `pkgs/breezex-cursors`. Set for Wayland, GTK and the X11 fallback |
| GTK theme | `adw-gtk3-dark` |
| Icons | Papirus-Dark |
| Dark mode | `color-scheme = prefer-dark` in dconf for libadwaita apps |
| Window buttons | dconf button layout, so Firefox's window buttons match |

On COSMIC hosts a pre-activation step removes `~/.config/gtk-4.0/gtk.css`, because COSMIC apps rewrite it on every launch and it would clash with Home Manager.

Two more icon packs exist as packages in `pkgs/`: `breeze-chameleon-dark-icons` and `ant-dark-kde`.

## User avatars

`modules/system/graphical/user-avatars.nix` is imported by `graphical.nix`, so it runs on every graphical host. On each activation it copies the avatar for each user from the `Avatar/` folder of the `assets` flake input to two places:

- `/var/lib/sddm-faces/<user>.face.icon`, which SDDM reads.
- `/var/lib/AccountsService/icons/`, plus a matching entry under `/var/lib/AccountsService/users/`. cosmic-greeter and GDM read these.

## Wallpapers

`modules/users/wallpapers.nix` is imported by each user's Home Manager config. It fills a real folder, `~/Pictures/Wallpapers`, from `Wallpapers/<wallpaperDir>` in the `assets` input:

- It copies only files that are not there yet.
- Files you add are never touched, and files you edit are never overwritten.
- A repo wallpaper you delete comes back on the next rebuild.
- New wallpapers pushed to the Assets repo reach each machine after `nix flake update assets` and a rebuild. `nru` does both.

`wallpaperDir` is set per host in `flake.nix`:

| Host | `wallpaperDir` |
|---|---|
| ThinkPad, Ryzen5800x, Asus-A15 | `4k` |
| Ryzen5900x | `3440x1440` |
| Alex-Desktop, Alex-Laptop | `PikaOS` |
