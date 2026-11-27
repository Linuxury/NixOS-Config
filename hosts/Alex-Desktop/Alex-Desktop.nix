# ===========================================================================
# hosts/Alex-Desktop/Alex-Desktop.nix — child account desktop
#
# Hardware: older AMD CPU, AMD GPU (Radeon HD 3000, radeon driver)
# Type: desktop with no disk encryption, for gaming and education
# Role: desktop for the child account, with parental controls
#
# Enabled modules:
#   - AMD drivers
#   - COSMIC (default DE)
#   - Gaming
#   - Firefox with forced policies (via firefox.nix)
#
# Parental controls:
#   - Declarative app control (only what we define is available)
#   - DNS filtering via Cloudflare 1.1.1.3
#   - Flatpak installed, with all system remotes removed on each rebuild (see Flatpak below)
#   - Login time restrictions (modules/users/alex/screen-time)
#   - Firefox locked down via policies
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
    #   fluxer      — Fluxer chat client (canary, nixpkgs)
    #   kdeconnect  — phone integration
    # ==============================================================
    ../../modules/system/graphical/firefox.nix
    ../../modules/system/graphical/fluxer.nix
    #../../modules/services/kdeconnect.nix
    #../../modules/system/graphical/zen-browser.nix
    #../../modules/system/graphical/helium.nix
    #../../modules/system/graphical/craft-apps.nix

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
    # ==============================================================
    #../../modules/development/languages/python.nix
    #../../modules/development/languages/rust.nix

    # ==============================================================
    # Services
    #   auto-update — weekly nixos-rebuild from GitHub
    #   syncthing   — linuxury pair (admin access to sync config + vault)
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
  networking.hostName = "Alex-Desktop";

  services.nixos-auto-update.primaryUser = "alex";

  # Update timer (services.nixos-auto-update.schedule): 04:30 instead of the 03:00 default,
  # so this host does not update at the same time as the others.
  services.nixos-auto-update.schedule = "*-*-* 04:30";

  # ==============================================================
  # GPU driver selection
  # The motherboard's Radeon HD 3000 (760G chipset) is pre-GCN, so it uses the radeon
  # driver, not amdgpu. services.xserver.videoDrivers (mkForce) overrides the amd default
  # set in drivers.nix.
  # ==============================================================
  hardware.gpu = "amd";
  # Modules needed to read the disk and USB devices in the initrd (SATA AHCI, PATA, USB, SD).
  boot.initrd.availableKernelModules = [ "ahci" "ata_piix" "xhci_pci" "ehci_pci" "ohci_pci" "usb_storage" "sd_mod" ];
  boot.initrd.kernelModules = [];
  services.xserver.videoDrivers = lib.mkForce [ "radeon" ];

  # ==============================================================
  # Hardware toggles — option-gated modules (imported in flake.nix)
  #   openrgb          — RGB lighting: package + udev rules + daemon
  #   lemokey-keychron — WebHID udev rules for keyboard web configurators
  # ==============================================================
  hardware.openrgb.enable = false;
  hardware.lemokey-keychron.enable = false;

  # ==============================================================
  # Network shares — CIFS mounts, read-only for the child account
  #   ro                  read-only: browse, but no deleting or changing files
  #   uid=alex, gid=users owner of the files shown (the child account, group users)
  #   Each share mounts on first access and unmounts after 60 s idle.
  # The local disk layout is in disk.nix (no LUKS on this desktop).
  # ==============================================================
  fileSystems = {

    # -----------------------------------------------------------------------
    # Media-Server share (//10.0.0.3/Media-Server), read-only.
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

    # Everyday tools for the child account
    nix-output-monitor # Progress bar + TUI for nix builds (nom)
    gcompris           # Educational activities for young children
    freetube           # YouTube client without ads, the recommendation feed, or Shorts

    # ==============================================================
    # Host-specific apps
    # Special tools only this machine needs — editors, creative tools,
    # etc. go here so each host can enable/disable them independently.
    # ==============================================================
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
  boot.kernelPackages = pkgs.linuxPackages_latest;           # Vanilla
  # boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;  # XanMod
  # boot.kernelPackages = pkgs.linuxPackages_zen;            # Zen

  # ==============================================================
  # DNS filtering — Cloudflare 1.1.1.3
  #
  # 1.1.1.3 is Cloudflare's family-safe DNS resolver.
  # It automatically blocks malware and adult content at the DNS level
  # without any extra software needed.
  #
  # This applies system-wide — all apps and browsers on this machine
  # use these DNS servers regardless of what the user tries to change.
  # ==============================================================
  networking.nameservers = [
    "1.1.1.3"      # Cloudflare family DNS primary
    "1.0.0.3"      # Cloudflare family DNS secondary
  ];

  # Lock DNS so NetworkManager cannot override it.
  #   networking.networkmanager.dns  "none": NetworkManager leaves resolv.conf alone (mkForce,
  #                                  because services.resolved sets it to "systemd-resolved")
  #   services.resolved.enable       systemd-resolved as the resolver (set here)
  #   settings.Resolve.FallbackDNS   servers used if the main ones fail (the same family-safe pair)
  networking.networkmanager.dns = lib.mkForce "none";
  services.resolved = {
    enable = true;
    settings.Resolve.FallbackDNS = [ "1.1.1.3" "1.0.0.3" ];
  };

  # ==============================================================
  # Flatpak — infrastructure kept, all remotes removed
  #
  # cosmic.nix enables Flatpak (it powers the COSMIC app store backend).
  # We cannot mkForce false here because the Hytale install service
  # (modules/system/graphical/hytale.nix) downloads the launcher bundle from
  # hytale.com and runs `flatpak install --user`, which needs the flatpak binary.
  #
  # Instead of disabling Flatpak entirely, the activation script below removes all configured
  # system remotes on every rebuild. With no remotes:
  #   - the COSMIC store shows nothing to browse or install
  #   - the child account cannot add a system remote, because that needs root
  #   - a user-level remote needs terminal knowledge the child account does not use
  #   - a local .flatpak bundle still installs, because it does not need a remote
  #
  # The activation script (system.activationScripts.removeFlatpakRemotes) runs flatpak
  # remote-list and remote-delete for each system remote.
  # ==============================================================
  system.activationScripts.removeFlatpakRemotes.text = ''
    # Remove all system-level Flatpak remotes so the app store is empty.
    for remote in $(${pkgs.flatpak}/bin/flatpak remote-list --system \
                    --columns=name 2>/dev/null | tail -n +1); do
      ${pkgs.flatpak}/bin/flatpak remote-delete --system --force \
        "$remote" 2>/dev/null || true
    done
  '';

  # ==============================================================
  # Child-account packages
  #
  # Gaming packages (prismlauncher, jdk17) are in
  # modules/gaming/gaming.nix (imported above).
  # Graphical tools (kitty, showtime, etc.) are in modules/system/graphical/graphical.nix.
  # Shell tools (fastfetch, btop) are in modules/system/core.nix.
  # ==============================================================

  # ==============================================================
  # Sudo restriction
  #
  # The child account has no sudo access. wheel is left out of its extraGroups, so it cannot
  # install software or change system settings.
  # ==============================================================

  # ==============================================================
  # Child account (users.users.alex)
  #   isNormalUser  home directory and login account (set here)
  #   extraGroups   supplementary groups; no wheel, so no sudo (set here)
  #   shell         zsh (set here)
  # The administrator manages this machine remotely over SSH from the linuxury account.
  # ==============================================================
  users.users.alex = {
    isNormalUser = true;
    extraGroups  = [
      # No wheel — no sudo
      "networkmanager"  # Can connect to WiFi
      "video"
      "audio"
      "input"
      "gamemode"
    ];
    shell = pkgs.zsh;
  };

  # Administrator account (linuxury): remote admin access over SSH, with sudo for rebuilds.
  #   home / createHome   home directory at /home/linuxury, created if missing
  #   group               primary group users
  #   extraGroups         wheel (sudo)
  users.users.linuxury = {
    isNormalUser = true;
    home         = "/home/linuxury";
    createHome   = true;
    group        = "users";
    extraGroups  = [ "wheel" ];
    shell        = pkgs.zsh;
  };

  # Hide the administrator account from the login screen (services.displayManager.hiddenUsers).
  # It stays available for SSH and su.
  services.displayManager.hiddenUsers = [ "linuxury" ];

  # zsh: enabled system-wide so it can be the login shell.
  programs.zsh.enable = true;

  # Minimal Home Manager config for linuxury: the shared zshrc, so nru, nr and ngc work
  home-manager.users.linuxury = { lib, inputs, ... }: {
    home.stateVersion = "24.11";
    programs.zsh = {
      enable     = true;
      initContent = import "${inputs.zsh}/init.nix" { inherit lib; };
    };
  };
}
