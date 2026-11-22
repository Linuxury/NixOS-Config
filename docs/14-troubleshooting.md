# Troubleshooting

Problems that match the current setup, grouped by area. Secrets problems are also in [06-secrets.md](06-secrets.md), rebuild menus in [07-maintenance.md](07-maintenance.md), and server details in [08-servers.md](08-servers.md).

## Install and boot

| Symptom | Cause and fix |
|---|---|
| `nixos-install` says the repository is not owned by the current user | Git's ownership check, because root runs it on a repo cloned by another user. Run `git config --global --add safe.directory /mnt/home/$NIXUSER/nixos-config` and retry ([03-install-manual.md](03-install-manual.md)) |
| Cannot SSH to a machine that was just installed | Check Tailscale is up (`sudo tailscale status`), the user's SSH key secret decrypted (`/etc/ssh/authorized_keys.d/<user>` exists), and port 22 is open. Do the first-boot steps in [04-first-boot.md](04-first-boot.md): secrets need the host key registered first |
| A secret is missing right after the first boot | The host key is not in `secrets.nix` yet. Register it, re-key, pull and rebuild ([06-secrets.md](06-secrets.md)) |
| Files are owned by the wrong user or UIDs differ between machines | UIDs are pinned: linuxury 1000, babylinux 1001, alex 1002 (`modules/users/uids.nix`, applied by `modules/users/uid-pin`). On a host installed before the pin, `uid-migrate.service` fixes it once, early in a boot. Check with `id linuxury` and `journalctl -b -u uid-migrate`. Files restored from a snapshot made before the migration keep the old UID: `chown` them |
| A server's repo was cloned as root and gives permission errors | `sudo chown -R linuxury:users ~/nixos-config` |

## Rebuild and `nru`

| Symptom | Cause and fix |
|---|---|
| `flake does not provide attribute` | The host name after `#` does not match a `hostname` in `flake.nix`. Names are case-sensitive: `ThinkPad`, not `thinkpad` |
| A new file is not seen by the build | Flakes ignore untracked files. Run `git add -N <file>` |
| `hash mismatch in fixed-output derivation` | A pinned or fetched file changed upstream. `nru` classifies it and offers `[F]ix hash` or the previous lock. See [07-maintenance.md](07-maintenance.md) |
| `nru` stops after a failure | Pick from its menu: `r` retry, `f` fix hash, `p` previous lock, `l` full log, `g` collect garbage (offered when the disk is full) |
| The Nix store is full | `ngc` (garbage collect, older than 30 days) or `nru` and `g`. Then `sudo nix-store --optimise` |
| `checkLinkTargets` fails: a file Home Manager wants already exists | The error names it. Move it aside (`mv <file> <file>.bak`) and rebuild |
| `checkLinkTargets` fails for `~/.config/gtk-4.0/gtk.css` on a COSMIC host | COSMIC apps rewrite that file on launch. A pre-activation step removes it; if it still fails, `rm -f ~/.config/gtk-4.0/gtk.css` and rebuild |
| A rebuild changed something and you want it back | `nrr` switches to the previous generation. `nrt` tries a change without adding a boot entry |

## Secrets

| Symptom | Cause and fix |
|---|---|
| A secret is missing under `/run/agenix/` | The host is not a recipient, or the file was not re-keyed after adding the host. Run `add-host`, pull, rebuild |
| `ragenix` cannot find `secrets.nix` | Run it from `secrets/` |
| `ragenix` rejects the key list | Duplicate keys. Wrap the list in `uniq` |
| Evaluation cannot find a new `.age` file | `git add -N` it |
| Cannot decrypt while editing | Your key is not a recipient, or you are using a key that does not match |

## Network and mounts

| Symptom | Cause and fix |
|---|---|
| Tailscale is connected but a host name does not resolve | DNS may lag. Use the Tailscale IP from `sudo tailscale status` |
| A CIFS mount fails with `mount error(13): Permission denied` | The Samba user has no password on the server. On the server run `sudo smbpasswd -a <user>`. Check that `/run/agenix/smb-credentials` decrypted |
| A CIFS mount hangs or times out | The server is off or Samba is down. Mounts are automounts with `nofail`, so they never block boot: they mount on first access. Check `ping <server>` and `sudo systemctl status samba` on the server |
| The NTFS drive on Ryzen5800x does not mount, or says "can't find FUSE helper" | NTFS must use `fsType = "ntfs3"` (the kernel driver) with `boot.supportedFilesystems.ntfs = true`. The FUSE `ntfs-3g` helper is not available to systemd mount units |
| Media-Server is missing a drive in `/data` | mergerfs keeps running on the remaining drive. Check `lsblk`, `dmesg` and `sudo smartctl -a /dev/sdX`. Replace the drive, label it, and restart the mount |
| Radxa-X4: qBittorrent has no connectivity or DHT | The WireGuard handshake may have failed at start. `sudo systemctl restart vpn-qbt-netns` (this restarts `qbittorrent-vpn` too), then `sudo wg show` |
| Radxa-X4: qBittorrent crashes with a proxy set | Leave the proxy blank in qBittorrent. The killswitch already sends all traffic through the VPN |
| Radxa-X4 shows offline in Tailscale | A watchdog (`tailscale-watchdog`) pings every 5 minutes and restarts `tailscaled`. To force it: `sudo systemctl restart tailscaled` |
| A server service failed | `systemctl --failed`, then `journalctl -u <service> -n 100` |

## Desktop

| Symptom | Cause and fix |
|---|---|
| COSMIC restarts its session in a loop | A corrupted COSMIC config, often the wallpaper one. From a TTY (`Ctrl+Alt+F3`): `rm -rf ~/.config/cosmic/com.system76.CosmicBackground/` and `systemctl --user restart cosmic-session`. Set the wallpaper again in COSMIC Settings. Look at `journalctl --user -u cosmic-session -n 100` first |
| COSMIC Files shows no or old network shares | Favourites are written by Home Manager. Rebuild with `nr`. Shares whose server is off are skipped, which is expected |
| Display scaling is wrong after the first boot | COSMIC keeps scaling per monitor. Set it in COSMIC Settings, Displays |
| COSMIC colours do not follow the wallpaper | The unit `wallpaper-color-sync` runs matugen. Check `systemctl --user status wallpaper-color-sync` and `~/.local/share/wallpaper-slideshow.log`. To force a run, remove `~/.local/share/last-matugen-wallpaper` and restart the unit |
| Ryzen5900x: Qt apps keep an old colour scheme | Kvantum is themed by `matugen.service`. Check `systemctl --user status matugen` and `~/.local/share/wallpaper-service.log`. To force a run, remove `~/.local/share/last-matugen-processed` and restart it |
| KDE login screen goes back to the Breeze theme | Opening System Settings, Login Screen writes `/etc/sddm.conf.d/kde_settings.conf`. The next rebuild deletes it. Do not use that settings page; set the theme in `modules/greeters/sddm.nix` |
| Noctalia greeter colours are old | The greeter scheme is `Synced` by hand: Settings, Security, Noctalia Greeter, "Sync Now" |

## Gaming

| Symptom | Cause and fix |
|---|---|
| A Steam game will not start | Switch the Proton build (Properties, Compatibility; see [10-gaming.md](10-gaming.md)). Add `PROTON_LOG=1 %command%` and read `~/steam-<appid>.log` |
| A new Proton build does not show in Steam | The three bundled builds are linked by Home Manager into `~/.local/share/Steam/compatibilitytools.d/`. Rebuild and restart Steam |
| A launch option does nothing | Check the build reads it: [11-proton-launch-options.md](11-proton-launch-options.md). Unknown `PROTON_ADD_CONFIG` keywords are dropped without an error |
| `PROTON_ADD_CONFIG=hdr` does nothing | Proton-CachyOS and Valve Proton have no `hdr` keyword. Use Proton-GE |
| In-game HDR checkbox is greyed out on Proton-GE | The compositor is not advertising HDR. Set `hdr = "auto"` on the output in Umbriel's `outputs.toml`, and use `PROTON_ADD_CONFIG=...,hdr,wayland` |
| MangoHud does not appear | The launch option is `MANGOHUD=1 %command%`, and it is case-sensitive. Some anti-cheat games block overlays |
| Minecraft (Prism) drops frames | Steam's overlay hooks the JVM. Prism here is wrapped to unset `LD_PRELOAD`, so start Minecraft from the Prism launcher entry installed by this config |
| Steam Controller or other pad not recognised | `sc-controller` does not autostart: `systemctl --user start scc-daemon`. The Steam Controller Puck is handled by Steam Input, not `sc-controller` |
| Asus-A15 games run on the AMD GPU | The Nvidia PRIME block is not configured yet. Fill the bus IDs in `hosts/Asus-A15/Asus-A15.nix` ([04-first-boot.md](04-first-boot.md)) |
| Millennium theme or plugin is missing after a Steam reset | Millennium files are seeded only when absent. Delete the file in `~/.config/millennium` or `~/.local/share/millennium` to seed it again on the next rebuild |

## Useful commands

```bash
nixos-rebuild list-generations                # generations (or ngens)
systemctl --failed                            # failed system units
systemctl --user --failed                     # failed user units
journalctl -b -p err                          # errors this boot
nix store diff-closures <old> <new>           # what changed between two generations
```
