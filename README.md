# nixos-config

A multi-host NixOS flake for a home network: desktops, laptops and headless servers. One repository builds every machine. Each host picks the shared modules it needs. Home Manager configures the desktop users.

## Hosts

| Host | Role | Desktop | Users |
|---|---|---|---|
| ThinkPad | Laptop (LUKS, TLP) | COSMIC | linuxury |
| Ryzen5900x | Desktop | Umbriel compositor + Noctalia shell | linuxury |
| Ryzen5800x | Desktop | KDE Plasma | babylinux, linuxury (admin) |
| Asus-A15 | Gaming laptop (LUKS, hybrid GPU) | KDE Plasma | babylinux, linuxury (admin) |
| Alex-Desktop | Desktop, child account | COSMIC | alex, linuxury (admin) |
| Alex-Laptop | Laptop, child account | COSMIC | alex, linuxury (admin) |
| Media-Server | Headless: Plex, Arr stack, Immich, FreshRSS, file sharing | none | linuxury (SSH) |
| MinisForum | Headless: game servers | none | linuxury (SSH) |
| Radxa-X4 | Headless: torrents behind a WireGuard VPN | none | linuxury (SSH) |

Hyprland, Niri and GNOME modules exist but no host imports them (available, not used by any host).

## Get started

- Install with the NixOS-Installer from the live ISO: [docs/02-install.md](docs/02-install.md).
- Install by hand (partition, `disk.nix`, `nixos-install`): [docs/03-install-manual.md](docs/03-install-manual.md).
- After the first boot: [docs/04-first-boot.md](docs/04-first-boot.md).

## Rebuild

On a configured machine, `nru` pulls the repo, updates the flake inputs and rebuilds. To rebuild without it:

```sh
sudo nixos-rebuild switch --flake .#<host>
```

Replace `<host>` with a host name from the table, for example `.#ThinkPad`. To check a change without activating it, use `nixos-rebuild dry-build --flake .#<host>`.

## Docs

| Doc | Contents |
|---|---|
| [01-overview](docs/01-overview.md) | Hosts, repo layout, how a host is assembled |
| [02-install](docs/02-install.md) | Install with the NixOS-Installer |
| [03-install-manual](docs/03-install-manual.md) | Install by hand |
| [04-first-boot](docs/04-first-boot.md) | Steps after the first boot |
| [05-flake-and-modules](docs/05-flake-and-modules.md) | The flake, `mkHost` and the module system; adding hosts and users |
| [06-secrets](docs/06-secrets.md) | agenix secrets and host keys |
| [07-maintenance](docs/07-maintenance.md) | Updates, cleanup, rollbacks |
| [08-servers](docs/08-servers.md) | The three headless servers |
| [09-applications](docs/09-applications.md) | Installed applications |
| [10-gaming](docs/10-gaming.md) | Gaming setup |
| [11-proton-launch-options](docs/11-proton-launch-options.md) | Proton launch options |
| [12-desktops](docs/12-desktops.md) | COSMIC, KDE Plasma, Umbriel and the unused desktops |
| [13-theming](docs/13-theming.md) | Themes and wallpapers |
| [14-troubleshooting](docs/14-troubleshooting.md) | Common problems and fixes |

## Layout

```
flake.nix   inputs and one nixosConfigurations entry per host
hosts/      one folder per host
modules/    shared modules, grouped by category
pkgs/       local packages
scripts/    maintenance scripts
secrets/    agenix-encrypted secrets
docs/       documentation
```
