# First boot

<!-- NixOS-Installer parses this file (install.sh checklist): keep "## All Machines", "## <HostName>" sections and "### step" headings. -->

Steps to do after the first boot of a freshly installed host, whether it was installed with the [installer](02-install.md) or [by hand](03-install-manual.md). Work through "All Machines" in order, then the section for your host. Log in as the host's primary user (`linuxury`, `babylinux` or `alex`) with the password set during the install. Headless servers (Media-Server, MinisForum, Radxa-X4) are reached over SSH as `linuxury`.

## All Machines

### Set user passwords

Users are mutable: NixOS does not set passwords from the config, and the repo holds no password hashes. Set each password by hand on each host.

```bash
sudo passwd <user>
```

SSH accepts keys only (`PasswordAuthentication = false` in `modules/system/core.nix`), so a password never works over the network. It is for the console, the greeter and `sudo`. Never put a password in the repo.

### Register the host key in secrets.nix and apply secrets

Secrets are encrypted to each host's SSH host key. If the key was registered and the secrets re-keyed before the install, this is done. Otherwise add the host's public key to `secrets/secrets.nix` on the admin machine, re-key from the `secrets/` directory, push, and pull on this host:

```bash
cat /etc/ssh/ssh_host_ed25519_key.pub      # on the new host
cd ~/nixos-config/secrets
nix run nixpkgs#ragenix -- -r              # on the admin machine
```

The full procedure is in [06-secrets.md](06-secrets.md).

### First rebuild

```bash
sudo nixos-rebuild switch --flake ~/nixos-config#<host>
```

On hosts with the shared zsh config, `nr` runs the same command for the current hostname:

| Command | What it does |
|---------|--------------|
| `nr` | `sudo nixos-rebuild switch` for this host |
| `nrt` | Test rebuild: activates now, not added to the boot menu |
| `nru` | Pull the repo, update inputs, rebuild |

If you cloned the repo as root, fix ownership: `sudo chown -R <user>:users ~/nixos-config`.

### Sign in to Tailscale

Tailscale is enabled on every host (`services.tailscale.enable` in `modules/system/core.nix`). Sign in once:

```bash
sudo tailscale up
tailscale status
```

Media-Server adds `--advertise-tags=tag:ssh` automatically through `services.tailscale.extraUpFlags`. Radxa-X4 joins the tailnet by itself with an auth key from the `tailscale-auth-radxa` secret, so it needs no manual `tailscale up`.

### Add the Syncthing device

Syncthing is declared in `modules/services/syncthing.nix` (all hosts except babylinux's) and `modules/services/syncthing-babylinux.nix` (Ryzen5800x, Asus-A15). Folders and known devices are in the config, so a host that is already listed needs no pairing.

For a brand-new host, find its device ID, add it to the module, then rebuild the other machines:

```bash
systemctl status syncthing | grep -i "device id"   # or open http://localhost:8384
```

For the babylinux hosts, fill in the device ID in `syncthing-babylinux.nix` and rebuild both machines.

### Set up Git over SSH (admin machines)

On linuxury's machines, create an SSH key, add it to GitHub, and use SSH for the repo remote so `git push` works:

```bash
ssh-keygen -t ed25519
cat ~/.ssh/id_ed25519.pub      # add to GitHub
ssh -T git@github.com
git -C ~/nixos-config remote set-url origin git@github.com:Linuxury/nixos-config.git
```

To let this machine re-key secrets, add its personal key to `secrets/secrets.nix` as described in [06-secrets.md](06-secrets.md).

## ThinkPad

### Enroll a fingerprint

The ThinkPad has a fingerprint reader (`services.fprintd.enable` in `hosts/ThinkPad/ThinkPad.nix`). Enroll a finger, then it works for `sudo` and the login screen:

```bash
fprintd-enroll
```

## Asus-A15

### Fill in the PRIME bus IDs

Hybrid graphics on the Asus-A15 needs the PCI bus IDs of the AMD and Nvidia GPUs. The `hardware.nvidia.prime` block in `hosts/Asus-A15/Asus-A15.nix` is commented out until they are filled in.

```bash
lspci | grep -E "VGA|3D"
```

Convert each ID to Nix format (`05:00.0` becomes `PCI:5:0:0`), put them in `amdgpuBusId` and `nvidiaBusId`, uncomment the block, and rebuild.

### Set the battery charge limit

```bash
asusctl -c 80
```

## Media-Server

### Set Samba passwords

Samba passwords are separate from the Linux password:

```bash
sudo smbpasswd -a linuxury
sudo smbpasswd -a babylinux
sudo smbpasswd -a alex
```

### Complete Plex setup

Open `http://Media-Server:32400/web` and finish setup. In the settings, enable Hardware-Accelerated Transcoding (`vainfo` checks VAAPI), and point the libraries at `/data/media/movies`, `/data/media/tv` and so on.

## Radxa-X4

### Set Samba passwords

```bash
sudo smbpasswd -a linuxury
sudo smbpasswd -a babylinux
```

### Change the qBittorrent login

qBittorrent runs inside the WireGuard namespace (`modules/services/vpn-qbittorrent.nix`). Open `http://10.200.200.2:8080` from a machine that can reach it, log in with the default `admin` / `adminadmin`, and change the password in Settings.

## MinisForum

### Set Samba passwords

```bash
sudo smbpasswd -a linuxury
sudo smbpasswd -a babylinux
```

### Change the Crafty login

Crafty Controller manages the Minecraft Java and Hytale servers. Open `https://MinisForum:8443` (or use the Tailscale address) and change the default login on first use.

## Checklist

- [ ] Password set for each user
- [ ] Host key registered in `secrets/secrets.nix` and secrets re-keyed
- [ ] `nr` completes without errors
- [ ] `sudo tailscale up` done (not needed on Radxa-X4)
- [ ] Syncthing device ID added where needed
- [ ] Host section above finished

Details of each server are in [08-servers.md](08-servers.md). For problems, see [14-troubleshooting.md](14-troubleshooting.md).
