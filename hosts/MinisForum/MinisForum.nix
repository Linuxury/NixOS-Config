# ===========================================================================
# hosts/MinisForum/MinisForum.nix — MinisForum UN1250 game server
#
# Hardware: Intel Core i5-1250P, Intel Iris Xe integrated graphics
# Type: headless server with no desktop environment and no display manager
# Role: game server host
#   - Crafty Controller (Docker, web UI on port 8443). It manages the Minecraft Java
#     servers and the Hytale server (QUIC/UDP 5520).
#       Access: https://MinisForum:8443 (or over Tailscale)
#       Change the default Crafty login on first use.
#
# Storage layout (under /data/gameservers/crafty/):
#   servers/  Crafty-managed server files
#   backups/  Crafty backups
#   config/   Crafty config and SSL certificate
#   logs/     Crafty logs
#   import/   drop server ZIP files here to import them
#
# Samba share: \\MinisForum\GameServers → /data/gameservers. Clients mount it at
#   /mnt/MinisForum (see the fileSystems note in each client host file).
#
# Enabled here: Intel drivers, core and server-shell system modules, AI tools (Claude),
# Samba, Syncthing, auto-update, SSH keys. Other modules in the imports block are commented out.
#
# To turn a module on or off, uncomment or comment out its line in the imports block.
# ===========================================================================

{ config, pkgs, lib, ... }:

{
  imports = [
    # Disks, swap, LUKS and boot loader (written by the installer)
    ./disk.nix

    # ==============================================================
    # System
    #   core         — locale, fonts, nix daemon, base CLI, boot defaults
    #   server-shell — headless zsh, aliases, zoxide/fzf/direnv
    # ==============================================================
    ../../modules/system/core.nix
    ../../modules/system/server-shell.nix

    # ==============================================================
    # Hardware
    #   drivers — Intel Iris Xe iGPU + basic support
    # ==============================================================
    ../../modules/hardware/drivers.nix

    # ==============================================================
    # Development — AI Tools
    #   ai-tools  — base: nix-ld, uv, ffmpeg (import alongside tools below)
    #   claude    — Claude Code CLI
    #   opencode  — OpenCode CLI
    #   local-llm — Ollama + GPU acceleration
    # ==============================================================
    ../../modules/development/ai-tools/ai-tools.nix
    ../../modules/development/ai-tools/claude.nix
    #../../modules/development/ai-tools/opencode.nix
    #../../modules/development/ai-tools/local-llm.nix

    # ==============================================================
    # Development — Editors (headless — no GUI editors)
    # ==============================================================
    #../../modules/development/editors/neovim/neovim.nix
    #../../modules/development/editors/vscodium/vscodium.nix
    #../../modules/development/editors/zed.nix

    # ==============================================================
    # Development — Languages
    #   python — python3, poetry, ruff, httpie
    #   rust   — rustup toolchain, cargo tools, just
    # ==============================================================
    #../../modules/development/languages/python.nix
    #../../modules/development/languages/rust.nix

    # ==============================================================
    # Services
    #   samba       — GameServers share at /data/gameservers
    #   syncthing   — vault + nixos-config sync (linuxury pair)
    #   auto-update — weekly nixos-rebuild from GitHub
    # ==============================================================
    ../../modules/services/samba.nix
    ../../modules/services/syncthing.nix
    ../../modules/services/auto-update/auto-update.nix
    #../../modules/services/ntfy.nix
    #../../modules/services/vpn-qbittorrent.nix
    #../../modules/services/snapper.nix
    #../../modules/services/syncthing-babylinux.nix

    # ==============================================================
    # Users
    #   ssh — authorized keys for this host
    # ==============================================================
    ../../modules/users/linuxury/linuxury-ssh.nix
  ];

  # ==============================================================
  # Host identity
  # ==============================================================
  networking.hostName = "MinisForum";

  # Update timer (services.nixos-auto-update.schedule): 02:00 instead of the 03:00 default, so the
  # hosts do not all fetch from GitHub and cache.nixos.org at the same moment.
  services.nixos-auto-update.schedule = "*-*-* 02:00";

  # ==============================================================
  # GPU driver selection
  # Intel Iris Xe integrated graphics
  # ==============================================================
  hardware.gpu = "intel";

  # ==============================================================
  # Hardware toggles — option-gated modules (imported in flake.nix)
  # ==============================================================
  hardware.openrgb.enable = false;
  hardware.lemokey-keychron.enable = false;

  # ==============================================================
  # Filesystems: the local disk layout is in disk.nix (Btrfs, no LUKS on this server).
  # The network share to the Media-Server is below.
  # ==============================================================

  # ==============================================================
  # Kernel — boot.kernelPackages (set here: linuxPackages_latest, the mainline latest)
  #   pkgs.linuxPackages_xanmod_latest and pkgs.linuxPackages_zen are commented out.
  # ==============================================================
  boot.kernelPackages = pkgs.linuxPackages_latest;           # Vanilla
  # boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;  # XanMod
  # boot.kernelPackages = pkgs.linuxPackages_zen;            # Zen

  # ==============================================================
  # Server optimizations
  #
  # Servers have different performance priorities than desktops.
  # These tweaks favor throughput and stability over interactivity.
  # ==============================================================
  boot.kernel.sysctl = {
    # Network performance
    "net.core.rmem_max"          = 134217728;  # Increase receive buffer
    "net.core.wmem_max"          = 134217728;  # Increase send buffer
    "net.ipv4.tcp_rmem"          = "4096 87380 134217728";
    "net.ipv4.tcp_wmem"          = "4096 65536 134217728";
    "net.core.netdev_max_backlog" = 5000;       # Handle bursts of traffic
  };

  # ==============================================================
  # Disable audio — servers don't need it.
  # services.pipewire.enable = false is forced here; core.nix turns PipeWire on for all hosts.
  # ==============================================================
  services.pipewire.enable = lib.mkForce false;

  # ==============================================================
  # Disable suspend/sleep — servers must stay on
  #
  # A server that suspends is useless. These settings ensure the machine
  # never sleeps regardless of inactivity.
  # ==============================================================
  systemd.targets.sleep.enable      = false;
  systemd.targets.suspend.enable    = false;
  systemd.targets.hibernate.enable  = false;
  systemd.targets.hybrid-sleep.enable = false;

  services.logind.settings.Login = {
    HandleSuspendKey             = "ignore";
    HandleHibernateKey           = "ignore";
    HandleLidSwitch              = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    IdleAction                   = "ignore";
  };

  # ==============================================================
  # Server packages
  #
  # Minimal set — only what you need to manage and monitor the server.
  # Services get their own packages when they are configured.
  # ==============================================================
  environment.systemPackages = with pkgs; [
    # Monitoring
    htop          # Interactive process viewer
    iotop         # Monitor disk I/O per process
    nethogs       # Monitor network usage per process
    ncdu          # Disk usage analyzer — find what's eating space
    smartmontools # Monitor hard drive health (S.M.A.R.T.)

    # File management
    rsync         # Fast file sync and backup tool
    rclone        # Cloud storage sync (useful for backups)
    cifs-utils    # Required for CIFS/Samba mounts

    # Utilities
    tmux          # Terminal multiplexer — keep sessions alive over SSH
                  # If your SSH connection drops, tmux keeps things running
    lsof          # List open files — useful for debugging
    strace        # Trace system calls — useful for debugging services
  ];

  # ==============================================================
  # Agenix secrets — decrypted at boot into /run/agenix/<name>
  #   file, mode (default "0400"), owner (default root), group (default: the owner's group)
  # ==============================================================

  # Samba login for the CIFS mount below. Readable by root only.
  age.secrets.smb-credentials = {
    file = ../../secrets/network/smb-credentials.age;
    mode = "0400";
    owner = "root";
  };

  # ==============================================================
  # Media-Server share (//10.0.0.3/Media-Server) for the Obsidian vault and shared files.
  # Mounted at /mnt/Media-Server on first access, unmounted after 60 s idle. Options as in
  # the client host files: credentials (agenix secret), uid/gid (gid 100 = users), nofail
  # (boot continues if the server is absent), _netdev (network mount), x-systemd.automount,
  # idle-timeout and mount-timeout.
  # ==============================================================
  fileSystems."/mnt/Media-Server" = {
    device = "//10.0.0.3/Media-Server";
    fsType = "cifs";
    options = [
      "credentials=/run/agenix/smb-credentials"
      "uid=${toString config.users.users.linuxury.uid}"
      "gid=100"
      "nofail"
      "_netdev"
      "x-systemd.automount"
      "x-systemd.idle-timeout=60"
      "x-systemd.mount-timeout=2s"
    ];
  };

  # ==============================================================
  # Game server directories
  #
  # Crafty owns everything under crafty/. Docker mounts these as volumes.
  # Entries use "d <path> <mode> <owner> <group> -" (create the directory) or
  # "Z <path> - <uid> <gid> - -" (recursively set owner and group on existing files).
  # ==============================================================
  systemd.tmpfiles.rules = [
    "d /mnt/Media-Server                    0755 linuxury users -"
    "d /data                                  0755 root     users -"
    "d /data/gameservers                      0775 linuxury users -"
    "d /data/gameservers/crafty               0775 linuxury users -"
    "d /data/gameservers/crafty/servers       0775 linuxury users -"
    "d /data/gameservers/crafty/backups       0775 linuxury users -"
    "d /data/gameservers/crafty/config        0775 linuxury users -"
    "d /data/gameservers/crafty/logs          0775 linuxury users -"
    "d /data/gameservers/crafty/import        0775 linuxury users -"
    # Z = recursively fix ownership on existing files (crafty container runs as UID 1000)
    # GID 100 (users) so linuxury (also UID 1000) is owner + group access is consistent
    "Z /data/gameservers/crafty              -     1000  100   - -"
  ];

  # ==============================================================
  # Crafty Controller — web-based Minecraft server manager
  #
  # Runs in Docker. Manages the Minecraft servers and the Hytale server.
  # Crafty doesn't auto-publish Hytale's UDP port, so it's mapped by hand
  # below (and opened in the firewall).
  #
  # Web UI:  https://MinisForum:8443  (self-signed cert, click through)
  #          or https://<tailscale-ip>:8443
  # The default login must be changed on first use.
  #
  # Ports mapped to host:
  #   8443        — Crafty web UI (HTTPS)
  #   25565       — Minecraft Java: Dark Fortress [26.2]
  #   25566       — Minecraft Java: Homestead [1.3.7]
  #   24454/udp   — Simple Voice Chat (Homestead ships voicechat)
  #   5520/udp    — Hytale: Dark Fortress (QUIC)
  #
  # To add more Minecraft ports (e.g. a third server on 25567):
  #   Add "25567:25567" to ports below and 25567 to allowedTCPPorts.
  # ==============================================================
  virtualisation.docker.enable = true;

  virtualisation.oci-containers = {
    backend = "docker";
    containers.crafty = {
      # Floating tag + pull="always": every container start checks the registry
      # digest and only downloads changed layers. ("newer" is podman-only.)
      # The weekly restart below triggers that.
      image     = "registry.gitlab.com/crafty-controller/crafty-4:latest";
      pull      = "always";
      autoStart = true;
      ports = [
        "8443:8443"         # Web UI
        "25565:25565"       # Minecraft Java — Dark Fortress [26.2]
        "25566:25566"       # Minecraft Java — Homestead [1.3.7]
        "24454:24454/udp"   # Simple Voice Chat — Homestead
        "5520:5520/udp"     # Hytale — Dark Fortress
      ];
      volumes = [
        "/data/gameservers/crafty/backups:/crafty/backups"
        "/data/gameservers/crafty/logs:/crafty/logs"
        "/data/gameservers/crafty/servers:/crafty/servers"
        "/data/gameservers/crafty/config:/crafty/app/config"
        "/data/gameservers/crafty/import:/crafty/import"
      ];
    };
  };

  # Weekly restart so the container re-checks :latest (see pull above).
  # Monday 04:00 — least likely time for anyone to be on a server.
  systemd.services.crafty-update = {
    description = "Restart Crafty to pull a newer :latest image";
    serviceConfig.Type = "oneshot";
    script = "systemctl restart docker-crafty.service";
  };
  systemd.timers.crafty-update = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "Mon 04:00";
  };

  # ==============================================================
  # Samba — GameServers share for managing server files
  #
  # Access: \\MinisForum\GameServers
  # Mount on client with: sudo mount /mnt/MinisForum
  # (Add CIFS mount to each client host's fileSystems config)
  # ==============================================================
  # The GameServers share (services.samba.settings."GameServers"):
  #   path             directory exported (/data/gameservers)
  #   read only        "no": clients can write
  #   valid users      accounts allowed to connect (linuxury, babylinux)
  #   create mask      permissions for new files (0664); directory mask for new folders (0775)
  services.samba.settings = {
    "GameServers" = {
      path             = "/data/gameservers";
      comment          = "Game server files";
      browseable       = "yes";
      "read only"      = "no";
      "valid users"    = "linuxury babylinux";
      "create mask"    = "0664";
      "directory mask" = "0775";
    };
  };

  # Firewall: SMB (TCP 445, 139; UDP 137, 138 for NetBIOS), Crafty web UI (8443),
  # Minecraft Java (25565, 25566), Simple Voice Chat (UDP 24454), Hytale (UDP 5520).
  networking.firewall.allowedTCPPorts = [ 445 139 8443 25565 25566 ];
  networking.firewall.allowedUDPPorts = [ 137 138 24454 5520 ]; # 24454 — Simple Voice Chat; 5520 — Hytale (QUIC/UDP only)

  # ==============================================================
  # Tailscale — remote management (services.tailscale)
  #   extraUpFlags  flags passed to "tailscale up" (here: advertise the tag:ssh tag)
  # On a new machine, run once: sudo tailscale up
  # ==============================================================
  # First-boot checklist:
  #   1. sudo tailscale up
  #   2. sudo smbpasswd -a linuxury && sudo smbpasswd -a babylinux
  #   3. git clone git@github.com:Linuxury/nixos-config.git ~/nixos-config
  #   4. sudo chown -R linuxury:users ~/nixos-config   ← required if cloned as root
  # ==============================================================
  services.tailscale.extraUpFlags = [ "--advertise-tags=tag:ssh" ];

  # ==============================================================
  # Users — accounts on this host (each uses zsh as its shell)
  #   isNormalUser  home directory and login account
  #   extraGroups   wheel: sudo; networkmanager: network settings; docker: run containers
  # ==============================================================
  users.users = {
    # Main account: administrator rights and Docker access.
    linuxury = {
      isNormalUser = true;
      extraGroups  = [ "wheel" "networkmanager" "docker" ];
      shell        = pkgs.zsh;
    };

    # Secondary account: Docker access, no sudo.
    babylinux = {
      isNormalUser  = true;
      # No wheel — no server admin rights for this account
      extraGroups   = [ "networkmanager" "docker" ];
      shell         = pkgs.zsh;
    };

    # Child account: no extra groups, so no sudo and no Docker.
    alex = {
      isNormalUser  = true;
      # No wheel — the child account has no server access
      extraGroups   = [];
      shell         = pkgs.zsh;
    };

    # ------------------------------------------------------------
    # nixbuilder — remote build account for the fleet
    #
    # Weak hosts (Radxa-X4, Media-Server, ThinkPad) offload their
    # derivations here instead of grinding at 1-2 jobs. They connect as
    # THIS user, not root — core.nix sets PermitRootLogin = "no"
    # fleet-wide, and Nix does not need root on a builder anyway.
    #
    # The private half lives in secrets/services/nix-builder-key.age and is
    # deployed only to the three clients. Public keys are safe in git.
    #
    # ⚠ This account is a trusted-user below, which means it can insert
    # arbitrary paths into this host's Nix store — root-equivalent HERE.
    # Only add clients you control; see secrets/secrets.nix.
    # ------------------------------------------------------------
    nixbuilder = {
      isNormalUser = true;
      description  = "Remote Nix build account";
      shell        = pkgs.bash;   # needs a real shell for nix-store --serve
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOCxGxusdbuSGqgAD8qTkTJ3sZpvrFvVJyx8uI4QP3cU fleet-builder"
      ];
    };
  };

  # ==============================================================
  # Remote builder — builder side
  #
  # nixbuilder must be trusted to import the store paths it builds for
  # clients. This list CONCATENATES with core.nix's
  # [ "root" "@wheel" ] rather than replacing it.
  #
  # Clients cap their dispatch at maxJobs = 2 (modules/system/remote-builder.nix), so builds
  # leave CPU headroom for the game server.
  # ==============================================================
  nix.settings.trusted-users = [ "nixbuilder" ];
}
