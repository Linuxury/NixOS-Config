# Servers

Three headless hosts, all administered over SSH by linuxury. None has Home Manager, a desktop or audio. Each imports `core.nix`, `server-shell.nix` (the shared zsh setup, so `nr`, `nrt` and `nru` work), the drivers module, Claude Code, Samba, Syncthing, auto-update and linuxury's SSH key. Sleep, suspend and lid actions are disabled on all three.

| Host | Hardware | GPU | Role |
|---|---|---|---|
| Media-Server | AMD Ryzen 5 3600X, Radeon RX 480 | `amd` | Plex, Arr stack, Immich, FreshRSS, ZenNotes server, ntfy, file shares |
| MinisForum | Intel Core i5-1250P (UN1250) | `intel` | Game servers (Crafty Controller), remote Nix builder |
| Radxa-X4 | Intel N100 | `intel` | Torrents behind a WireGuard killswitch |

Addresses in the host files: Media-Server `10.0.0.3`, Radxa-X4 `10.0.0.5`. Update timers are staggered (see [07-maintenance.md](07-maintenance.md)).

## Samba

`modules/services/samba.nix` is the shared base: user-level security, no guest access, SMB2 and SMB3 only, and the firewall ports for SMB (TCP 139 and 445, UDP 137 and 138). It defines no shares; each host defines its own.

Samba passwords are separate from Linux passwords. After the first boot, set them on each server:

```sh
sudo smbpasswd -a linuxury
sudo smbpasswd -a babylinux
sudo smbpasswd -a alex        # only on Media-Server (see below)
```

| Server | Share | Path | Valid users |
|---|---|---|---|
| Media-Server | `Media-Server` | `/data` | linuxury, babylinux, alex |
| Media-Server | `Downloads` | `/data/downloads` | linuxury, babylinux, alex |
| MinisForum | `GameServers` | `/data/gameservers` | linuxury, babylinux |
| Radxa-X4 | `Torrents` | `/data/torrents` | linuxury, babylinux |

Clients mount the shares by CIFS with the `smb-credentials` secret, automount and a 60-second idle timeout. The mount points are `/mnt/Media-Server`, `/mnt/MinisForum` and `/mnt/Torrents` on the hosts that declare them. See [06-secrets.md](06-secrets.md).

## Tailscale

`core.nix` enables Tailscale on every host. After the first boot run `sudo tailscale up` once.

- Media-Server and MinisForum add `--advertise-tags=tag:ssh`.
- Radxa-X4 logs in unattended with the `tailscale-auth-radxa` secret and sets `--ssh=false`. A `tailscale-watchdog` timer runs every 5 minutes (first run 2 minutes after boot) and restarts `tailscaled` if a `tailscale ping` to the host's own name fails.

## Media-Server

Storage:

- OS disk: NVMe, Btrfs (`disk.nix`).
- `/data`: two HDDs (`/mnt/disk1`, `/mnt/disk2`) pooled by mergerfs into one mount. New files go to the drive with the most free space, and at least 10 GB stays free on each.
- `/data/downloads` is a CIFS mount of `//10.0.0.5/Torrents` from Radxa-X4. Sonarr and Radarr need a remote path mapping from `/data/torrents/complete` to `/data/downloads/complete`.
- `/data/media` holds `movies`, `tv`, `anime`, `music` and `books`. `/data/photos` is Immich's library. `/data/config/<service>` holds service state.

Groups: `media` (shared by Plex, Sonarr, Radarr, Lidarr, Readarr, Bazarr, Prowlarr, linuxury, babylinux), and `immich` (linuxury, babylinux). alex is in `media` only. Samba and the services share files through the `media` group.

Services and ports (all TCP, opened in the firewall unless noted):

| Service | Port | Notes |
|---|---|---|
| Plex | 32400 | Hardware transcoding through VAAPI on the RX 480. The plex user is in the `render` and `video` groups. Version pinned in `hosts/Media-Server/plex.json` |
| Prowlarr | 9696 | |
| Sonarr | 8989 | |
| Radarr | 7878 | |
| Lidarr | 8686 | |
| Readarr | 8787 | |
| Bazarr | 6767 | |
| Immich | 2283 | Library at `/data/photos`; create the admin account at first login. UMask forced to `0022` so Samba can read what Immich writes |
| FreshRSS | 8080 | nginx on all interfaces, defined in `hosts/Media-Server/freshrss.nix`. Admin password from the `freshrss-admin-password` secret |
| ZenNotes server | 7879 | Container (host 7879 to container 7878). Vault is `~/Jarvis` of linuxury; token from the `zennotes-auth-token` secret. Image tag pinned in `modules/services/zennotes/zennotes.json` |
| ntfy | 2586 | Push notifications; the update notifier posts to topic `nixos-updates` ([07-maintenance.md](07-maintenance.md)) |
| Syncthing | 22000 TCP and UDP, 21027 UDP | |

PostgreSQL 16 with `pgvector` also runs (`services.postgresql`). Network buffers and BBR congestion control are tuned in `boot.kernel.sysctl`.

Check VAAPI with `vainfo`, then enable hardware transcoding in Plex.

## MinisForum

Game-server host.

- **Crafty Controller** runs in Docker (`registry.gitlab.com/crafty-controller/crafty-4`, auto-start, always pulls the latest image). Its web UI is `https://MinisForum:8443` (or the Tailscale name) with a self-signed certificate. Change the default login on first use.
- Crafty manages the Minecraft Java servers and the Hytale server. A `crafty-update` timer restarts the container every Monday at 04:00.
- Data lives under `/data/gameservers/crafty/` (`servers`, `backups`, `config`, `logs`, `import`). Drop server ZIPs in `import/` to import them.

| Port | Protocol | Use |
|---|---|---|
| 8443 | TCP | Crafty web UI |
| 25565 | TCP | Minecraft Java server |
| 25566 | TCP | Minecraft Java server |
| 24454 | UDP | Simple Voice Chat |
| 5520 | UDP | Hytale (QUIC) |
| 445, 139 / 137, 138 | TCP / UDP | Samba |

To expose a new server port, add it to the container's `ports` and to the firewall lists in `hosts/MinisForum/MinisForum.nix`.

Users: linuxury and babylinux are in the `docker` group. alex has no extra groups.

### Remote builder

MinisForum (16 threads, 31 GB RAM, always on) is the builder for low-memory hosts.

- It has a `nixbuilder` account with one authorized SSH key, and `nixbuilder` is a trusted Nix user on this host. That makes its key root-equivalent here, so only hosts you control may hold the matching private key.
- The private key is the `nix-builder-key` secret, readable by Radxa-X4, Media-Server and ThinkPad ([06-secrets.md](06-secrets.md)).
- `modules/system/remote-builder.nix` is the client side. It is imported only by Radxa-X4. It pins MinisForum's host key, sets `nix.distributedBuilds`, and sends builds to `nixbuilder@minisforum` over `ssh-ng` with `maxJobs = 2` and the `big-parallel` and `kvm` features. If MinisForum is unreachable, the build falls back to running locally.
- `modules/system/build-capacity.nix` (imported by `core.nix`) sets `max-jobs` and `cores` per host from `hosts/<Host>/specs.nix`, written by `scripts/host-specs.sh`. Radxa-X4 (4 cores, 7 GB) gets 1 job of 4 cores. Hosts without `specs.nix` get 1 job of 2 cores.

## Radxa-X4

Dedicated torrent host. Two network paths on purpose:

- `enp2s0` (Ethernet): LAN only, static `10.0.0.5/24`, no default route, no DHCP. Carries Samba, SSH and Tailscale.
- `wlp1s0` (Wi-Fi): managed by NetworkManager, holds the default route, and is what WireGuard uses to reach the VPN.

IPv6 is disabled.

### qBittorrent behind WireGuard

`modules/services/vpn-qbittorrent.nix` runs `qbittorrent-nox` inside a network namespace named `vpn-qbt`. The only default route inside the namespace is the WireGuard interface `wg-qbt`, so if the tunnel drops qBittorrent has no connectivity and nothing leaks.

- A veth pair links the host (`10.200.200.1`) to the namespace (`10.200.200.2`). The WireGuard endpoint is reached through it with masquerade on the host.
- The Web UI is on port 8080 inside the namespace. The host forwards TCP 8080 to it with `socat` and opens the port in the firewall.
- The default login is `admin` with a temporary password in the journal. Set a permanent password in Settings.
- The WireGuard config (a Mullvad config, wg-quick format) comes from the `wireguard-vpnunlimited` secret, placed at `/etc/wireguard/vpnunlimited.conf` with mode `0600`.
- Options set on this host: `user = "linuxury"`, `watchedFolder = "/data/torrents/queued"` (`.torrent` files dropped there are added), and `failoverServers`. `failoverServers` lists `us-atl-wg-001`, `us-dal-wg-001`, `us-nyc-wg-301`, `us-chi-wg-201` and `us-lax-wg-001`. When the tunnel fails its check, the failover script skips the endpoint in use and tries the others from the list. A health check runs 2 minutes after boot and then every 5 minutes.
- Downloads go to `/data/torrents/incomplete` and `/data/torrents/complete`. Media-Server mounts the share as `/data/downloads`.

### Other behaviour

- Samba serves `Torrents` only on `lo` and `enp2s0`. Firewall: TCP 445 and 139, UDP 137 and 138, plus 8080 from the VPN module.
- `daily-reboot` reboots at 06:00 (with up to 5 minutes of jitter) as a backstop.
- `wifi-watchdog` checks the Wi-Fi link every minute against `1.1.1.1` and `8.8.8.8`, tries to reconnect twice with `nmcli`, then reboots.
- It mounts `/mnt/Media-Server` from `//10.0.0.3/Media-Server`.
- Users: linuxury (wheel, `networkmanager`, `gpio`) and babylinux (`networkmanager`).

## First boot of a server

1. `sudo tailscale up` (not needed on Radxa-X4, which uses an auth key).
2. Set Samba passwords with `smbpasswd -a`.
3. Clone the config repo to `~/nixos-config` and check ownership.
4. Follow [04-first-boot.md](04-first-boot.md) for the rest of the checklist.

Next: [09-applications.md](09-applications.md).
