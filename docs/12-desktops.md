# Desktops

Each graphical host picks one desktop by importing its module in the host file. Themes are in [13-theming.md](13-theming.md).

## Which host uses what

| Host | Desktop | Login screen | Default session |
|---|---|---|---|
| ThinkPad | COSMIC | cosmic-greeter | COSMIC |
| Alex-Desktop | COSMIC | cosmic-greeter | COSMIC |
| Alex-Laptop | COSMIC | cosmic-greeter | COSMIC |
| Ryzen5800x | KDE Plasma | SDDM | `plasma` |
| Asus-A15 | KDE Plasma | SDDM | `plasma` |
| Ryzen5900x | Umbriel compositor with the Noctalia shell | Noctalia greeter | `umbriel` |

Servers have no desktop.

## COSMIC

`modules/desktops/cosmic/cosmic.nix`. System76's desktop, packaged in nixpkgs, with its own greeter.

- Turns on `services.desktopManager.cosmic` and the Wayland data-control protocol, so the clipboard applet works.
- Adds two Home Manager modules to every user on the host: `modules/services/wallpaper-slideshow.nix` and `modules/desktops/cosmic/cosmic-themes.nix` (see [13-theming.md](13-theming.md)).
- Wallpaper rotation is COSMIC's own slideshow, set in COSMIC Settings, Desktop, Wallpaper.

## KDE Plasma

`modules/desktops/kde.nix`. Plasma 6 on Wayland.

- Imports `modules/greeters/sddm.nix`, so the login screen is SDDM. KDE makes the SDDM greeter run on `kwin_wayland` instead of weston.
- Sets `QT_QPA_PLATFORMTHEME` to `kde` for the session and clears it for the greeter. The NixOS default (`gtk2`) crashes `kwin_wayland` and the Qt 6 greeter.
- Removes `/etc/sddm.conf.d/kde_settings.conf` on every rebuild. System Settings writes that file when you open Login Screen, and it would override the declared theme.
- The host sets `services.displayManager.defaultSession = "plasma"`.

## Umbriel and Noctalia (Ryzen5900x)

Three parts, all imported by the host:

| Part | File | What it is |
|---|---|---|
| Compositor | `modules/compositors/umbriel/umbriel.nix` | Umbriel, a wlroots compositor with scrolling, dwindle and master layouts. Enabled with `programs.umbriel.enable`. The flake module adds the session, the systemd service and the portal |
| Shell | `modules/shells/noctalia/shell-noctalia.nix` | Noctalia, a C++ Wayland shell: bar, launcher, lock screen, idle handling, wallpaper and theming. It runs as a systemd user service |
| Greeter | `modules/greeters/greeter-noctalia.nix` | A greetd greeter with its own wlroots compositor. The shell module imports it. Default session is Umbriel |

Details:

- Noctalia rotates wallpapers from `~/Pictures/Wallpapers` every 30 minutes, in random order, subfolders included.
- Noctalia owns idle handling: lock after 15 minutes, screen off after 26, no suspend on this desktop.
- The greeter uses the BreezeX-Light cursor. Its colour scheme is `Synced`, and the sync is manual: Settings, Security, Noctalia Greeter, "Sync Now".
- `umbriel.nix` adds `umbriel-themes.nix` and `modules/themes/theme-matugen.nix` for users. They theme Qt apps (see [13-theming.md](13-theming.md)).

## Available, not used by any host

These modules exist and their imports are commented out in every host file:

| Module | What it is |
|---|---|
| `modules/compositors/hyprland/` | Hyprland with its own theme and matugen modules |
| `modules/compositors/niri.nix` | Niri |
| `modules/desktops/gnome/` | GNOME and its theme module |
| `modules/shells/wayle.nix` | The wayle shell |
| waybar, wofi, swaync | Bar, launcher and notification modules under `modules/components/` |

They are kept for later and are not tested with the current hosts.

## Switch a host's desktop

Change the import in the host file and rebuild.

1. In `hosts/<host>/<host>.nix`, comment out the current desktop import and uncomment or add the new one. A shell needs its compositor: Noctalia goes with Umbriel.
2. Set `services.displayManager.defaultSession` if the host needs it (`plasma` or `umbriel`).
3. `git add` any new file, then `nrt` to try it without a boot entry, then `nr`.

See [05-flake-and-modules.md](05-flake-and-modules.md) for how imports work.
