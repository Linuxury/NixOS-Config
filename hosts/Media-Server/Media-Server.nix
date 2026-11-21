# ===========================================================================
# hosts/Media-Server/Media-Server.nix — media server
#
# Hardware: AMD Ryzen 5 3600x, AMD Radeon RX 480 (VAAPI transcoding)
# Type: headless server with no desktop environment and no display manager
# Role: media server for Plex, the Arr stack, Immich, FreshRSS and file sharing
#
# Storage:
#   - NVMe 232.9 GB OS drive (Btrfs; disk.nix)
#   - two 3.6 TB HDDs pooled by mergerfs at /data (see fileSystems below)
#
# Enabled here: AMD drivers, core and server-shell system modules, Claude and AI tools,
# Samba (one share of /data), ntfy, Syncthing, auto-update, the ZenNotes server (port 7879),
# FreshRSS (freshrss.nix), PostgreSQL with pgvector, Plex, the Arr services and Immich.
#
# To turn a module on or off, uncomment or comment out its line in the imports block.
# ===========================================================================

{ pkgs, lib, ... }:

{
  imports = [
    # Disks, swap, LUKS and boot loader (written by the installer)
    ./disk.nix

    # ==============================================================
    # System
    #   core           — locale, fonts, nix daemon, base CLI, boot defaults
    #   server-shell   — headless zsh, aliases, zoxide/fzf/direnv
    # ==============================================================
    ../../modules/system/core.nix
    ../../modules/system/server-shell.nix

    # ==============================================================
    # Hardware
    #   drivers — AMD RX 480, used for VAAPI hardware transcoding
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
    #   samba       — Media-Server share at /data (media, shared, downloads)
    #   ntfy        — push notification server for all hosts
    #   syncthing   — vault + nixos-config sync (linuxury pair)
    #   auto-update — weekly nixos-rebuild from GitHub
    # ==============================================================
    ../../modules/services/samba.nix
    ../../modules/services/ntfy.nix
    ../../modules/services/syncthing.nix
    ../../modules/services/auto-update/auto-update.nix
    ../../modules/services/zennotes/service-zennotes.nix
    #../../modules/services/vpn-qbittorrent.nix
    #../../modules/services/snapper.nix
    #../../modules/services/syncthing-babylinux.nix

    # ==============================================================
    # Host-specific
    #   freshrss — RSS reader
    # ==============================================================
    ./freshrss.nix

    # ==============================================================
    # Users
    #   ssh — authorized keys for this host
    # ==============================================================
    ../../modules/users/linuxury/linuxury-ssh.nix
  ];

  # ==============================================================
  # Host identity
  # ==============================================================
  networking.hostName = "Media-Server";

  # Update timer (services.nixos-auto-update.schedule): 02:30 instead of the 03:00 default,
  # so the hosts do not all update at the same time.
  services.nixos-auto-update.schedule = "*-*-* 02:30";

  # ==============================================================
  # GPU driver selection
  # AMD RX 480 — used for VAAPI hardware transcoding via Plex
  # ==============================================================
  hardware.gpu = "amd";

  # ==============================================================
  # Hardware toggles — option-gated modules (imported in flake.nix)
  # ==============================================================
  hardware.openrgb.enable = false;
  hardware.lemokey-keychron.enable = false;

  # ==============================================================
  # PostgreSQL with pgvector — database for the AI memory service
  #   enable                    run PostgreSQL (set here)
  #   package                   server version: postgresql_16 (set here)
  #   settings.shared_preload_libraries  "vector": load pgvector at server start (set here)
  #   extensions                pgvector, installed into the server (set here)
  # ==============================================================
  services.postgresql = {
    enable = true;
    package = pkgs.postgresql_16;
    settings = {
      shared_preload_libraries = "vector";
    };
    extensions = ps: [ ps.pgvector ];
  };

  # ==============================================================
  # Filesystems — the OS disk layout is in disk.nix. The /data pool is below.
  # ==============================================================
  fileSystems = {

    # -----------------------------------------------------------------------
    # mergerfs — combines both HDDs into a single /data mount point
    #
    # From the outside /data looks like one 7.2TB drive.
    # mergerfs handles distributing files across the two physical drives
    # transparently using the "most free space" policy.
    #
    # Options explained:
    #   cache.files=partial   — partial caching for better performance
    #   dropcacheonclose=true — frees memory cache when files are closed
    #   category.create=mfs   — write new files to drive with most free space
    #   moveonenospc=true     — move files to other drive if one fills up
    #   minfreespace=10G      — always keep 10GB free on each drive
    #   nofail                — boot even if drives are missing
    # -----------------------------------------------------------------------
    "/data" = {
      device  = "/mnt/disk1:/mnt/disk2";
      fsType  = "fuse.mergerfs";
      options = [
        "cache.files=partial"
        "dropcacheonclose=true"
        "category.create=mfs"
        "moveonenospc=true"
        "minfreespace=10G"
        "nofail"
      ];
      depends = [ "/mnt/disk1" "/mnt/disk2" ];
    };
  };

  # ==============================================================
  # Kernel — boot.kernelPackages (set here: linuxPackages_latest, the mainline latest)
  #   pkgs.linuxPackages_xanmod_latest and pkgs.linuxPackages_zen are commented out.
  # ==============================================================
  boot.kernelPackages = pkgs.linuxPackages_latest;           # Vanilla
  # boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;  # XanMod
  # boot.kernelPackages = pkgs.linuxPackages_zen;            # Zen

  # amdgpu power-management feature mask, set to all features (0xffffffff) for the RX 480.
  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff"
  ];

  # ==============================================================
  # Hardware video transcoding — VAAPI on the RX 480 (hardware.graphics)
  #   enable          graphics stack (set here)
  #   enable32Bit     32-bit graphics libraries (set here)
  #   extraPackages   ROCm OpenCL runtime (rocmPackages.clr)
  # Run `vainfo` after first boot to check VAAPI. In Plex, enable Hardware-Accelerated Transcoding.
  # ==============================================================
  hardware.graphics = {
    enable      = true;
    enable32Bit = true;
    extraPackages = with pkgs; [
      rocmPackages.clr
    ];
  };

  # ==============================================================
  # Service groups
  #
  # These groups control file permissions across all media services.
  # Each service runs under its own user but shares the media group
  # for read/write access to /data/media and related folders.
  # ==============================================================
  users.groups = {
    media        = { gid = 995; members = [ "plex" "sonarr" "radarr" "lidarr" "readarr" "bazarr" "prowlarr" "linuxury" "babylinux" ]; };
    arr-services = {};  # Shared group for all arr services
    # linuxury/babylinux in the immich group so Samba connections can read
    # photo files (which immich creates as immich:immich).
    immich       = { members = [ "linuxury" "babylinux" ]; };
  };

  # ==============================================================
  # Storage directory structure
  #
  # systemd-tmpfiles creates and manages these directories at boot.
  # They are recreated automatically if accidentally deleted.
  # ==============================================================
  systemd.tmpfiles.rules = [
    # Media library — Plex and Arr services read from here
    "d /data/media                        0775 root media        -"
    "d /data/media/movies                 0775 root media        -"
    "d /data/media/tv                     0775 root media        -"
    "d /data/media/anime                  0775 root media        -"
    "d /data/media/music                  0775 root media        -"
    "d /data/media/books                  0775 root media        -"

    # Downloads — mount point for Radxa-X4 Torrents CIFS share
    # The CIFS mount overlays this dir, so only the mountpoint needs to exist.
    "d /data/downloads                    0755 root root         -"

    # Photos — Immich library
    # Use 'z' (not 'd') so permissions are enforced on existing dirs too.
    # 0750: immich group (linuxury, babylinux) can read/browse but not write.
    "z /data/photos                       0750 immich immich -"
    "z /data/photos/library               0750 immich immich -"
    "z /data/photos/uploads               0750 immich immich -"
    "z /data/photos/thumbs                0750 immich immich -"
    "z /data/photos/profile               0750 immich immich -"
    "z /data/photos/backups               0750 immich immich -"
    "z /data/photos/encoded-video         0750 immich immich -"

    # Shared workspace — accessible to every account via Samba
    "d /data/shared                       0775 root media        -"

    # Service config directories — persistent app data
    "d /data/config                       0755 root         root         -"
    "d /data/config/plex                  0775 plex         media        -"
    # 'z' fixes permissions on existing dirs (unlike 'd' which only creates).
    # Plex creates these subdirs itself — enforce group-write on every boot.
    "z \"/data/config/plex/Plex Media Server\"           0775 plex media -"
    "z \"/data/config/plex/Plex Media Server/Plug-ins\"  0775 plex media -"
    "d /data/config/immich                0755 immich       immich       -"
    "d /data/config/arr-services          0755 root         arr-services -"
    "d /data/config/arr-services/sonarr   0755 sonarr       arr-services -"
    "d /data/config/arr-services/radarr   0755 radarr       arr-services -"
    "d /data/config/arr-services/prowlarr 0755 prowlarr     arr-services -"
    "d /data/config/arr-services/bazarr   0755 bazarr       arr-services -"
    "d /data/config/arr-services/readarr  0755 readarr      arr-services -"
    "d /data/config/arr-services/lidarr   0755 lidarr       arr-services -"

    # Obsidian vault — central location for all hosts + phone sync
    "d /data/obsidian                     0755 linuxury     users        -"

  ];

  # ==============================================================
  # Samba credentials for mounting Radxa-X4's Torrents share (agenix secret, root-only)
  # ==============================================================
  age.secrets.smb-credentials = {
    file = ../../secrets/network/smb-credentials.age;
    mode = "0400";
  };

  # ==============================================================
  # CIFS mount — Radxa-X4 Torrents share
  #
  # Mounted directly at /data/downloads so it appears as the "downloads"
  # folder in the Media-Server Samba share and Arr services can access it
  # at the expected path.
  #
  # Remote path mapping in Sonarr/Radarr (manual setup after first boot):
  #   Download Clients → qBittorrent → Remote Path Mappings:
  #     Remote path: /data/torrents/complete
  #     Local path:  /data/downloads/complete
  #
  # Mounts on first access and unmounts after 60 s idle. nofail: boot continues if Radxa-X4 is offline.
  # Ownership: uid 0 (root) and gid 995 (media). file_mode 0664 and dir_mode 0775 for new files.
  # ==============================================================
  fileSystems."/data/downloads" = {
    device  = "//10.0.0.5/Torrents";
    fsType  = "cifs";
    options = [
      "credentials=/run/agenix/smb-credentials"
      "uid=0" "gid=995"
      "file_mode=0664" "dir_mode=0775"
      "nofail" "_netdev"
      "x-systemd.mount-timeout=30s"
    ];
  };

  # ==============================================================
  # Plex Media Server (services.plex)
  #   enable        run Plex (set here)
  #   openFirewall  open the Plex ports in the firewall (set here)
  #   user, group   account and group Plex runs as (plex, media)
  #   dataDir       configuration and metadata (/data/config/plex)
  #   package       the Plex build, pinned via plex.json (below)
  # Web UI: http://Media-Server:32400/web after first boot.
  #
  # After first boot:
  #   1. Open the Plex web UI and complete setup
  #   2. Enable Hardware-Accelerated Transcoding in settings
  #   3. Point libraries at /data/media/movies, /data/media/tv etc
  #   4. Point Plex transcoder at jellyfin-ffmpeg for VAAPI support
  # ==============================================================
  services.plex = {
    enable       = true;
    openFirewall = true;
    user         = "plex";
    group        = "media";
    dataDir      = "/data/config/plex";
    # Pinned via plex.json (nixpkgs only packages the public release and lags).
    # Update with scripts/plex-bump; drop this override to follow nixpkgs again.
    package = pkgs.plex.override {
      plexRaw = pkgs.plexRaw.overrideAttrs (_: let pin = builtins.fromJSON (builtins.readFile ./plex.json); in {
        inherit (pin) version;
        src = pkgs.fetchurl {
          url    = "https://downloads.plex.tv/plex-media-server-new/${pin.version}/debian/plexmediaserver_${pin.version}_amd64.deb";
          sha256 = pin.sha256;
        };
      });
    };
  };

  # Allow media group members to write into Plex's data dir (e.g. Plug-ins).
  # UMask 0002 means Plex creates files/dirs as 664/775 instead of 644/755.
  systemd.services.plex.serviceConfig.UMask = "0002";

  # ==============================================================
  # Arr stack — automated media management (services.<name>)
  #   enable   run the service (set here for each)
  #   user     account it runs as (sonarr, radarr, lidarr, readarr, bazarr, prowlarr)
  #   group    media, or arr-services for bazarr
  #   dataDir  state directory under /data/config/arr-services (prowlarr keeps its default)
  #
  # Web UIs after first boot:
  #   Prowlarr → http://Media-Server:9696
  #   Sonarr   → http://Media-Server:8989
  #   Radarr   → http://Media-Server:7878
  #   Lidarr   → http://Media-Server:8686
  #   Readarr  → http://Media-Server:8787
  #   Bazarr   → http://Media-Server:6767
  # ==============================================================
  services.sonarr = {
    enable  = true;
    user    = "sonarr";
    group   = "media";
    dataDir = "/data/config/arr-services/sonarr";
  };

  services.radarr = {
    enable  = true;
    user    = "radarr";
    group   = "media";
    dataDir = "/data/config/arr-services/radarr";
  };

  services.prowlarr = {
    enable = true;
    # Note: dataDir not configurable in nixpkgs yet
    # defaults to /var/lib/prowlarr
  };

  services.lidarr = {
    enable  = true;
    user    = "lidarr";
    group   = "media";
    dataDir = "/data/config/arr-services/lidarr";
  };

  services.readarr = {
    enable  = true;
    user    = "readarr";
    group   = "media";
    dataDir = "/data/config/arr-services/readarr";
  };

  services.bazarr = {
    enable = true;
    user   = "bazarr";
    group  = "arr-services";
  };

  # ==============================================================
  # Immich — self-hosted photo and video management (services.immich)
  #   enable         run Immich (set here)
  #   openFirewall   open its port in the firewall (set here)
  #   mediaLocation  where uploaded media is stored: /data/photos (set here)
  #   host           address to listen on: 0.0.0.0, all interfaces (set here)
  # Web UI: http://Media-Server:2283 after first boot.
  #
  # After first boot:
  #   1. Create admin account at the web UI
  #   2. Configure external library at /data/photos/library
  # ==============================================================
  services.immich = {
    enable        = true;
    openFirewall  = true;
    mediaLocation = "/data/photos";
    host          = "0.0.0.0";
  };

  # Override Immich's default restrictive umask (0077) so that files are
  # readable by group members (linuxury/babylinux via the immich group).
  # 0022 → files: 0644, dirs: 0755 — group + others can read.
  systemd.services.immich-server.serviceConfig.UMask        = lib.mkForce "0022";
  systemd.services.immich-microservices.serviceConfig.UMask = lib.mkForce "0022";

  # ==============================================================
  # Open firewall ports for all services
  #
  # Syncthing (22000/tcp+udp, 21027/udp) is handled by the base syncthing module.
  # ==============================================================
  networking.firewall.allowedTCPPorts = [
    32400 # Plex
    8989  # Sonarr
    7878  # Radarr
    9696  # Prowlarr
    8686  # Lidarr
    8787  # Readarr
    6767  # Bazarr
    2283  # Immich
  ];

  # ==============================================================
  # Give Plex access to the GPU for transcoding: plex joins the render and video groups.
  # ==============================================================
  users.groups.render.members = [ "plex" ];
  users.groups.video.members  = [ "plex" ];

  # ==============================================================
  # Disable audio — servers don't need it (services.pipewire.enable forced off).
  # ==============================================================
  services.pipewire.enable    = lib.mkForce false;

  # ==============================================================
  # Disable suspend and sleep. A server must stay on.
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

  # ==============================================================
  # Server network tuning (boot.kernel.sysctl, Linux kernel keys)
  #   net.core.rmem_max / wmem_max       largest socket receive and send buffers (128 MiB)
  #   net.ipv4.tcp_rmem / tcp_wmem       TCP buffer sizes: min, default, max
  #   net.core.netdev_max_backlog        packets queued per CPU before the kernel drops them
  #   net.ipv4.tcp_congestion_control    "bbr": congestion control algorithm
  #   net.core.default_qdisc             "fq": fair-queue packet scheduler (pairs with bbr)
  # ==============================================================
  boot.kernel.sysctl = {
    "net.core.rmem_max"               = 134217728;
    "net.core.wmem_max"               = 134217728;
    "net.ipv4.tcp_rmem"               = "4096 87380 134217728";
    "net.ipv4.tcp_wmem"               = "4096 65536 134217728";
    "net.core.netdev_max_backlog"     = 5000;
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc"          = "fq";
  };

  # ==============================================================
  # Packages
  # ==============================================================
  environment.systemPackages = with pkgs; [
    # Monitoring
    libva-utils  # vainfo — verify VAAPI hardware transcoding
    iotop
    nethogs
    ncdu
    smartmontools
    rsync
    rclone
    tmux
    lsof
    strace

    # Media tools
    jellyfin-ffmpeg  # FFmpeg with VAAPI support for Plex transcoding
    mediainfo        # Inspect media file details
    mkvtoolnix       # MKV container tools
    ffmpeg           # General media conversion

    # Storage
    mergerfs         # CLI access to mergerfs pool
    cifs-utils       # Required for CIFS/SMB mounts
  ];

  # ==============================================================
  # Samba shares
  #
  # Global Samba config (security, protocol, discovery) is in samba.nix.
  # Here we define what this specific server actually shares.
  #
  # Single share exposing /data under the server's hostname. Subdirectories
  # (media/, shared/, downloads/) are visible inside it. Per-folder access
  # control is enforced by filesystem permissions on the server rather than
  # separate Samba shares.
  #
  # After first boot, set Samba passwords (separate from Linux password):
  #   sudo smbpasswd -a linuxury
  #   sudo smbpasswd -a babylinux
  #   sudo smbpasswd -a alex
  #
  # Access from clients:
  #   Windows:  \\Media-Server\Media-Server  and  \\Media-Server\Downloads
  #   macOS:    smb://Media-Server/Media-Server  and  smb://Media-Server/Downloads
  #   Linux:    smb://Media-Server/Media-Server  and  smb://Media-Server/Downloads
  #   fstab:    //10.0.0.3/Media-Server → /mnt/Media-Server
  # ==============================================================
  services.samba.settings = {

    "Media-Server" = {
      path              = "/data";
      comment           = "Media Server";
      browseable        = "yes";
      "read only"       = "no";
      "valid users"     = "linuxury babylinux alex";
      "force group"     = "media";
      "create mask"     = "0664";
      "directory mask"  = "0775";
    };

    "Downloads" = {
      path              = "/data/downloads";
      comment           = "Torrents (Radxa-X4)";
      browseable        = "yes";
      "read only"       = "no";
      "valid users"     = "linuxury babylinux alex";
      "force group"     = "media";
      "create mask"     = "0664";
      "directory mask"  = "0775";
    };

  };

  # ==============================================================
  # Users — three accounts, each with a Samba login (see the Samba section above)
  #   linuxury   administrator (wheel), GPU and media access
  #   babylinux  media and immich groups
  #   alex       child account, media group only
  # ==============================================================
  users.users = {
    linuxury = {
      isNormalUser = true;
      extraGroups  = [ "wheel" "networkmanager" "video" "render" "media" ];
      shell        = pkgs.zsh;
    };

    babylinux = {
      isNormalUser = true;
      extraGroups  = [ "networkmanager" "media" "immich" ];
      shell        = pkgs.zsh;
    };

    alex = {
      isNormalUser = true;
      extraGroups  = [ "media" ];
      shell        = pkgs.zsh;
    };
  };

  # ==============================================================
  # Tailscale — remote access to FreshRSS and management (services.tailscale.extraUpFlags).
  # The extra flag advertises the tag:ssh tag. On a new machine, run once: sudo tailscale up
  # ==============================================================
  services.tailscale.extraUpFlags = [ "--advertise-tags=tag:ssh" ];
}
