# ===========================================================================
# hosts/Alex-Laptop/Alex-Laptop.nix — Alex's Laptop (HP with AMD A-10 APU)
#
# Owner: alex
# Hardware: Older HP laptop, AMD A-10 APU (integrated graphics)
# Type: Laptop — kid focused
# Role: Kid's laptop — school, gaming, videos
#
# Enabled modules:
#   - AMD drivers
#   - COSMIC (default DE)
#   - Gaming
#   - Firefox with forced policies (via firefox.nix)
#
# Parental controls:
#   - Same as Alex-Desktop
#   - Extra power management for older battery
# ===========================================================================

{ pkgs, lib, ... }:

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
    #   firefox     — primary browser (locked down via policies)
    #   fluxer      — Discord client
    #   kdeconnect  — phone integration
    # ==============================================================
    ../../modules/system/graphical/firefox.nix
    #../../modules/system/graphical/helium.nix
    ../../modules/system/graphical/fluxer.nix
    ../../modules/system/graphical/craft-apps.nix
    #../../modules/services/kdeconnect.nix

    # ==============================================================
    # Desktop Environment — enable ONE (includes shell + greeter)
    # ==============================================================
    ../../modules/desktops/cosmic/cosmic.nix
    #../../modules/desktops/gnome/gnome.nix
    #../../modules/desktops/kde.nix

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
    # ==============================================================
    #../../modules/development/ai-tools/ai-tools.nix
    #../../modules/development/ai-tools/claude.nix
    #../../modules/development/ai-tools/opencode.nix
    #../../modules/development/ai-tools/local-llm.nix
    #../../modules/development/ai-tools/lm-studio.nix

    # ==============================================================
    # Development — Editors (not a development host)
    # ==============================================================
    #../../modules/development/editors/neovim/neovim.nix
    #../../modules/development/editors/vscodium/vscodium.nix
    #../../modules/development/editors/zed.nix

    # ==============================================================
    # Development — Languages (not a development host)
    # ==============================================================
    #../../modules/development/languages/python.nix
    #../../modules/development/languages/rust.nix

    # ==============================================================
    # Services
    #   auto-update — weekly nixos-rebuild from GitHub
    #   syncthing   — linuxury pair (admin access to sync config + vault)
    #   snapper     — BTRFS automatic snapshots
    # ==============================================================
    # DISABLED 2026-09-16: this host still needs the @steam btrfs
    # subvolume created before it's safe to switch (see PENDING.md) —
    # auto-update would crash-loop the boot the moment it fires, same as
    # it did on Ryzen5900x. Re-enable (uncomment this + the primaryUser
    # line below) once @steam has been created+populated here.
    # ../../modules/services/auto-update/auto-update.nix
    ../../modules/services/syncthing.nix
    #../../modules/services/snapper.nix
    #../../modules/services/wallpaper-slideshow.nix
    #../../modules/services/samba.nix
    #../../modules/services/ntfy.nix
    #../../modules/services/vpn-qbittorrent.nix
    #../../modules/services/syncthing-babylinux.nix

    # ==============================================================
    # Users
    #   alex: description — GECOS display name (agenix secret)
    #   alex: screen-time — login hours (pam_time) + cutoff logout
    #   alex: packages    — per-user package set
    #   linuxury: ssh     — emergency admin access + Syncthing
    # ==============================================================
    ../../modules/users/alex/alex-description.nix
    ../../modules/users/alex/screen-time.nix
    ../../modules/users/linuxury/linuxury-ssh.nix
  ];

  # ==============================================================
  # Host identity
  # ==============================================================
  networking.hostName = "Alex-Laptop";

  # services.nixos-auto-update.primaryUser = "alex"; # see DISABLED note above

  # ==============================================================
  # GPU driver selection
  #
  # AMD A-10 APU uses integrated Radeon graphics.
  # Same amdgpu driver as dedicated cards — works fine.
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
  # Filesystem — BTRFS with subvolumes
  # ==============================================================
  fileSystems = {

    # -----------------------------------------------------------------------
    # Media-Server Samba share
    # Read-only for alex — he can browse media but not accidentally delete.
    # Automounts on first access, disconnects after 60s idle.
    # -----------------------------------------------------------------------
    "/mnt/Media-Server" = {
      device  = "//10.0.0.3/Media-Server";
      fsType  = "cifs";
      options = [
        "credentials=/run/agenix/smb-credentials"
        "uid=alex" "gid=users"
        "ro"
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
        "uid=alex" "gid=users"
        "ro"
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
        "uid=alex" "gid=users"
        "ro"
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
    "d /mnt/Media-Server 0755 alex users -"
    "d /mnt/MinisForum   0755 alex users -"
    "d /mnt/Torrents     0755 alex users -"
  ];

  environment.systemPackages = with pkgs; [
    cifs-utils

    # alex — everyday tools
    nix-output-monitor # Progress bar + TUI for nix builds (nom)
    gcompris           # 100+ educational activities — ages 2-10
    freetube           # YouTube without ads, algorithm, or shorts

    # ==============================================================
    # Host-specific apps
    # Special tools only this machine needs — editors, creative tools,
    # etc. go here so each host can enable/disable them independently.
    # ==============================================================
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
  #
  # Using latest stable rather than testing on this older hardware.
  # Older AMD APUs are very well supported and stable — no need
  # to risk RC kernel instability on a kid's school laptop.
  # ==============================================================
  boot.kernelPackages = pkgs.linuxPackages_latest;           # Vanilla
  # boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;  # XanMod
  # boot.kernelPackages = pkgs.linuxPackages_zen;            # Zen

  # ==============================================================
  # Performance tweaks for older hardware
  #
  # The A-10 APU is older and lower powered. These tweaks help it
  # run more smoothly with limited resources.
  # ==============================================================
  boot.kernelParams = [
    "amdgpu.ppfeaturemask=0xffffffff"
    "mitigations=auto"    # Keep security mitigations but let kernel
                          # choose the least impactful ones for this CPU
  ];

  # ==============================================================
  # Power management — important for older laptop battery
  #
  # Older batteries benefit even more from conservative power management.
  # ==============================================================
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC  = "ondemand";   # Balanced on AC
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";  # Aggressive saving on battery
      CPU_ENERGY_PERF_POLICY_ON_AC  = "balance-performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # Conservative battery thresholds for older battery health
      START_CHARGE_THRESH_BAT0 = 20;
      STOP_CHARGE_THRESH_BAT0  = 80;

      PCIE_ASPM_ON_BAT = "powersupersave";

      # Aggressive disk power saving on battery
      DISK_APM_LEVEL_ON_BAT = "1";
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
    HandleLidSwitch              = "suspend";
    HandleLidSwitchExternalPower = "suspend";
    HandlePowerKey               = "suspend";
    IdleAction                   = "suspend";
    IdleActionSec                = "15min";
  };

  # ==============================================================
  # DNS filtering — same as Alex-Desktop
  # ==============================================================
  networking.nameservers = [ "1.1.1.3" "1.0.0.3" ];
  # mkForce needed because services.resolved sets this to "systemd-resolved"
  networking.networkmanager.dns = lib.mkForce "none";
  services.resolved = {
    enable = true;
    settings.Resolve.FallbackDNS = [ "1.1.1.3" "1.0.0.3" ];
  };

  # ==============================================================
  # Flatpak — infrastructure kept, all remotes removed
  # Same approach as Alex-Desktop — see comment there for full explanation.
  # ==============================================================
  system.activationScripts.removeFlatpakRemotes.text = ''
    for remote in $(${pkgs.flatpak}/bin/flatpak remote-list --system \
                    --columns=name 2>/dev/null | tail -n +1); do
      ${pkgs.flatpak}/bin/flatpak remote-delete --system --force \
        "$remote" 2>/dev/null || true
    done
  '';

  # ==============================================================
  # Packages
  #
  # Office apps come from the Craft office suite (below).
  # Gaming packages (prismlauncher, jdk17) are in
  # modules/gaming/gaming.nix (imported above).
  # Graphical tools (kitty, showtime, etc.) are in modules/system/graphical/graphical.nix.
  # Shell tools (fastfetch, btop) are in modules/system/core.nix.
  # ==============================================================
  craftApps.suites = [ "office" ];

  # ==============================================================
  # User account — no wheel, same restrictions as desktop
  # ==============================================================
  users.users.alex = {
    isNormalUser = true;
    extraGroups  = [
      "networkmanager"
      "video"
      "audio"
      "input"
      "gamemode"
    ];
    shell = pkgs.zsh;
  };

  # linuxury user — needed for Syncthing (vault sync) and auto-update notifications
  users.users.linuxury = {
    isNormalUser = true;
    extraGroups  = [ "wheel" "networkmanager" ];
    home         = "/home/linuxury";
    createHome   = true;
    group        = "users";
    shell        = pkgs.zsh;
  };

  # Hide linuxury from the login screen — emergency account only
  services.displayManager.hiddenUsers = [ "linuxury" ];

  programs.zsh.enable = true;
}
