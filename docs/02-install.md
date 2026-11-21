# Install with the NixOS-Installer

The NixOS-Installer is the recommended way to install a host. It is a separate project with its own in-depth docs: <https://github.com/Linuxury/NixOS-Installer>.

## What it does

- Scans the real disks and asks which to use, with the filesystem, boot loader, encryption and swap.
- Writes `hosts/<host>/disk.nix` and `install.json` for the machine, then partitions, formats and installs.
- Offers two config sources: a starter flake for a first host, or this repository's hosts (it clones the repo and adds the disk layout to an existing host).
- Sets up the secrets and the host key, so the machine can decrypt its agenix secrets.
- Logs every step to `/tmp/nixos-install.log`. A failed phase continues with `--resume` without re-partitioning.

Nothing is changed until you confirm at the Review step and type the hostname.

## Start it

Boot the NixOS live ISO, get a network connection, then run:

```sh
sudo nix run github:Linuxury/NixOS-Installer
```

Useful options, passed after `--`:

| Option | Effect |
|---|---|
| `--hub` | One main menu; open any step in any order |
| `--config answers.json` | Replay a saved answers file |
| `--resume` | Re-run the install from the failed phase |
| `--demo` | Run every menu and print the result without touching disks |
| `--fake-disks 3-mixed` | Demo with simulated disks |

Example: `sudo nix run github:Linuxury/NixOS-Installer -- --hub`.

Choose this repository's hosts at the first screen to install one of the hosts listed in the [README](../README.md).

## Install by hand

To partition and install without the installer, follow [03-install-manual.md](03-install-manual.md). After either method, continue with [04-first-boot.md](04-first-boot.md).
