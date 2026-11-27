# ===========================================================================
# hosts/ThinkPad/ThinkPad.nix — Lenovo ThinkPad T14s Gen 4 (AMD) laptop
#
# Hardware: AMD Ryzen 7 PRO 7840U, Radeon 780M iGPU
# Type: laptop with LUKS full-disk encryption (disk.nix) and TLP power management
# Role: personal daily-driver laptop
#
# Enabled modules:
#   - AMD drivers
#   - COSMIC desktop with cosmic-greeter
#   - Gaming
#   - Development (AI tools, editors, Python)
#
# Hyprland, Niri, GNOME, KDE, wayle and noctalia are in the imports block, commented out.
# Only one desktop and one compositor should be active. To change one, uncomment its line
# and comment out the current one.
# ===========================================================================

{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

{
  imports = [
    # Disks, swap, LUKS and boot loader (written by the installer)
    ./disk.nix

    # ==============================================================
    # System
    #   nixos-hardware — ThinkPad T14s AMD Gen4: thermal, power, fingerprint
    #   core           — locale, fonts, nix daemon, base CLI, boot defaults
    #   graphical      — Wayland stack, PipeWire audio, XDG portals, base pkgs
    # ==============================================================
    inputs.nixos-hardware.nixosModules.lenovo-thinkpad-t14s-amd-gen4
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
    #   zen-browser  — primary browser (privacy-focused Firefox fork)
    #   thunderbird  — email client
    #   fluxer       — Fluxer chat client (canary, nixpkgs)
    #   kdeconnect   — phone integration
    #   zennotes     — keyboard-first Markdown notes (connects to Media-Server:7879)
    # ==============================================================
    #../../modules/system/graphical/zen-browser.nix
    ../../modules/system/graphical/thunderbird.nix
    ../../modules/system/graphical/app-zennotes.nix
    ../../modules/system/graphical/app-nowted.nix
    ../../modules/system/graphical/fluxer.nix
    ../../modules/system/graphical/craft-apps.nix
    ../../modules/system/graphical/claude-desktop.nix
    ../../modules/system/graphical/mailcraft.nix
    ../../modules/services/kdeconnect.nix
    ../../modules/system/graphical/firefox.nix
    #../../modules/system/graphical/helium.nix

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
    # Development — AI Tools
    #   ai-tools  — base: nix-ld, uv, ffmpeg (import alongside tools below)
    #   claude    — Claude Code CLI + VSCodium extension
    #   opencode  — OpenCode CLI + VSCodium extension
    #   local-llm — Ollama + ROCm (disabled — laptop VRAM too limited)
    #   lm-studio — GUI LLM runner (requires ai-tools)
    # ==============================================================
    ../../modules/development/ai-tools/ai-tools.nix
    ../../modules/development/ai-tools/claude.nix
    ../../modules/development/ai-tools/opencode.nix
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
    # Development — Languages
    #   python — python3, poetry, ruff, httpie
    #   rust   — rustup toolchain, cargo tools, just
    # ==============================================================
    ../../modules/development/languages/python.nix
    #../../modules/development/languages/rust.nix

    # ==============================================================
    # Services
    #   auto-update — weekly nixos-rebuild from GitHub
    #   syncthing   — vault + nixos-config sync (linuxury pair)
    #   snapper     — BTRFS automatic snapshots
    # ==============================================================
    ../../modules/services/auto-update/auto-update.nix
    ../../modules/services/syncthing.nix
    #../../modules/services/snapper.nix
    #../../modules/services/wallpaper-slideshow.nix
    #../../modules/services/samba.nix
    #../../modules/services/ntfy.nix
    #../../modules/services/vpn-qbittorrent.nix
    #../../modules/services/syncthing-babylinux.nix

    # ==============================================================
    # Users
    #   ssh         — authorized keys for this host
    #   description — GECOS display name (agenix secret)
    #   packages    — per-user package set
    # ==============================================================
    ../../modules/users/linuxury/linuxury-ssh.nix
    ../../modules/users/linuxury/linuxury-description.nix
  ];

  # ==============================================================
  # Host identity
  # ==============================================================
  networking.hostName = "ThinkPad";

  # Update timer (services.nixos-auto-update.schedule): 03:30 instead of the 03:00 default,
  # so this host does not update at the same time as the others.
  services.nixos-auto-update.schedule = "*-*-* 03:30";

  # ==============================================================
  # GPU driver selection — tells drivers.nix which profile to use
  # ==============================================================
  hardware.gpu = "amd";

  # ==============================================================
  # Hardware toggles — option-gated modules (imported in flake.nix)
  #   openrgb          — RGB lighting: package + udev rules + daemon
  #   lemokey-keychron — WebHID udev rules for keyboard web configurators
  # ==============================================================
  hardware.openrgb.enable = false;
  hardware.lemokey-keychron.enable = true;

  # ==============================================================
  # SwayNC Control Panel — hardware capabilities (Hyprland only)
  # Uncomment when hyprland.nix is active.
  #
  # Verify device names on first boot:
  #   ls /sys/class/backlight/   → confirm backlightDevice
  #   ls /sys/class/leds/ | grep kbd → confirm kbBacklightDevice
  # ==============================================================
  # myModules.swaync.hasBacklight      = true;
  # myModules.swaync.backlightDevice   = "amdgpu_bl1";  # typical AMD ThinkPad T14s
  # myModules.swaync.hasKbBacklight    = true;
  # myModules.swaync.kbBacklightDevice = "tpacpi::kbd_backlight";
  # myModules.swaync.hasWifi           = true;
  # myModules.swaync.hasBluetooth      = true;

  # Early KMS — load the AMD GPU driver inside initrd so Plymouth gets a real
  # framebuffer before the root filesystem is mounted. Without this, Plymouth
  # falls back to the VGA text console and the LUKS passphrase prompt appears
  # as a tiny line at the top of the screen instead of a centered graphical UI.
  boot.initrd.kernelModules = [ "amdgpu" ];

  # ==============================================================
  # Network shares — CIFS mounts from the home servers
  #
  # The local BTRFS subvolumes and the LUKS container are in disk.nix. Each share below
  # mounts on first access and unmounts after 60 s idle. Options used on each share:
  #   credentials=<file>        username and password, from the agenix secret below
  #   uid=<n>, gid=<n>          owner of files when the server reports none (gid 100 = users)
  #   nofail                    a missing share does not stop boot (e.g. when away from home)
  #   _netdev                   network mount: ordered after the network is up
  #   noauto                    not mounted at boot or by nixos-rebuild switch
  #   x-systemd.automount       mount on first access
  #   x-systemd.idle-timeout=60 unmount after 60 s without access
  #   x-systemd.mount-timeout=2s give up if the mount command takes longer than 2 s
  # ==============================================================
  fileSystems = {

    # -----------------------------------------------------------------------
    # Media-Server share (//10.0.0.3/Media-Server), mounted at /mnt/Media-Server.
    # Mount by hand with: sudo mount /mnt/Media-Server
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
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=60"
        "x-systemd.mount-timeout=2s"
      ];
    };

    # -----------------------------------------------------------------------
    # MinisForum share (//10.0.0.7/GameServers), mounted at /mnt/MinisForum.
    # Used to manage game server files. Mount by hand with: sudo mount /mnt/MinisForum
    # -----------------------------------------------------------------------
    "/mnt/MinisForum" = {
      device = "//10.0.0.7/GameServers";
      fsType = "cifs";
      options = [
        "credentials=/run/agenix/smb-credentials"
        "uid=${toString config.users.users.linuxury.uid}"
        "gid=100"
        "nofail"
        "_netdev"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=60"
        "x-systemd.mount-timeout=2s"
      ];
    };

    "/mnt/Torrents" = {
      device = "//10.0.0.3/Downloads";
      fsType = "cifs";
      options = [
        "credentials=/run/agenix/smb-credentials"
        "uid=${toString config.users.users.linuxury.uid}"
        "gid=100"
        "nofail"
        "_netdev"
        "noauto"
        "x-systemd.automount"
        "x-systemd.idle-timeout=60"
        "x-systemd.mount-timeout=2s"
      ];
    };

  };

  # ==============================================================
  # CIFS tools — required for Samba/SMB mounts
  # ==============================================================
  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "add-host" (builtins.readFile ../../scripts/add-host))  # register a host key + re-key secrets (NixOS-Installer's Secrets step)
    (writeShellScriptBin "install-host" (builtins.readFile ../../scripts/install-host))  # run NixOS-Installer on a live-ISO machine over SSH
    cifs-utils

    # Everyday tools
    inputs.nixpkgs-goose.legacyPackages.${pkgs.stdenv.hostPlatform.system}.topgrade  # from the nixpkgs-goose input, pinned: the unstable aws-lc-sys build fails. One-command updater for Nix, cargo, flatpaks, etc.
    bat                # cat with syntax highlighting and line numbers
    herdr              # CLI — agent multiplexer TUI (delete this line for desktop only)
    herdr-desktop      # GUI app — persistent terminals + agents (delete this line for CLI only)
    herdr-core         # hc — talk to herdr-app terminals/agents (needed by herdr-team)
    lazygit            # TUI for git — stage, commit, branch all in one
    gh                 # GitHub CLI — PRs, issues from terminal
    delta              # Pretty diff viewer — integrates with git
    dust               # Visual disk usage — like du but readable
    procs              # Modern ps replacement with color and filtering
    whois              # Domain registration lookup
    traceroute         # Trace network path to a host
    # obsidian           # Markdown-based knowledge base / note-taking app
    fluent-reader      # RSS feed reader — clean GTK app for following news/blogs
    # obs-studio         # Screen recording and streaming
    p7zip              # Extract .7z, .rar, and many other archive formats
    imagemagick        # CLI image conversion and manipulation
    nix-output-monitor # Progress bar + TUI for nix builds (nom)

    # ==============================================================
    # Host-specific apps
    # Special tools only this machine needs — editors, design tools,
    # video editors, image editors, etc. go here so each host can
    # enable/disable them independently.
    # ==============================================================
    # affinity-v3  # off: re-enable once the vc_redist.x64.exe download (Microsoft's CDN) works
  ];

  # ==============================================================
  # Mount point directories for the shares above
  #   "d <path> <mode> <owner> <group> -": create the directory, mode 0755, owned by linuxury:users
  # ==============================================================
  systemd.tmpfiles.rules = [
    "d /mnt/Media-Server 0755 linuxury users -"
    "d /mnt/MinisForum   0755 linuxury users -"
    "d /mnt/Torrents     0755 linuxury users -"
  ];

  # ==============================================================
  # Agenix secrets — encrypted files in secrets/, decrypted at boot into /run/agenix/<name>
  #   file   the encrypted .age file (required)
  #   mode   permissions of the decrypted file, chmod style (default "0400")
  #   owner  user that owns the decrypted file (default "0", root)
  #   group  group that owns it (default: the owner's primary group)
  # ==============================================================

  # Samba login for the CIFS mounts above. Readable by root only.
  age.secrets.smb-credentials = {
    file = ../../secrets/network/smb-credentials.age;
    mode = "0400";
    owner = "root";
  };

  # API key for OpenRouter. Readable by root and members of the users group.
  age.secrets.openrouter-api-key = {
    file = ../../secrets/api-keys/openrouter.age;
    mode = "0440";
    owner = "root";
    group = "users";
  };

  # License file for the Flow icon set. Readable by root and members of the users group.
  age.secrets.flow-icons-license = {
    file = ../../secrets/licenses/flow-icons.age;
    mode = "0440";
    owner = "root";
    group = "users";
  };

  # ==============================================================
  # Kernel — boot.kernelPackages selects the kernel package set
  #   pkgs.linuxPackages_latest           mainline latest (set here)
  #   pkgs.linuxPackages_xanmod_latest    XanMod latest (commented out)
  #   pkgs.linuxPackages_zen              Zen kernel (commented out)
  # To switch, comment out the active line and uncomment another one.
  # ==============================================================
  boot.kernelPackages = pkgs.linuxPackages_latest;          # Vanilla
  # boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;  # XanMod
  # boot.kernelPackages = pkgs.linuxPackages_zen;            # Zen

  # ==============================================================
  # Power management — TLP (services.tlp, written to tlp.conf)
  #   enable    run TLP (set here)
  #   settings  TLP keys; AC = on charger, BAT = on battery. See tlp.conf(5) for each key.
  # ==============================================================
  services.tlp = {
    enable = true;
    settings = {
      # CPU frequency governor: full speed on AC, powersave on battery.
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "powersave";

      # AMD energy/performance preference: performance on AC, power on battery.
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";

      # Battery charge thresholds, handled by the ThinkPad embedded controller. Charging starts
      # when the charge drops below 75 % and stops at 95 %.
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 95;

      # PCIe link power management on battery: powersupersave is the lowest-power setting.
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
      tapping = true;
      naturalScrolling = true;
      scrollMethod = "twofinger";
      middleEmulation = true;
      disableWhileTyping = true;
    };
  };

  # ==============================================================
  # Fingerprint reader — fprintd
  #
  # The T14s G4 has a fingerprint reader supported by fprintd.
  # After installation, enroll your finger with:
  #   fprintd-enroll
  #
  # Then you can use your fingerprint for:
  #   - sudo authentication
  #   - login screen authentication
  # ==============================================================
  services.fprintd.enable = true;

  # Allow PAM to use the fingerprint reader for login, sudo and polkit prompts.
  # login uses mkForce because the GDM module sets login.fprintAuth = false when fprintd is
  # enabled. This host uses cosmic-greeter, not GDM, so the override is only needed with GDM.
  security.pam.services = {
    login.fprintAuth = lib.mkForce true;
    sudo.fprintAuth = true;
    polkit-1.fprintAuth = true;
  };

  # ==============================================================
  # Firmware — required for WiFi (Qualcomm QCNFA765 / ath12k)
  #
  # Without linux-firmware, the ath12k driver loads but finds no firmware
  # files and refuses to bind — leaving the WiFi adapter invisible to the
  # system. enableRedistributableFirmware pulls in linux-firmware which
  # contains the WCN7850/ath12k blobs needed for this card.
  # ==============================================================
  hardware.enableRedistributableFirmware = true;

  # ==============================================================
  # Laptop specific kernel modules
  #
  # thinkpad_acpi — fan control, hotkeys, LED control, battery events
  #
  # No acpi_call: the T14s Gen 4 exposes charge thresholds natively via
  # sysfs (NATACPI), which TLP 1.4+ uses automatically. Loading acpi_call
  # triggers ACPI method execution during TLP restarts (e.g. nixos-rebuild
  # switch) that can freeze the system.
  # ==============================================================
  boot.kernelModules = [ "thinkpad_acpi" ];

  # ==============================================================
  # Lid, power button and idle behavior (services.logind.settings.Login)
  #   HandleLidSwitch              action when the lid closes on battery: suspend (set here)
  #   HandleLidSwitchExternalPower action when the lid closes on AC: suspend (set here)
  #   HandlePowerKey               action for the power button: suspend (set here)
  #   IdleAction, IdleActionSec    action after idle time: suspend after 20 min (set here)
  # ==============================================================
  services.logind = {
    settings.Login = {
      HandleLidSwitch = "suspend";
      HandleLidSwitchExternalPower = "suspend";
      HandlePowerKey = "suspend";
      IdleAction = "suspend";
      IdleActionSec = "20min";
    };
  };

  # ==============================================================
  # User account
  #
  # This defines your system user. The password is set separately
  # (never put passwords in config files — use passwd after first boot).
  # ==============================================================
  users.users.linuxury = {
    isNormalUser = true;
    extraGroups = [
      "wheel" # sudo access
      "networkmanager" # manage network connections without sudo
      "video" # access to video devices
      "audio" # access to audio devices
      "input" # access to input devices (controllers, etc)
      "gamemode" # access to GameMode daemon
    ];
    shell = pkgs.zsh;
  };

  # Tailscale is enabled in core.nix (services.tailscale.enable). On a new machine, sign in once
  # with: sudo tailscale up

  # ==============================================================
  # Zsh — enable system-wide so it's available as a login shell
  # Actual configuration lives in modules/users/linuxury/linuxury-home.nix
  # ==============================================================
  programs.zsh.enable = true;
}
