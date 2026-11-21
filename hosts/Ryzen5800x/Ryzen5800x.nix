# ===========================================================================
# hosts/Ryzen5800x/Ryzen5800x.nix — AMD Ryzen 7 5800x Desktop
#
# Owner: babylinux
# Hardware: AMD Ryzen 7 5800x, AMD Radeon RX 5700 XT
# Type: Desktop — no disk encryption
# Role: babylinux's daily driver desktop
#
# Enabled modules (see imports below): core + graphical system, AMD drivers,
# browsers and desktop apps, KDE Plasma, gaming, Claude Code + OpenCode, Zed,
# auto-update, babylinux Syncthing, SSH keys and display name.
# Disabled alternatives (COSMIC, GNOME, Hyprland, niri, snapper, ...) stay in
# imports as commented lines: uncomment one to switch.
#
# Users: babylinux (main, wheel) and linuxury (remote admin, no home).
# ===========================================================================

{ config, pkgs, ... }:

{
  imports = [
    # Filesystems and swap (written by the installer)
    ./disk.nix

    # ==============================================================
    # System
    #   core     — locale, fonts, nix daemon, base CLI, boot defaults
    #   graphical — Wayland stack, PipeWire audio, XDG portals, base pkgs
    # ==============================================================
    ../../modules/system/core.nix
    ../../modules/system/graphical/graphical.nix

    # ==============================================================
    # Hardware
    #   drivers — GPU (AMD/NVIDIA/Intel) + OpenCL/VAAPI
    #   (openrgb / lemokey-keychron are option-gated — see Hardware toggles)
    # ==============================================================
    ../../modules/hardware/drivers.nix

    # ==============================================================
    # Graphical Apps — all optional, comment out to remove
    #   firefox     — primary browser
    #   helium      — secondary browser (Firefox-based)
    #   app-zennotes — ZenNotes notes app
    #   craft-apps  — creative apps
    #   fluxer      — Discord client
    #   kdeconnect  — phone integration
    #   zen-browser — privacy-focused Firefox fork
    # ==============================================================
    ../../modules/system/graphical/firefox.nix
    ../../modules/system/graphical/helium.nix
    ../../modules/system/graphical/app-zennotes.nix
    ../../modules/system/graphical/fluxer.nix
    ../../modules/system/graphical/craft-apps.nix
    ../../modules/services/kdeconnect.nix
    #../../modules/system/graphical/zen-browser.nix

    # ==============================================================
    # Desktop Environment — enable ONE (includes shell + greeter)
    # ==============================================================
    ../../modules/desktops/kde.nix
    #../../modules/desktops/cosmic/cosmic.nix
    #../../modules/desktops/gnome/gnome.nix

    # ==============================================================
    # Compositor — enable ONE, pair with Shell + Greeter below
    # ==============================================================
    #../../modules/compositors/hyprland/hyprland.nix
    #../../modules/compositors/niri.nix

    # ==============================================================
    # Shell — enable ONE for the active compositor
    #   wayle    — needs greeters/sddm (imported below)
    #   noctalia — bundles its own greeter (noctalia-greeter/greetd)
    # ==============================================================
    #../../modules/shells/wayle.nix
    #../../modules/shells/noctalia/shell-noctalia.nix

    # ==============================================================
    # Greeter — skip if using a full DE (they bundle their own)
    # ==============================================================
    #../../modules/greeters/sddm.nix

    # ==============================================================
    # Components — individual desktop components
    #   only needed with bare compositors not using a full shell
    # ==============================================================
    #../../modules/components/bar/waybar.nix
    #../../modules/components/launcher/wofi.nix
    #../../modules/components/notifications/swaync/swaync.nix

    # ==============================================================
    # Gaming
    #   Steam, Proton/Wine, Faugus, MangoHud, gamemode, controllers
    # ==============================================================
    ../../modules/gaming/gaming.nix

    # ==============================================================
    # Development — AI Tools (not a development host)
    #   ai-tools  — base: nix-ld, uv, ffmpeg (import alongside tools below)
    #   claude    — Claude Code CLI + VSCodium extension
    #   opencode  — OpenCode CLI + VSCodium extension
    #   local-llm — Ollama + AMD ROCm GPU acceleration
    #   lm-studio — GUI LLM runner (requires ai-tools)
    # ==============================================================
    ../../modules/development/ai-tools/ai-tools.nix
    ../../modules/development/ai-tools/claude.nix
    ../../modules/development/ai-tools/opencode.nix
    #../../modules/development/ai-tools/local-llm.nix
    #../../modules/development/ai-tools/lm-studio.nix

    # ==============================================================
    # Development — Editors (not a development host)
    #   neovim   — full IDE: custom config, LSPs, opencode-nvim, claude wrapper
    #   vscodium — GUI editor: Catppuccin theme, Claude Code + OpenCode extensions
    #   zed      — fast Wayland-native editor (Rust), vim mode
    # ==============================================================
    #../../modules/development/editors/neovim/neovim.nix
    #../../modules/development/editors/vscodium/vscodium.nix
    ../../modules/development/editors/zed.nix

    # ==============================================================
    # Development — Languages (not a development host)
    #   python — python3, poetry, ruff, httpie
    #   rust   — rustup toolchain, cargo tools, just
    # ==============================================================
    #../../modules/development/languages/python.nix
    #../../modules/development/languages/rust.nix

    # ==============================================================
    # Services
    #   auto-update         — weekly nixos-rebuild from GitHub
    #   syncthing-babylinux — vault + nixos-config sync (babylinux pair)
    #   snapper             — BTRFS automatic snapshots
    # ==============================================================
    ../../modules/services/auto-update/auto-update.nix
    ../../modules/services/syncthing-babylinux.nix
    #../../modules/services/snapper.nix
    #../../modules/services/wallpaper-slideshow.nix
    #../../modules/services/samba.nix
    #../../modules/services/ntfy.nix
    #../../modules/services/vpn-qbittorrent.nix
    #../../modules/services/syncthing.nix

    # ==============================================================
    # Users
    #   ssh         — authorized keys for this host
    #   description — GECOS display name (agenix secret)
    #   (linuxury-ssh — the admin's key, for remote login)
    # ==============================================================
    ../../modules/users/babylinux/babylinux-ssh.nix
    ../../modules/users/babylinux/babylinux-description.nix
    ../../modules/users/linuxury/linuxury-ssh.nix
  ];

  # ==============================================================
  # Host identity
  # ==============================================================
  networking.hostName = "Ryzen5800x";

  # ==============================================================
  # GPU driver selection (hardware.gpu, defined by modules/hardware/drivers.nix;
  # "amd" = Radeon amdgpu/RADV stack)
  # ==============================================================
  hardware.gpu = "amd";

  # ==============================================================
  # Hardware toggles — option-gated modules (imported in flake.nix)
  #   openrgb          — RGB lighting: package + udev rules + daemon
  #   lemokey-keychron — WebHID udev rules for keyboard web configurators
  # ==============================================================
  # OpenRGB off: its boot-time device scan disconnects the HyperX Alloy Origins
  # keyboard from USB, which resets NumLock and its RGB. Re-enable only with the
  # HyperX detector disabled and a saved OpenRGB profile.
  hardware.openrgb.enable = false;
  hardware.lemokey-keychron.enable = false;

  # Primary user for the auto-update service: vault writes, notification
  # ownership and the smtp-app-password secret are scoped to it (see
  # modules/services/auto-update/auto-update.nix; default is linuxury).
  services.nixos-auto-update.primaryUser = "babylinux";

  # Session started by the display manager by default (KDE Plasma).
  services.displayManager.defaultSession = "plasma";

  # ==============================================================
  # Filesystem — local disks are in ./disk.nix; only network mounts here
  # ==============================================================
  fileSystems = {

    # -----------------------------------------------------------------------
    # Network shares (the three CIFS mounts below share one option set):
    #   credentials=...      agenix secret with the SMB username/password
    #   uid=babylinux        files appear owned by babylinux (gid=users)
    #   nofail, _netdev      boot continues without it; waits for the network
    #   noauto               not mounted at boot
    #   x-systemd.automount  mounts on first access
    #   idle-timeout=60      unmounts after 60 s idle
    #   mount-timeout=2s     give up quickly if the server is down
    # /mnt/Media-Server = Media-Server share; /mnt/MinisForum = GameServers share
    # (MinisForum); /mnt/Torrents = Downloads share (Media-Server).
    # -----------------------------------------------------------------------
    "/mnt/Media-Server" = {
      device  = "//10.0.0.3/Media-Server";
      fsType  = "cifs";
      options = [
        "credentials=/run/agenix/smb-credentials"
        "uid=babylinux" "gid=users"
        "nofail" "_netdev" "noauto"
        "x-systemd.automount" "x-systemd.idle-timeout=60"
        "x-systemd.mount-timeout=2s"
      ];
    };

    "/mnt/MinisForum" = {
      device  = "//10.0.0.7/GameServers";
      fsType  = "cifs";
      options = [
        "credentials=/run/agenix/smb-credentials"
        "uid=babylinux" "gid=users"
        "nofail" "_netdev" "noauto"
        "x-systemd.automount" "x-systemd.idle-timeout=60"
        "x-systemd.mount-timeout=2s"
      ];
    };

    "/mnt/Torrents" = {
      device  = "//10.0.0.3/Downloads";
      fsType  = "cifs";
      options = [
        "credentials=/run/agenix/smb-credentials"
        "uid=babylinux" "gid=users"
        "nofail" "_netdev" "noauto"
        "x-systemd.automount" "x-systemd.idle-timeout=60"
        "x-systemd.mount-timeout=2s"
      ];
    };

  };

  # ==============================================================
  # Mount point directories (tmpfiles "d path mode owner group age") for the
  # network mounts above and the local Warehouse disk (./disk.nix)
  # ==============================================================
  systemd.tmpfiles.rules = [
    "d /mnt/Media-Server 0755 babylinux users -"
    "d /mnt/MinisForum   0755 babylinux users -"
    "d /mnt/Torrents     0755 babylinux users -"
    "d /mnt/Warehouse    0755 babylinux users -"
  ];

  # ==============================================================
  # Agenix secrets — SMB credentials, readable by root only (mount.cifs)
  # ==============================================================
  age.secrets.smb-credentials = {
    file  = ../../secrets/network/smb-credentials.age;
    mode  = "0400";
    owner = "root";
  };

  # ==============================================================
  # Kernel
  # ==============================================================
  # Kernel package set: Zen (below). Alternatives (pick one):
  # boot.kernelPackages = pkgs.linuxPackages_latest;          # Vanilla
  # boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;  # XanMod
  boot.kernelPackages = pkgs.linuxPackages_zen;            # Zen

  # NTFS support (kernel ntfs3 driver and tools) for the Warehouse HDD
  boot.supportedFilesystems.ntfs = true;

  # ==============================================================
  # AMD Radeon RX 5700 XT specific settings
  #
  # The 5700 XT is an RDNA1 card with mature Linux driver support.
  # amdgpu.ppfeaturemask=0xffffffff unlocks all amdgpu power-play features
  # (needed by overclocking/fan tools such as CoreCtrl, which is not installed).
  # ==============================================================
  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff"
  ];

  # programs.affinity.enable = true;  # off: craft-apps (imported above) provides these apps

  # ==============================================================
  # System packages — cifs-utils (SMB mounts), ntfs3g (NTFS tools), remote
  # support (RustDesk), media (VLC), build output viewer (nom), Zoom.
  # ==============================================================
  environment.systemPackages = with pkgs; [
    cifs-utils
    ntfs3g

    # Remote support
    # ponytail: drop the override once nixpkgs' rustdesk-flutter builds again;
    # the override adds libsodium + pkg-config so libsodium-sys finds libsodium.pc
    (rustdesk-flutter.overrideAttrs (o: {
      buildInputs = (o.buildInputs or [ ]) ++ [ libsodium ];
      nativeBuildInputs = (o.nativeBuildInputs or [ ]) ++ [ pkg-config ];
    }))  # Open source remote desktop — remote support for this machine

    # Media
    vlc       # Reliable video player that plays anything

    # Everyday tools
    nix-output-monitor # Progress bar + TUI for nix builds (nom)
    zoom-us            # Video conferencing
    # obsidian           # Markdown-based notes app (not installed)

    # ==============================================================
    # Host-specific apps
    # Tools only this machine needs (editors, design/video/image tools) go here
    # so each host can enable/disable them independently. None at the moment:
    # craft-apps (imported above) supplies the creative apps.
    # ==============================================================
  ];

  # ==============================================================
  # Printing support
  #
  # CUPS handles printer management on Linux. Most modern printers
  # are detected automatically once this is enabled. Network printer
  # discovery (avahi) is enabled in system/graphical/graphical.nix, not here.
  #   drivers  gutenprint (wide range of printers), hplip (HP printers)
  # ==============================================================
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      gutenprint      # Supports a wide range of printers
      hplip           # HP printers specifically
    ];
  };

  # ==============================================================
  # User account — babylinux: normal user, zsh; groups: wheel (sudo),
  # networkmanager, video, audio, input, gamemode (GameMode's helper rules)
  # ==============================================================
  users.users.babylinux = {
    isNormalUser = true;
    extraGroups  = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
      "gamemode"
    ];
    shell = pkgs.zsh;
  };

  # linuxury user — remote admin: SSH + sudo (wheel), no home on this host
  # (home /var/empty, createHome false), group users, bash shell. The password
  # is set by hand on each host (mutableUsers).
  users.users.linuxury = {
    isNormalUser = true;
    extraGroups  = [ "wheel" ];
    home         = "/var/empty";
    createHome   = false;
    group        = "users";
    shell        = pkgs.bash;
  };

  # Hide linuxury from the login screen (account is for remote admin only)
  services.displayManager.hiddenUsers = [ "linuxury" ];

  # System-wide zsh (login shell for babylinux; the shell setup is in the user's Home Manager config)
  programs.zsh.enable = true;
}
