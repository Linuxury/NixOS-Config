# ===========================================================================
# hosts/Asus-A15/Asus-A15.nix — Asus TUF Gaming A15 FA506IU
#
# Owner: babylinux
# Hardware: AMD Ryzen 7 4800H, Nvidia GTX 1660 Ti (hybrid graphics)
# Type: Laptop — LUKS encrypted, hybrid GPU, gaming focused
# Role: Wife's laptop
#
# Enabled modules:
#   - Nvidia hybrid drivers (AMD iGPU + Nvidia dGPU)
#   - KDE (default DE)
#   - COSMIC (disabled)
#   - Gaming
#
# Special considerations:
#   - Hybrid graphics requires PRIME offloading
#   - Asus battery management via asusctl
#   - PCI bus IDs must be filled in manually (see docs/)
# ===========================================================================

{ pkgs, ... }:

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
    #../../modules/development/ai-tools/ai-tools.nix
    #../../modules/development/ai-tools/claude.nix
    #../../modules/development/ai-tools/opencode.nix
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
    #../../modules/development/editors/zed.nix

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
    # DISABLED 2026-09-16: this host still needs the @steam btrfs
    # subvolume created before it's safe to switch (see PENDING.md) —
    # auto-update would crash-loop the boot the moment it fires, same as
    # it did on Ryzen5900x. Re-enable (uncomment this + the primaryUser
    # line below) once @steam has been created+populated here.
    # ../../modules/services/auto-update/auto-update.nix
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
  networking.hostName = "Asus-A15";

  # ==============================================================
  # GPU driver selection
  # Nvidia hybrid triggers the PRIME offload setup in drivers.nix
  # ==============================================================
  # TODO: switch back to "nvidia-hybrid" once PCI bus IDs are filled in above
  hardware.gpu = "amd";

  # ==============================================================
  # Hardware toggles — option-gated modules (imported in flake.nix)
  #   openrgb          — RGB lighting: package + udev rules + daemon
  #   lemokey-keychron — WebHID udev rules for keyboard web configurators
  # ==============================================================
  hardware.openrgb.enable = false;
  hardware.lemokey-keychron.enable = false;

  # ==============================================================
  # PRIME PCI Bus IDs
  #
  # These values are placeholders — you MUST replace them with the
  # actual IDs from this specific machine.
  #
  # To find them, boot any Linux live USB on the Asus A15 and run:
  #   lspci | grep -E "VGA|3D"
  #
  # Example output:
  #   05:00.0 VGA compatible controller: Advanced Micro Devices [AMD/ATI] ...
  #   01:00.0 3D controller: NVIDIA Corporation TU116M [GeForce GTX 1660 Ti]
  #
  # Convert to Nix format: "05:00.0" becomes "PCI:5:0:0"
  # Then fill in below and remove this comment block.
  # This is tracked in docs/manual-steps.md
  # ==============================================================
  # hardware.nvidia.prime = {
  #   amdgpuBusId = "PCI:FILL:IN"; # AMD iGPU — replace with actual ID
  #   nvidiaBusId = "PCI:FILL:IN"; # Nvidia dGPU — replace with actual ID
  # };
  # TODO: fill in PCI bus IDs from: lspci | grep -E "VGA|3D"

  # services.nixos-auto-update.primaryUser = "babylinux"; # see DISABLED note above

  services.displayManager.defaultSession = "plasma";

  # ==============================================================
  # Filesystem — BTRFS with subvolumes on top of LUKS
  # ==============================================================
  fileSystems = {

    # -----------------------------------------------------------------------
    # Media-Server Samba share
    # Automounts on first access, disconnects after 60s idle.
    # nofail: non-fatal if the server is offline (common on laptop away from home).
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

  # Craft apps — Office + Design suites only on the laptop
  craftApps.suites = [ "office" "design" ];

  # ==============================================================
  # Mount point directory + CIFS tools
  # ==============================================================
  systemd.tmpfiles.rules = [
    "d /mnt/Media-Server 0755 babylinux users -"
    "d /mnt/MinisForum   0755 babylinux users -"
    "d /mnt/Torrents     0755 babylinux users -"
  ];

  environment.systemPackages = with pkgs; [
    cifs-utils

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
    # affinity-v3  # re-enable when vc_redist.x64.exe CDN recovers (Microsoft 503s as of 2026-07-04)
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
  boot.kernelPackages = pkgs.linuxPackages_latest;          # Vanilla
  # boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;  # XanMod
  # boot.kernelPackages = pkgs.linuxPackages_zen;            # Zen

  # ==============================================================
  # Asus TUF specific kernel modules
  #
  # asus-wmi and asus-nb-wmi handle Asus-specific hardware:
  #   - Keyboard backlight control
  #   - Fan boost modes
  #   - ROG/TUF hotkeys
  # ==============================================================
  boot.kernelModules = [ "asus-wmi" "asus-nb-wmi" ];

  # ==============================================================
  # asusctl — Asus laptop control daemon
  #
  # asusctl gives you control over Asus-specific features:
  #   - Battery charge limit (e.g. stop charging at 80%)
  #   - Fan curves and performance profiles
  #   - Keyboard backlight (if available)
  #
  # After first boot set battery limit with:
  #   asusctl -c 80
  # ==============================================================
  services.asusd.enable = true;

  # ==============================================================
  # Power management for hybrid laptop
  #
  # supergfxctl works alongside asusctl to manage GPU switching.
  # It handles powering down the Nvidia GPU when not in use which
  # is critical for battery life on hybrid graphics laptops.
  # ==============================================================
  services.supergfxd.enable = true;

  # TLP for general power management
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC  = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC  = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      # Battery threshold — keeps battery healthy long term
      START_CHARGE_THRESH_BAT0 = 20;
      STOP_CHARGE_THRESH_BAT0  = 80;
      PCIE_ASPM_ON_BAT = "powersupersave";
    };
  };

  services.power-profiles-daemon.enable = false;

  # ==============================================================
  # Touchpad
  # ==============================================================
  services.libinput = {
    enable = true;
    touchpad = {
      tapping            = true;
      naturalScrolling   = true;
      scrollMethod       = "twofinger";
      middleEmulation    = true;
      disableWhileTyping = true;
    };
  };

  # ==============================================================
  # Lid and power button behavior
  # ==============================================================
  services.logind.settings.Login = {
    HandleLidSwitch              = "suspend";   # Suspend on lid close
    HandleLidSwitchExternalPower = "suspend";   # Even on AC
    HandlePowerKey               = "suspend";
    IdleAction                   = "suspend";
    IdleActionSec                = "20min";
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
