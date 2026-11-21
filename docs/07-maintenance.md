# Maintenance

Day-to-day commands, the update tool, automatic updates, cleanup and snapshots.

## Rebuild commands

`nr`, `nrt` and `nru` are zsh functions from the ZSH flake input (`conf.d/nru/` in `github:Linuxury/ZSH`). They run in every interactive shell that loads it. All use the flake in `$NIXOS_CONFIG` and the machine's hostname.

| Command | What it does |
|---|---|
| `nr` | `sudo nixos-rebuild switch -L --no-link --flake $NIXOS_CONFIG#<hostname>`: build, activate now and make it the boot default |
| `nrt` | Same with `test`: activate now without adding a boot entry, so a reboot returns to the last switched generation. Use it to try risky changes |
| `nru` | Update everything, then rebuild (see below) |
| `nrr` | `sudo nixos-rebuild switch --rollback`: switch back to the previous generation |
| `ngens` | List system generations |
| `ngc` | `sudo nix-collect-garbage --delete-older-than 30d` |

`nr` and `nrt` run the build behind a progress display, save the log, and on failure print a short summary and keep the full log in `last-failure.log`.

## nru

`nru` takes no arguments. It pulls the repository, updates what this host may update, rebuilds and switches, then reports. Each step that fails offers only the options that make sense for that failure.

### Steps

| Group | Step | Runs |
|---|---|---|
| Flake | `git pull --ff-only` in the config repo | Always. If offline it asks whether to continue offline |
| Flake | `nix flake update` | Lock writer only. Shows how many inputs moved and which |
| Pinned | Proton builds (`proton-ge-custom`, `proton-cachyos`, `proton-wineland`) | When Steam is installed. Only the lock writer downloads and rewrites `modules/gaming/gaming.nix`; other hosts show "available" |
| Pinned | Craft apps (`pkgs/craft-apps/package.nix`) | When PhotoCraft is installed |
| Pinned | Claude Desktop (`pkgs/claude-desktop/package.nix`) | Where it is installed, or on the lock writer |
| Pinned | Plex, ZenNotes, MailCraft, VSCodium extensions | Lock writer only |
| Flatpak | `nixos-flatpak-update` for user and system scope | When `flatpak` exists |
| Rebuild | Build and switch, package diff (nvd), summary | Always |

After the switch, `nru` records auto-update markers, pushes pinned files (lock writer only), then checks `/nix` disk space, firmware updates (`fwupdmgr update`) and whether a reboot is needed. It offers to reboot now or later.

Offline hosts skip every update step and rebuild from what they have.

### The lock writer

Exactly one account owns the shared state: user `linuxury` on `Ryzen5900x`. That account updates `flake.lock`, bumps pinned versions and hashes, and pushes the result. Every other host only pulls. Two writers would make conflicting lock commits.

The role is hard-coded in `_nru_is_lock_writer` (`conf.d/nru/00-ui.zsh`). To move it, change the user and host names there.

### Pinned files

These files in the config repo are updated by `nru`. A previous-lock restore and the push step use the same list:

- `flake.lock`
- `modules/gaming/gaming.nix` (Proton tags and hashes)
- `pkgs/hash-fixes.nix`
- `pkgs/craft-apps/package.nix`
- `pkgs/claude-desktop/package.nix`
- `hosts/Media-Server/plex.json`
- `modules/services/zennotes/zennotes.json`
- `modules/development/editors/vscodium/extensions.json`

The lock writer commits changed pinned files with the message `flake: update inputs (<date>)` and pushes.

### When the rebuild fails

`nru` classifies the failure and shows a menu. The first entry is the default and is picked by Enter.

| Key | Action |
|---|---|
| `r` | Retry the rebuild (not the git pull or the input update) |
| `f` | Fix a stale dependency hash (see below) |
| `p` | Previous lock: restore all pinned files from git, then rebuild on the older lock |
| `l` | Show the full log |
| `g` | Collect garbage (`--delete-older-than 30d`), then retry. Offered when the disk is full |
| `q` | Quit |

Failure kinds, checked in order: `hash`, `hash-stale`, `hash-manual`, `disk`, `download`, `build`, `config`, `unknown`.

### The [F]ix hash flow

Sometimes a nixpkgs package fails with `hash mismatch in fixed-output derivation` because its dependency hash (`pnpmDeps`, `npmDeps`, `cargoDeps` or `goModules`) is stale. Choosing `f` edits `pkgs/hash-fixes.nix`, which the hash-fixes overlay in `flake.nix` applies ([05-flake-and-modules.md](05-flake-and-modules.md)):

- Kind `hash`: adds or replaces an entry `<pkg> = { attr = "<attr>"; hash = "<sri>"; added = "<date>"; };` for the failing package, then you retry.
- Kind `hash-stale`: the mismatch is on a hash already in the file, meaning nixpkgs caught up. `f` removes the entry.
- Kind `hash-manual`: `f` cannot target it; fix it by hand.

The file must keep one entry per line and `}` as its last line, because `nru` edits it line by line.

### Ctrl+C

Pressing Ctrl+C during `nru` offers to retry the rebuild or quit. It returns 130 on quit.

## Automatic updates

`modules/services/auto-update/auto-update.nix` runs updates without a person at the keyboard. Hosts that import it: ThinkPad, Ryzen5900x, Ryzen5800x, Alex-Desktop, Media-Server, MinisForum and Radxa-X4. Asus-A15 and Alex-Laptop do not.

Options (`services.nixos-auto-update.*`):

| Option | Default | Meaning |
|---|---|---|
| `enable` | `true` | Run the unattended timer and session-start service. Manual runs are unaffected |
| `primaryUser` | `linuxury` | The user who owns the machine. Notification and vault writes and the mail secrets are scoped to this user. Set to `babylinux` on Ryzen5800x and `alex` on Alex-Desktop |
| `isPrimary` | `false` | This host owns the nixpkgs update cycle. Set only on Ryzen5900x |
| `nixosConfigPath` | `/home/linuxury/nixos-config` | Local repo, used only when `isPrimary` is true |
| `schedule` | `*-*-* 03:00` | `OnCalendar` of the timer |

Per-host schedules are staggered so hosts do not all fetch at once: Media-Server 02:30, MinisForum 02:00, Radxa-X4 04:00, ThinkPad 03:30, Alex-Desktop 04:30. Others use the default.

### Two tiers

| Tier | Hosts | Behaviour |
|---|---|---|
| Primary | Ryzen5900x | No timer. Updates on demand, through `nru` or `nixos-auto-update [--force]`: pull, `nix flake update`, rebuild from the local repo, commit and push `flake.lock`, then notify |
| Non-primary | all others with auto-update | A timer (`system.autoUpgrade`) rebuilds from `github:linuxury/nixos-config` with a random delay of up to 45 minutes and no reboot. A user service also runs at graphical session start: it compares the GitHub HEAD with the last built revision and skips if they match and the last build is under 30 days old |

The timer service skips itself in the first 20 minutes after boot, to avoid racing an interactive `nru`. `nixos-auto-update` writes `/etc/nixos-last-update-time` and `/etc/nixos-last-update-rev`.

### Notifications and logs

After each unattended run, `notify-vault@` runs as the primary user and:

- Shows a desktop toast.
- Sends an ntfy push to `http://media-server:2586/nixos-updates` (the ntfy server runs on Media-Server).
- Sends an email on failure only, through msmtp (Gmail SMTP, password from `smtp-app-password`, address from `notify-email`). With no `notify-email` secret no email is sent.
- Calls `nixos-log-rebuild`, which writes the outcome to `~/Jarvis/Hosts/<hostname>.md` (entries older than 30 days are pruned) and puts actionable warnings in `PENDING.md`.

The raw log is `/var/log/nixos-auto-update.log`. Secrets involved: see [06-secrets.md](06-secrets.md).

## Garbage collection and generations

Set in `modules/system/core.nix`, for every host:

| Setting | Value |
|---|---|
| `nix.gc` | Weekly, `--delete-older-than 30d` |
| `nix.optimise.automatic` | On: hard-links identical store files |
| `boot.loader.systemd-boot.configurationLimit` | 10 generations in the boot menu |

`configurationLimit` applies to hosts that use systemd-boot. A host with GRUB, such as Alex-Desktop, sets its own loader in `disk.nix`.

Manual cleanup:

```sh
ngens        # list generations
ngc          # delete generations older than 30 days and collect garbage
```

## Snapshots

`modules/services/snapper.nix` is imported by `core.nix`, so it applies everywhere, and turns itself off when `/` is not Btrfs. It snapshots `/` and `/home` hourly and prunes on a timeline:

| Limit | Kept |
|---|---|
| Hourly | 8 |
| Daily | 7 |
| Weekly | 2 |
| Monthly, yearly | 0 |

Snapshots are root-only. A monthly Btrfs scrub runs on `/`. Useful commands:

```sh
sudo snapper -c root list
sudo snapper -c home list
sudo snapper -c root create --description "before update"
sudo snapper -c root undochange 5..0 /etc/someconfig
```

The first number pair is a snapshot range from `list`; `undochange` restores the files that changed between them.

## Helper scripts

Run from the repo root. Each rewrites its own pin file; commit and run `nru` yourself. `nru` runs most of them on the lock writer.

| Script | What it does |
|---|---|
| `scripts/plex-bump [public]` | Updates the Plex version pinned in `hosts/Media-Server/plex.json`. Default is the Plex Pass beta channel, which needs a Plex token; `public` uses the public channel |
| `scripts/mailcraft-bump` | Pins the newest MailCraft release in `pkgs/mailcraft/mailcraft.json`, taking the hash from the release's `SHA256SUMS.txt` |
| `scripts/zennotes-bump` | Pins the newest ZenNotes image tag from Docker Hub in `modules/services/zennotes/zennotes.json` |
| `scripts/vscodium-ext-bump` | Bumps the Open VSX extensions in `modules/development/editors/vscodium/extensions.json`. Entries with a `hold` reason are skipped |
| `scripts/host-specs.sh` | Writes `hosts/<this host>/specs.nix` (CPU threads and RAM), which `modules/system/build-capacity.nix` uses to set `max-jobs` and `cores`. Run once per machine, commit the result, and re-run if the hardware changes. A host without `specs.nix` gets the lowest tier (1 job, 2 cores) |
| `scripts/add-host`, `scripts/install-host` | Register a host key and install over SSH. See [06-secrets.md](06-secrets.md) |

Next: [08-servers.md](08-servers.md).
