# ===========================================================================
# hosts/Radxa-X4/Radxa-X4.nix — Radxa X4
#
# Owner: managed by linuxury
# Hardware: Intel N100, Intel UHD integrated graphics
# Type: Headless server — no DE, no display manager
# Role: Dedicated torrent host behind WireGuard VPN
#        - WireGuard (VPN for torrenting) bound to WiFi interface
#        - Tailscale (management) bound to Ethernet interface
#        - qBittorrent runs inside a VPN network namespace (killswitch)
#
# Enabled modules (see imports below): core system, server shell, remote
# builder, Intel drivers, Claude Code, Samba (Torrents share), WireGuard
# killswitch for qBittorrent, Syncthing, weekly auto-update, linuxury SSH key.
#
# Users: linuxury (admin), babylinux, alex (plain accounts, no sudo).
# To add a module: add its path to imports; to disable one, comment out or
# remove its line (commented lines below are the disabled alternatives).
# ===========================================================================

{ config, pkgs, lib, ... }:

{
  imports = [
    # Filesystems and swap (written by the installer)
    ./disk.nix

    # ==============================================================
    # System
    #   core           — locale, fonts, nix daemon, base CLI, boot defaults
    #   server-shell   — headless zsh, aliases, zoxide/fzf/direnv
    #   remote-builder — offload builds to MinisForum (this host is 1 x 4)
    # ==============================================================
    ../../modules/system/core.nix
    ../../modules/system/server-shell.nix
    ../../modules/system/remote-builder.nix

    # ==============================================================
    # Hardware
    #   drivers — Intel N100 UHD iGPU + basic support
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
    #   samba           — Torrents share at /data/torrents
    #   vpn-qbittorrent — WireGuard killswitch for qBittorrent (Mullvad)
    #   syncthing       — vault + nixos-config sync (linuxury pair)
    #   auto-update     — weekly nixos-rebuild from GitHub
    # ==============================================================
    ../../modules/services/samba.nix
    ../../modules/services/vpn-qbittorrent.nix
    ../../modules/services/syncthing.nix
    ../../modules/services/auto-update/auto-update.nix
    #../../modules/services/ntfy.nix
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
  networking.hostName = "Radxa-X4";

  # Weekly auto-update start time (systemd OnCalendar format); the default is
  # 03:00, hosts are staggered so they don't rebuild at the same time.
  services.nixos-auto-update.schedule = "*-*-* 04:00";

  # ==============================================================
  # Network interface configuration
  #
  # enp2s0 (Ethernet) — LAN only, static IP, no default gateway.
  #   Used by Samba, SSH, and Tailscale. Removed from NetworkManager so
  #   NM doesn't try to DHCP it or add a competing default route.
  #   Router also has a static DHCP lease for this MAC → always 10.0.0.5.
  #
  # wlp1s0 (WiFi) — internet-facing, managed by NetworkManager (DHCP).
  #   Provides the default route, which is what WireGuard uses for its
  #   VPN handshake traffic via the masquerade in vpn-qbittorrent.nix.
  # ==============================================================
  networking.networkmanager.unmanaged = [ "enp2s0" ];
  networking.interfaces.enp2s0 = {
    useDHCP = false;  # LAN only — no DHCP, no default route via Ethernet
    ipv4.addresses = [{ address = "10.0.0.5"; prefixLength = 24; }];
  };

  # Disable IPv6 — not needed, and reduces attack surface and complexity.
  # networking.enableIPv6 sets net.ipv6.conf.all/default.disable_ipv6,
  # but NetworkManager re-enables IPv6 on interfaces it manages (wlp1s0);
  # the per-interface sysctl turns it off again after NM brings it up.
  networking.enableIPv6 = false;
  boot.kernel.sysctl."net.ipv6.conf.wlp1s0.disable_ipv6" = 1;

  # ==============================================================
  # GPU driver selection (hardware.gpu, defined by modules/hardware/drivers.nix;
  # "intel" = Intel UHD integrated graphics, Alder Lake N)
  # ==============================================================
  hardware.gpu = "intel";

  # ==============================================================
  # Hardware toggles — option-gated modules (imported in flake.nix);
  # both are off on this host (OpenRGB lighting, Lemokey/Keychron keyboard tools)
  # ==============================================================
  hardware.openrgb.enable = false;
  hardware.lemokey-keychron.enable = false;

  # ==============================================================
  # Filesystem — local disks are in ./disk.nix; only network mounts here
  # ==============================================================
  fileSystems = {

    # -----------------------------------------------------------------------
    # Media-Server Samba share — for the notes vault and shared files.
    #   credentials=...      agenix secret with the SMB username/password
    #   uid / gid=100        files appear owned by linuxury, group users
    #   nofail, _netdev      boot continues without it; waits for the network
    #   x-systemd.automount  mounts on first access
    #   idle-timeout=60      unmounts after 60 s idle
    #   mount-timeout=2s     give up quickly if the server is down
    # -----------------------------------------------------------------------
    "/mnt/Media-Server" = {
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
  };

  # ==============================================================
  # Kernel
  # ==============================================================
  # Kernel package set: latest mainline. Alternatives (pick one):
  boot.kernelPackages = pkgs.linuxPackages_latest;           # Vanilla
  # boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;  # XanMod
  # boot.kernelPackages = pkgs.linuxPackages_zen;            # Zen

  # ==============================================================
  # Intel N100 specific settings
  # ==============================================================
  # intel_pstate=active: use the intel_pstate driver with hardware-managed P-states
  boot.kernelParams = [
    "intel_pstate=active"
  ];

  hardware.cpu.intel.updateMicrocode = true;      # apply Intel CPU microcode updates
  hardware.enableRedistributableFirmware = true;  # required for Intel WiFi firmware
  powerManagement.powertop.enable = true;         # powertop auto-tune power settings at boot

  # ==============================================================
  # Packages — server tools: disk/IO/network monitoring (iotop, nethogs, ncdu,
  # smartmontools, lsof, strace), transfer (rsync, rclone, cifs-utils for SMB
  # mounts), tmux, and Radxa X4 GPIO/I2C/serial access (libgpiod, i2c-tools,
  # minicom).
  # ==============================================================
  environment.systemPackages = with pkgs; [
    iotop
    nethogs
    ncdu
    smartmontools
    rsync
    rclone
    cifs-utils    # Required for CIFS/Samba mounts
    tmux
    lsof
    strace
    libgpiod
    i2c-tools
    minicom
  ];

  # ==============================================================
  # Disable audio — headless, no sound server
  # ==============================================================
  services.pipewire.enable = lib.mkForce false;

  # ==============================================================
  # Disable suspend/sleep — the targets are disabled and logind ignores the
  # suspend/hibernate keys, lid switch and idle action.
  # ==============================================================
  systemd.targets.sleep.enable        = false;
  systemd.targets.suspend.enable      = false;
  systemd.targets.hibernate.enable    = false;
  systemd.targets.hybrid-sleep.enable = false;

  services.logind.settings.Login = {
    HandleSuspendKey             = "ignore";
    HandleHibernateKey           = "ignore";
    HandleLidSwitch              = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    IdleAction                   = "ignore";
  };

  # Scheduled reboot (1x daily) — coarse backstop behind wifi-watchdog
  # (below), which handles routine recovery; also covers wifi-watchdog itself
  # getting stuck. Persistent = true catches up once if the machine was off at
  # the scheduled time.
  systemd.services.daily-reboot = {
    description = "Scheduled reboot";
    serviceConfig = {
      Type       = "oneshot";
      ExecStart  = "/run/current-system/sw/bin/systemctl reboot";
    };
  };

  systemd.timers.daily-reboot = {
    description = "Reboot timer — 1x daily (06:00)";
    wantedBy    = [ "timers.target" ];
    timerConfig = {
      OnCalendar         = "06:00";
      Persistent         = true;      # catch up if machine was off at scheduled time
      RandomizedDelaySec = "5min";    # jitter so services don't always restart at exact times
    };
  };

  # ==============================================================
  # Server network optimizations (sysctl)
  #   net.core.rmem_max / wmem_max        max socket buffer size (128 MiB)
  #   net.ipv4.tcp_rmem / tcp_wmem        TCP buffer min / default / max
  #   net.core.netdev_max_backlog         packets queued when the NIC is faster than the CPU
  #   fs.inotify.max_user_watches         file watches per user (large torrent trees)
  # ==============================================================
  boot.kernel.sysctl = {
    "net.core.rmem_max"           = 134217728;
    "net.core.wmem_max"           = 134217728;
    "net.ipv4.tcp_rmem"           = "4096 87380 134217728";
    "net.ipv4.tcp_wmem"           = "4096 65536 134217728";
    "net.core.netdev_max_backlog" = 5000;
    "fs.inotify.max_user_watches" = 524288;
  };

  # ==============================================================
  # Tailscale — management access via Ethernet
  # Auth key stored in agenix — joins the tailnet without a manual "tailscale up".
  #   authKeyFile    decrypted secret path
  #   extraSetFlags  --ssh=false: Tailscale's SSH server is off (OpenSSH is used)
  # ==============================================================
  age.secrets.tailscale-auth-radxa = {
    file = ../../secrets/network/tailscale-auth-radxa.age;
    mode = "0400";
  };

  services.tailscale = {
    enable = true;
    authKeyFile = config.age.secrets.tailscale-auth-radxa.path;
    extraSetFlags = [ "--ssh=false" ];
  };

  # Tailscale watchdog — restarts tailscaled if it loses connectivity
  # Runs every 5 minutes. Uses 'tailscale ping' to verify the tunnel is
  # actually working, not just that the daemon is running.
  systemd.services.tailscale-watchdog = {
    description = "Restart tailscaled if Tailscale connectivity is lost";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "tailscale-watchdog" ''
        if ! ${pkgs.tailscale}/bin/tailscale ping --timeout=10s --c=1 ${config.networking.hostName} &>/dev/null; then
          echo "Tailscale connectivity lost, restarting tailscaled..."
          systemctl restart tailscaled
        fi
      '';
    };
  };

  systemd.timers.tailscale-watchdog = {
    description = "Tailscale connectivity watchdog timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec  = "2min";
      OnUnitActiveSec = "5min";
      Unit = "tailscale-watchdog.service";
    };
  };

  # WiFi watchdog — reconnects wlp1s0's NetworkManager connection, then reboots
  # the host, if real internet is unreachable. Checks 1.1.1.1/8.8.8.8, not the
  # gateway directly, because the gateway can drop direct pings from wlp1s0
  # while routing/NAT still works, so a gateway-only check would give false
  # alarms. Uses nmcli, not raw `ip link`, since wlp1s0 is NM-managed. Two
  # attempts with backoff before rebooting, so a brief upstream outage doesn't
  # reboot the host mid-torrent. Runs 2 min after boot, then every 60 s.
  systemd.services.wifi-watchdog = {
    description = "Recover wlp1s0 if it loses real internet connectivity";
    serviceConfig = {
      Type = "oneshot";
      # ~156 s worst case (2 internet checks + 2 bounded reconnect
      # attempts + backoff); the default 90 s TimeoutStartSec is too short.
      TimeoutStartSec = "240s";
      ExecStart = pkgs.writeShellScript "wifi-watchdog" ''
        IFACE="wlp1s0"
        GATEWAY="10.0.0.100"
        EXT1="1.1.1.1"
        EXT2="8.8.8.8"
        NMCLI="${pkgs.networkmanager}/bin/nmcli"
        PING="${pkgs.iputils}/bin/ping"

        check_internet() {
          $PING -I "$IFACE" -c 3 -W 2 "$EXT1" &>/dev/null && return 0
          $PING -I "$IFACE" -c 3 -W 2 "$EXT2" &>/dev/null && return 0
          return 1
        }

        if check_internet; then
          exit 0
        fi

        echo "wifi-watchdog: $IFACE cannot reach $EXT1 or $EXT2, attempting recovery"
        if $PING -I "$IFACE" -c 1 -W 2 "$GATEWAY" &>/dev/null; then
          echo "wifi-watchdog: note — gateway $GATEWAY IS reachable, so this isn't a gateway-level failure"
        else
          echo "wifi-watchdog: gateway $GATEWAY also unreachable"
        fi
        $NMCLI device show "$IFACE" 2>&1 || true

        for attempt in 1 2; do
          echo "wifi-watchdog: attempt $attempt — reconnecting $IFACE via NetworkManager"
          timeout 15 $NMCLI device disconnect "$IFACE" &>/dev/null || true
          sleep 2
          timeout 20 $NMCLI device connect "$IFACE" &>/dev/null || true

          sleep 8
          if check_internet; then
            echo "wifi-watchdog: recovered on attempt $attempt"
            exit 0
          fi

          echo "wifi-watchdog: attempt $attempt did not recover connectivity"
          if [ "$attempt" -eq 1 ]; then
            sleep 30
          fi
        done

        echo "wifi-watchdog: still unreachable after 2 recovery attempts, rebooting"
        systemctl reboot
      '';
    };
  };

  systemd.timers.wifi-watchdog = {
    description = "WiFi connectivity watchdog timer";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "2min";
      OnUnitActiveSec = "60s";
      Unit = "wifi-watchdog.service";
    };
  };

  # ==============================================================
  # qBittorrent with WireGuard killswitch
  #
  # Architecture:
  #   - Tailscale (management) runs on the host, prefers Ethernet
  #   - WireGuard VPN for torrents uses WiFi as its transport because
  #     WiFi is Radxa's internet-facing interface (default route)
  #   - qBittorrent runs inside the vpn-qbt network namespace
  #   - All torrent traffic exits via WireGuard — structural killswitch
  #
  # Web UI: http://Radxa-X4:8080  (LAN) or via Tailscale hostname:8080
  #
  # Setup steps:
  #   1. The WireGuard config (Mullvad) is managed by agenix — decrypted to
  #      /etc/wireguard/vpnunlimited.conf (secret and file keep that name)
  #   2. On first access, log in with a temporary password — modern qBittorrent
  #      no longer defaults to admin/adminadmin. It generates a random temp
  #      password on every service (re)start, logged only to journalctl:
  #        journalctl -u qbittorrent-vpn.service | grep "temporary password"
  #      Set a permanent one immediately (Options -> WebUI -> Change password)
  #      or it keeps randomizing on every restart/reboot.
  #   3. Set download paths to /data/torrents/incomplete and /data/torrents/complete
  #   4. Configure qBittorrent in Sonarr/Radarr as remote download client
  # ==============================================================
  age.secrets.wireguard-vpnunlimited = {
    file = ../../secrets/network/mullvad-wireguard.age;
    path = "/etc/wireguard/vpnunlimited.conf";
    mode = "0600";
  };

  age.secrets.smb-credentials = {
    file = ../../secrets/network/smb-credentials.age;
    mode = "0400";
    owner = "root";
  };

  services.vpn-qbittorrent = {
    enable        = true;
    user          = "linuxury";
    watchedFolder = "/data/torrents/queued";

    # services.vpn-qbittorrent options used here (see the module header for all):
    #   user            account qbittorrent-nox runs as
    #   watchedFolder   directory polled for .torrent files to add
    #   failoverServers ordered backups, tried when the active tunnel goes down.
    # The primary server (us-atl-wg-001) is in the agenix secret; these are the
    # backups. Public keys are the Mullvad server keys (not sensitive).
    failoverServers = [
      { name = "us-atl-wg-001"; publicKey = "nvyBkaEXHwyPBAm8spGB0TFzf2W5wPAl8EEuJ0t+bzs="; endpoint = "45.134.140.130:51820"; }
      { name = "us-dal-wg-001"; publicKey = "EAzbWMQXxJGsd8j2brhYerGB3t5cPOXqdIDFspDGSng="; endpoint = "146.70.211.66:51820"; }
      { name = "us-nyc-wg-301"; publicKey = "IzqkjVCdJYC1AShILfzebchTlKCqVCt/SMEXolaS3Uc="; endpoint = "143.244.47.65:51820"; }
      { name = "us-chi-wg-201"; publicKey = "+Xx2mJnoJ+JS11Z6g8mp6aUZV7p6DAN9ZTAzPaHakhM="; endpoint = "87.249.134.1:51820"; }
      { name = "us-lax-wg-001"; publicKey = "zqsfGglzJPY657WMRxf/S4omG7+ZkSDIpDq+ggbc9yo="; endpoint = "23.234.72.2:51820"; }
    ];
  };

  # Directories created at boot, "type path mode owner group age". /data is a
  # plain directory here, so a separate disk can be mounted on it; without one
  # these live on the main BTRFS filesystem.
  systemd.tmpfiles.rules = [
    "d /mnt/Media-Server                    0755 linuxury users -"
    "d /data                             0755 root     users -"
    "d /data/torrents                    0775 linuxury users -"
    "d /data/torrents/complete           0775 linuxury users -"
    "d /data/torrents/incomplete         0775 linuxury users -"
  ];

  # ==============================================================
  # Samba — share torrent directories for file management
  #   Torrents  /data/torrents, read-write for "valid users" linuxury and
  #             babylinux; new files 0664, new dirs 0775
  #
  # Access: \\Radxa-X4\Torrents
  # ==============================================================
  services.samba.settings = {
    # Bind Samba to Ethernet only — never listens on WiFi or the veth pair.
    # "bind interfaces only" prevents nmbd/smbd from accepting connections
    # on wlp1s0 (10.0.0.32) or veth-qbt (10.200.200.x).
    global = {
      "interfaces"           = "lo enp2s0";
      "bind interfaces only" = "yes";
    };

    "Torrents" = {
      path             = "/data/torrents";
      comment          = "Torrent downloads";
      browseable       = "yes";
      "read only"      = "no";
      "valid users"    = "linuxury babylinux";
      "create mask"    = "0664";
      "directory mask" = "0775";
    };
  };

  # SMB ports: TCP 445 (SMB), 139 (NetBIOS session); UDP 137/138 (NetBIOS)
  networking.firewall.allowedTCPPorts = [ 445 139 ];
  networking.firewall.allowedUDPPorts = [ 137 138 ];

  # ==============================================================
  # Users — accounts present on this host: linuxury (wheel = sudo, networkmanager,
  # gpio), babylinux (networkmanager), alex (no extra groups); all use zsh.
  # ==============================================================
  users.users = {
    linuxury = {
      isNormalUser = true;
      extraGroups  = [ "wheel" "networkmanager" "gpio" ];
      shell        = pkgs.zsh;
    };

    babylinux = {
      isNormalUser = true;
      extraGroups  = [ "networkmanager" ];
      shell        = pkgs.zsh;
    };

    alex = {
      isNormalUser = true;
      extraGroups  = [];
      shell        = pkgs.zsh;
    };
  };
}
