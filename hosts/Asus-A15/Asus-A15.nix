# ===========================================================================
# hosts/Asus-A15/Asus-A15.nix — Asus TUF Gaming A15 FA506IU laptop
#
# Hardware: AMD Ryzen 7 4800H, Nvidia GTX 1660 Ti (hybrid graphics)
# Type: laptop with LUKS full-disk encryption (disk.nix), hybrid GPU, for gaming
# Role: the babylinux account's laptop
#
# Enabled modules:
#   - AMD drivers (hardware.gpu = "amd", see the GPU section)
#   - KDE Plasma desktop (the default session)
#   - Gaming, Asus laptop control (asusctl, supergfxctl)
#
# Special considerations:
#   - Hybrid graphics needs PRIME offloading. It stays commented out until the bus IDs are filled in.
#   - Asus battery management and fan profiles come from asusctl.
#   - The PCI bus IDs are placeholders and must be filled in on this machine (see the PRIME section).
# ===========================================================================

{ pkgs, ... }:

{
  imports = [
    # Local filesystems, LUKS, swap (disk.nix)
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
    #   fluxer      — Fluxer chat client (canary, nixpkgs)
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
    # Development — Editors
    #   vscode   — VS Code (Microsoft build), sets VISUAL="code --wait"
    #   helix    — LSPs + "Helix" desktop entry for text files; the helix
    #              package and EDITOR=hx come from core.nix on every host
    #   off: neovim, vscodium, zed (uncomment to turn one back on)
    # ==============================================================
    ../../modules/development/editors/vscode/vscode.nix
    ../../modules/development/editors/helix.nix
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
    # Auto-update is off on this host until the @steam Btrfs subvolume exists and holds the
    # Steam library (disk.nix mounts it at the Steam path). Before then, auto-update would
    # fail on boot. To re-enable: uncomment this line and the primaryUser line below.
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
  # GPU driver selection (hardware.gpu)
  #   "nvidia-hybrid"  AMD iGPU and Nvidia dGPU with PRIME offload (drivers.nix); needs the bus IDs below
  #   "amd"            AMD only (set here)
  # TODO: switch to "nvidia-hybrid" once the PCI bus IDs are filled in below.
  # ==============================================================
  hardware.gpu = "amd";

  # ==============================================================
  # Hardware toggles — option-gated modules (imported in flake.nix)
  #   openrgb          — RGB lighting: package + udev rules + daemon
  #   lemokey-keychron — WebHID udev rules for keyboard web configurators
  # ==============================================================
  hardware.openrgb.enable = false;
  hardware.lemokey-keychron.enable = false;

  # ==============================================================
  # PRIME PCI bus IDs — hardware.nvidia.prime (commented out until filled in)
  #   amdgpuBusId  the AMD iGPU
  #   nvidiaBusId  the Nvidia dGPU
  # The values below are placeholders. Replace them with this machine's IDs, then uncomment the block.
  # To find them, boot a Linux live system on this laptop and run:
  #   lspci | grep -E "VGA|3D"
  # Example output:
  #   05:00.0 VGA compatible controller: Advanced Micro Devices [AMD/ATI] ...
  #   01:00.0 3D controller: NVIDIA Corporation TU116M [GeForce GTX 1660 Ti]
  # Convert to Nix format: "05:00.0" becomes "PCI:5:0:0".
  # ==============================================================
  # hardware.nvidia.prime = {
  #   amdgpuBusId = "PCI:FILL:IN"; # AMD iGPU — replace with actual ID
  #   nvidiaBusId = "PCI:FILL:IN"; # Nvidia dGPU — replace with actual ID
  # };
  # TODO: fill in PCI bus IDs from: lspci | grep -E "VGA|3D"

  # services.nixos-auto-update.primaryUser = "babylinux"; # set this when auto-update is re-enabled (see the imports block)

  # Session the display manager pre-selects (services.displayManager.defaultSession): Plasma (KDE).
  services.displayManager.defaultSession = "plasma";

  # ==============================================================
  # Network shares — CIFS mounts from the home servers
  #   uid=babylinux, gid=users owner of the files shown (group users)
  #   nofail   boot continues if the server is offline (common away from home)
  #   Each share mounts on first access and unmounts after 60 s idle.
  # The local BTRFS-on-LUKS layout is in disk.nix.
  # ==============================================================
  fileSystems = {

    # -----------------------------------------------------------------------
    # Media-Server share (//10.0.0.3/Media-Server).
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

  # craft-apps suites installed on this laptop: office, photo, graphics, 3d (craftApps.suites)
  craftApps.suites = [ "office" "photo" "graphics" "3d" ];

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

    # Everyday tools for the babylinux account
    nix-output-monitor # Progress bar + TUI for nix builds (nom)
    zoom-us            # Video conferencing
    # obsidian           # Markdown-based knowledge base / note-taking app

    # ==============================================================
    # Host-specific apps
    # Special tools only this machine needs — editors, design tools,
    # video editors, image editors, etc. go here so each host can
    # enable/disable them independently.
    # ==============================================================
    # affinity-v3  # off: re-enable once the vc_redist.x64.exe download (Microsoft's CDN) works
  ];

  # ==============================================================
  # Agenix secrets — the SMB login for the CIFS mounts above (root-only, mode 0400)
  # ==============================================================
  age.secrets.smb-credentials = {
    file  = ../../secrets/network/smb-credentials.age;
    mode  = "0400";
    owner = "root";
  };

  # ==============================================================
  # Kernel — boot.kernelPackages (set here: linuxPackages_latest, the mainline latest)
  #   pkgs.linuxPackages_xanmod_latest and pkgs.linuxPackages_zen are commented out.
  # ==============================================================
  boot.kernelPackages = pkgs.linuxPackages_latest;          # Vanilla
  # boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;  # XanMod
  # boot.kernelPackages = pkgs.linuxPackages_zen;            # Zen

  # ==============================================================
  # Asus TUF kernel modules (boot.kernelModules)
  #   asus-wmi, asus-nb-wmi  Asus WMI drivers: keyboard backlight, fan boost modes, hotkeys
  # ==============================================================
  boot.kernelModules = [ "asus-wmi" "asus-nb-wmi" ];

  # ==============================================================
  # asusctl — Asus laptop control daemon (services.asusd.enable, set here)
  #   charge limit   stop charging at a set percentage (for example 80)
  #   fan curves     and performance profiles
  #   keyboard backlight, where the hardware has one
  # After first boot, set the charge limit with: asusctl -c 80
  # ==============================================================
  services.asusd.enable = true;

  # ==============================================================
  # Hybrid GPU power — supergfxctl (services.supergfxd.enable, set here)
  # Works with asusctl to switch GPUs. It powers the Nvidia GPU down when it is not in use,
  # which matters for battery life on hybrid graphics laptops.
  # ==============================================================
  services.supergfxd.enable = true;

  # TLP for general power management (services.tlp, written to tlp.conf).
  # AC = on charger, BAT = on battery. See tlp.conf(5) for each key.
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

  # power-profiles-daemon is off: TLP manages the power settings, and the two conflict.
  services.power-profiles-daemon.enable = false;

  # ==============================================================
  # Touchpad — libinput (services.libinput.touchpad)
  #   tapping               tap to click (set here)
  #   naturalScrolling      reverse scroll direction (set here)
  #   scrollMethod          "twofinger": scroll with two fingers (set here)
  #   middleEmulation       pressing left and right together acts as a middle click (set here)
  #   disableWhileTyping    ignore the touchpad while typing (set here)
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
  # User accounts
  # The babylinux account (daily user, with sudo through wheel) is the one used on this laptop.
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

  # Administrator account (linuxury): remote admin over SSH with sudo (wheel). It has no home
  # directory on this host. Its password is set by hand on each host (mutableUsers).
  users.users.linuxury = {
    isNormalUser = true;
    extraGroups  = [ "wheel" ];
    home         = "/var/empty";
    createHome   = false;
    group        = "users";
    shell        = pkgs.bash;
  };

  # Hide the administrator account from the login screen (emergency account only).
  services.displayManager.hiddenUsers = [ "linuxury" ];

  programs.zsh.enable = true;
}
