# ===========================================================================
# hosts/Ryzen5800x/Ryzen5800x.nix — AMD Ryzen 7 5800x Desktop
#
# Owner: babylinux
# Hardware: AMD Ryzen 7 5800x, AMD Radeon RX 5700 XT
# Type: Desktop — no encryption, stable and reliable
# Role: Wife's daily driver desktop
#
# Enabled modules:
#   - AMD drivers
#   - KDE (default DE)
#   - COSMIC (disabled)
#   - Gaming
#
# No development tools — kept clean and simple.
# ===========================================================================

{ config, pkgs, ... }:

{
  imports = [
    # Disks, swap, LUKS and boot loader (written by the installer)
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
    #   Steam, Proton/Wine, Lutris, MangoHud, gamemode, controllers
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
    #   packages    — per-user package set
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
  # GPU driver selection
  # ==============================================================
  hardware.gpu = "amd";

  # ==============================================================
  # Hardware toggles — option-gated modules (imported in flake.nix)
  #   openrgb          — RGB lighting: package + udev rules + daemon
  #   lemokey-keychron — WebHID udev rules for keyboard web configurators
  # ==============================================================
  # OpenRGB off: its boot scan makes the HyperX Alloy Origins drop off USB (disconnect ~3 s after the
  # scan, every boot), which resets NumLock and RGB. The "main" profile never existed on this host anyway.
  # Re-enable only with the HyperX detector disabled + a real saved profile.
  hardware.openrgb.enable = false;
  hardware.lemokey-keychron.enable = false;

  services.nixos-auto-update.primaryUser = "babylinux";

  services.displayManager.defaultSession = "plasma";

  # ==============================================================
  # Filesystem — BTRFS with subvolumes, no LUKS on desktop
  # ==============================================================
  fileSystems = {

    # -----------------------------------------------------------------------
    # Media-Server Samba share
    # Automounts on first access, disconnects after 60s idle.
    # nofail: non-fatal if the server is offline.
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
  # Mount point directory + CIFS tools
  # ==============================================================
  systemd.tmpfiles.rules = [
    "d /mnt/Media-Server 0755 babylinux users -"
    "d /mnt/MinisForum   0755 babylinux users -"
    "d /mnt/Torrents     0755 babylinux users -"
    "d /mnt/Warehouse    0755 babylinux users -"
  ];

  # ==============================================================
  # Agenix secrets
  # ==============================================================
  age.secrets.smb-credentials = {
    file  = ../../secrets/smb-credentials.age;
    mode  = "0400";
    owner = "root";
  };

  # ==============================================================
  # Kernel
  # ==============================================================
  # boot.kernelPackages = pkgs.linuxPackages_latest;          # Vanilla
  # boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;  # XanMod
  boot.kernelPackages = pkgs.linuxPackages_zen;            # Zen

  # NTFS3 kernel driver for the Warehouse HDD
  boot.supportedFilesystems.ntfs = true;

  # ==============================================================
  # AMD Radeon RX 5700 XT specific settings
  #
  # The 5700 XT is an RDNA1 card. It has mature driver support on Linux
  # and works very reliably. CoreCtrl is available if she ever wants
  # GPU monitoring but we keep it optional here.
  # ==============================================================
  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff"
  ];

  # programs.affinity.enable = true;  # disabled 2026-10-08 — replaced by craft-apps

  # ==============================================================
  # Stability focused extras
  #
  # Since this is a machine you manage for someone else, we add a few
  # quality of life things that make it easier to support remotely.
  # ==============================================================
  environment.systemPackages = with pkgs; [
    cifs-utils
    ntfs3g

    # Remote support
    # TODO: re-enable once nixpkgs fixes rustdesk-flutter (libsodium-sys fails: libsodium.pc not found, 2026-11-10)
    # rustdesk-flutter  # Open source remote desktop — lets you help her remotely

    # Media
    vlc       # Reliable video player that plays anything

    # babylinux — everyday tools
    nix-output-monitor # Progress bar + TUI for nix builds (nom)
    zoom-us            # Video conferencing
    # obsidian           # Markdown-based knowledge base / note-taking app

    # ==============================================================
    # Host-specific apps
    # Special tools only this machine needs — editors, design tools,
    # video editors, image editors, etc. go here so each host can
    # enable/disable them independently.
    # ==============================================================
    # affinity-v3 disabled above (replaced by craft-apps)
  ];

  # ==============================================================
  # Printing support
  #
  # CUPS handles printer management on Linux. Most modern printers
  # are detected automatically once this is enabled. Network printer
  # discovery (avahi) is enabled universally in
  # system/graphical/graphical.nix, not duplicated here.
  # ==============================================================
  services.printing = {
    enable = true;
    drivers = with pkgs; [
      gutenprint      # Supports a wide range of printers
      hplip           # HP printers specifically
    ];
  };

  # ==============================================================
  # User account
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

  # linuxury user — remote admin: SSH + sudo (wheel), no home on this host.
  # Password set by hand per host (mutableUsers), like every other machine.
  users.users.linuxury = {
    isNormalUser = true;
    extraGroups  = [ "wheel" ];
    home         = "/var/empty";
    createHome   = false;
    group        = "users";
    shell        = pkgs.bash;
  };

  # Hide linuxury from the login screen — emergency account only
  services.displayManager.hiddenUsers = [ "linuxury" ];

  programs.zsh.enable = true;
}
