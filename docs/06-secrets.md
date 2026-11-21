# Secrets

Secrets are encrypted with age and stored in `secrets/` as `.age` files. The repository holds only the encrypted files. The tool is **ragenix**, a Rust implementation of agenix. Run it with `nix run nixpkgs#ragenix`.

## How it works

- Each `.age` file is encrypted to a list of SSH public keys, its recipients.
- `secrets/secrets.nix` is the access list: it maps each file to its recipients.
- Two kinds of key are recipients. A **host key** (`/etc/ssh/ssh_host_ed25519_key.pub` on each machine) lets that machine decrypt its secrets at activation. A **personal key** lets an admin edit and re-key secrets.
- A host module declares a secret with `age.secrets.<name>.file = <path>.age;`. At activation agenix decrypts it with the host's SSH key to `/run/agenix/<name>`, or to the `path` the module sets.
- Only the secrets a host declares are decrypted there. A host can decrypt a secret only if its key is in that secret's recipient list.

The secret **name** (`<name>` in `age.secrets.<name>`) and the **file path** differ for some secrets. The runtime path always uses the name.

## The secrets tree

```
secrets/
  secrets.nix
  api-keys/       iteracompute.age  openrouter.age
  licenses/       flow-icons.age
  network/        mullvad-wireguard.age  smb-credentials.age  tailscale-auth-radxa.age
  notifications/  notify-email.age  smtp-app-password.age
  services/       freshrss-admin-password.age  nix-builder-key.age  zennotes-auth-token.age
  users/
    alex/         description.age
    babylinux/    authorized-key.age  description.age  git-email.age
    linuxury/     authorized-key.age  description.age  git-email.age
```

| File | Secret name (`/run/agenix/<name>`) | Used by | Recipients (besides admins) |
|---|---|---|---|
| `users/linuxury/authorized-key.age` | `linuxury-authorized-key`, placed at `/etc/ssh/authorized_keys.d/linuxury` | `linuxury-ssh.nix` | all hosts |
| `users/babylinux/authorized-key.age` | `babylinux-authorized-key`, placed at `/etc/ssh/authorized_keys.d/babylinux` | `babylinux-ssh.nix` | babylinux hosts, babylinux's personal key |
| `users/<user>/description.age` | `description-<user>` | `<user>-description.nix` | linuxury: ThinkPad, Ryzen5900x; babylinux: babylinux hosts; alex: Alex hosts |
| `users/<user>/git-email.age` | `git-email-<user>` | `linuxury-description.nix`, `babylinux-description.nix` | linuxury: ThinkPad, Ryzen5900x; babylinux: babylinux hosts. alex has none |
| `network/smb-credentials.age` | `smb-credentials` | CIFS mounts on every host, Samba clients | every host |
| `network/mullvad-wireguard.age` | `wireguard-vpnunlimited`, placed at `/etc/wireguard/vpnunlimited.conf` | `vpn-qbittorrent` on Radxa-X4 | Radxa-X4 |
| `network/tailscale-auth-radxa.age` | `tailscale-auth-radxa` | Tailscale login on Radxa-X4 | Radxa-X4 |
| `notifications/smtp-app-password.age` | `smtp-app-password` | msmtp in `auto-update.nix` | every host |
| `notifications/notify-email.age` | `notify-email` | update notification address | every host |
| `services/freshrss-admin-password.age` | `freshrss-admin-password` | `hosts/Media-Server/freshrss.nix` | Media-Server |
| `services/zennotes-auth-token.age` | `zennotes-auth-token` | ZenNotes server | Media-Server |
| `services/nix-builder-key.age` | `nix-builder-key` | `remote-builder.nix` | Radxa-X4, Media-Server, ThinkPad |
| `api-keys/iteracompute.age` | `iteracompute-api-key` | `ai-tools.nix`, `zed.nix` | every host |
| `api-keys/openrouter.age` | `openrouter-api-key` | opencode on ThinkPad and Ryzen5900x | ThinkPad, Ryzen5900x |
| `licenses/flow-icons.age` | `flow-icons-license` | VSCodium and VS Code settings | ThinkPad, Ryzen5900x |

"Every host" means the personal admin keys plus the host keys in `linuxury-machines`, `babylinux-machines` and `alex-machines`.

The Mullvad secret keeps the name `wireguard-vpnunlimited` and the path `vpnunlimited.conf`. The file holds a Mullvad WireGuard config.

### Names and emails

Real names and email addresses are not in the repository.

- **Display names.** `modules/users/<user>/<user>-description.nix` decrypts `description-<user>` and writes it into the account's full-name field with `usermod`, in an activation script that runs after agenix and after the users are updated. Without it, NixOS would blank the field on every rebuild.
- **Git email.** `programs.git.includes` in `linuxury-home.nix` and `babylinux-home.nix` points at `/run/agenix/git-email-<user>`. The secret holds a `[user]` section with the address, and is owned by the user with mode `0400`. The git name is set in the home file.
- **Update notifications.** The sender and recipient address come from `notify-email`. Without that secret no email is sent.

## Recipients and groups in `secrets.nix`

`secrets.nix` defines keys first, then groups, then the file-to-recipient map.

| Name | Meaning |
|---|---|
| `linuxury-personal`, `thinkpad-personal`, `ryzen5900x-personal`, `minisforum-personal`, `media-server-personal` | Personal keys of the admin on each machine |
| `ryzen5800x-personal` | babylinux's personal key, used for babylinux's authorized-key secret |
| `<Host>` (capitalised, such as `ThinkPad`) | The SSH host key of that machine |
| `linuxury-admins` | Personal keys that can re-key: `linuxury-personal`, `thinkpad-personal`, `ryzen5900x-personal`, `minisforum-personal` |
| `linuxury-machines` | ThinkPad, Ryzen5900x, MinisForum, Radxa-X4, Media-Server |
| `babylinux-machines` | Ryzen5800x, Asus-A15 |
| `alex-machines` | Alex-Desktop, Alex-Laptop |

Every secret includes `linuxury-admins`, so an admin machine can always re-key. A typical entry:

```nix
"network/smb-credentials.age".publicKeys = uniq (
  linuxury-admins ++ [ ThinkPad Ryzen5900x ] ++ babylinux-machines ++ alex-machines
);
```

`uniq` removes duplicate keys, which ragenix would reject.

`nix-builder-key` is deliberately not given to the Alex hosts or Asus-A15. The matching public key makes `nixbuilder` on MinisForum a trusted user, so the private key is root-equivalent there. Only add hosts you control.

## Create or edit a secret

Run ragenix from the `secrets/` directory, because it reads `secrets.nix` from the current directory. It opens `$EDITOR` and encrypts on save:

```sh
cd ~/nixos-config/secrets
nix run nixpkgs#ragenix -- -e network/smb-credentials.age
```

Shortcuts: `age-edit <file>` runs `ragenix -e` and `age-rekey` runs `ragenix -r`. On linuxury's and babylinux's desktops they are zsh-abbr abbreviations that run in `~/nixos-config/secrets` by themselves; on the servers they are plain aliases, so run them from `secrets/`.

To fill a secret from a file instead of an editor, use `cp` as the editor:

```sh
cd ~/nixos-config/secrets
EDITOR="cp /tmp/new-value.txt" nix run nixpkgs#ragenix -- -e network/mullvad-wireguard.age
```

You can only edit a secret if your own key is a recipient of it. Admin machines are, for every secret.

To create a new secret:

1. Add an entry for the file to `secrets.nix` with its recipients.
2. Run the `ragenix -e` command above for the new path.
3. Declare it in a host or module: `age.secrets.<name>.file = ../../secrets/<dir>/<file>.age;`. Add `owner` and `mode` if a non-root service reads it.
4. Read it at `config.age.secrets.<name>.path`, never by hand-writing `/run/agenix/...` when a module can use the option.
5. `git add -N` the new `.age` file before evaluating, because flakes ignore untracked files.

Re-key after you change any recipient list:

```sh
cd ~/nixos-config/secrets
nix run nixpkgs#ragenix -- -r
```

Then commit the changed `.age` files and `secrets.nix`, and push.

## Add or re-key a host: `add-host`

`add-host` registers a host's SSH host key in `secrets.nix`, re-keys every secret, commits and pushes. Run it on an admin machine, one whose personal key is in `linuxury-admins`. It is on the PATH on ThinkPad and Ryzen5900x; elsewhere run `scripts/add-host`.

```sh
add-host <Host> '<ssh-ed25519 key>'
add-host --no-push <Host> '<ssh-ed25519 key>'
```

The key is the machine's public host key, for example from `ssh-keyscan -t ed25519 <ip>`. The installer prints the exact command at its Secrets step. The script needs a clean `secrets/` tree and pulls with rebase first.

| Case | What `add-host` does |
|---|---|
| Reinstall of a host already in `secrets.nix` | Replaces its key line, re-keys every secret, commits and pushes (`--no-push` stops after the commit) |
| New host | Adds the key line and stops. Add the host to the recipient lists of the secrets it needs in `secrets.nix`, then run `add-host` again to re-key, commit and push |

After the push, the installer's "pull the re-keyed secrets" step picks the new keys up.

A new host needs these entries in `secrets.nix`, at least:

- Its key line, which `add-host` creates.
- Membership in the right group (`linuxury-machines`, `babylinux-machines` or `alex-machines`) if the secrets list the group.
- Its name in the lists of any secret that names hosts one by one (display name, git email, API keys, builder key).

## Install a host over SSH: `install-host`

`install-host` runs the NixOS-Installer on a machine booted from the live ISO, driven from an admin machine over SSH. It registers the host key first, so nothing is copied by hand. It is on the PATH on ThinkPad and Ryzen5900x; elsewhere run `scripts/install-host`.

On the target: boot the live ISO, connect to the network and set a password for the `nixos` user with `passwd`.

```sh
install-host <ip>                      # run the installer remotely
install-host <ip> <Host>               # also create and register the host key
install-host <ip> <Host> -- --hub      # pass arguments to the installer
```

With a host name, the script:

1. Generates a new SSH host key on the admin machine.
2. Runs `add-host` with its public half (re-key and push).
3. Copies the key to `/tmp/nixos-install-hostkey/` on the ISO (root-owned, mode `0600`).
4. Starts the installer. At its Secrets step pick "I ran add-host - pull the re-keyed secrets".

Then it deletes its local copy of the private key on exit. For a new host `add-host` stops early (recipient lists first); the key is still copied, so after you edit `secrets.nix` and run `add-host` again the keys match.

SSH agent forwarding lets the installer push `hosts/<Host>/disk.nix` back to the repo. Host-key checking is off for this session only, because a live ISO makes a new SSH host key on every boot.

The installer itself is described in [02-install.md](02-install.md). The by-hand route is [03-install-manual.md](03-install-manual.md), and the first-boot checklist is [04-first-boot.md](04-first-boot.md).

## Rotating a secret

Edit the file with `ragenix -e`, commit, push, and rebuild each host that uses it. Rotate the secret at its source as well (a Mullvad config, a Tailscale key, an app password).

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| A secret is missing under `/run/agenix/` | The host is not a recipient, or the file was not re-keyed after the host was added. Run `add-host`, pull, rebuild |
| `ragenix` cannot find `secrets.nix` | Run it from `secrets/` |
| `ragenix` rejects the key list | Duplicate keys. Wrap the list in `uniq` |
| Evaluation cannot find a new `.age` file | Run `git add -N` on it; flakes ignore untracked files |
| Cannot decrypt when editing | Your key is not a recipient, or you are not using the key that matches |
