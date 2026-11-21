# ===========================================================================
# modules/system/core.nix — Shared base configuration for ALL hosts
#
# Base configuration that every host (desktops, laptops, servers) imports:
# boot, networking, SSH, locale, audio, Nix settings, build memory limits,
# fonts, base packages, polkit, sysctl, Bluetooth, firmware updates and
# Tailscale. It has no enable flag; a host turns it off only by not
# importing it.
#
# Anything every host needs lives here; anything only some hosts need
# belongs in a more specific module. Most values are plain settings, so a
# host overrides them with lib.mkForce; values wrapped in lib.mkDefault can
# be overridden with a plain assignment.
# ===========================================================================

{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    # Automatic BTRFS snapshots + monthly scrub on every host
    ../services/snapper.nix

    # Per-host nix max-jobs/cores, derived from hosts/<host>/specs.nix
    ./build-capacity.nix
  ];
  # =========================================================================
  # BOOT — systemd-boot + Plymouth
  #
  # systemd-boot is a simple UEFI bootloader (GRUB is the alternative,
  # boot.loader.grub). It reads entries from /boot/loader/entries/ and lists
  # one per NixOS generation.
  #   systemd-boot.configurationLimit  generations kept in the menu
  #   efi.canTouchEfiVariables         let the installer write EFI boot vars
  #   timeout                          menu wait in seconds (0 = hidden)
  # Also available, not set here: systemd-boot.editor (kernel-line edit,
  # default true), consoleMode, memtest86 / netbootxyz / edk2-uefi-shell
  # entries, extraEntries, windows (dual-boot entries).
  #
  # Plymouth shows a graphical boot splash instead of kernel messages.
  # =========================================================================
  boot = {
    loader = {
      systemd-boot = {
        enable = true;
        # Generations kept in the boot menu; older entries are removed
        # from /boot. 10 leaves room to roll back without filling /boot.
        configurationLimit = 10;
      };
      # Let NixOS write EFI variables so it can register the boot entry.
      efi.canTouchEfiVariables = true;

      # Boot immediately — the menu shows only when Space is held at startup.
      timeout = 0;
    };

    # -----------------------------------------------------------------------
    # Plymouth — graphical boot splash
    # A host can set its own theme.
    # -----------------------------------------------------------------------
    plymouth = {
      enable = true;
      # "spinner" shows a minimal loading animation. Other built-in themes:
      # "bgrt" (UEFI logo), "tribar", "fade-in"; boot.plymouth.themePackages
      # adds more. mkDefault lets a host override it without mkForce.
      # Also available, not set here: logo, font, extraConfig.
      theme = lib.mkDefault "spinner";
    };

    # Quiet boot — kernel and udev messages stay hidden behind Plymouth.
    consoleLogLevel = 0;
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"  # Drops to a shell on failure instead of rebooting — useful for debugging
      "loglevel=3"          # Only show errors, not info messages
      "rd.udev.log_level=3" # Same for udev (device detection)
      "udev.log_priority=3"
    ];

    # -----------------------------------------------------------------------
    # Kernel — Zen (default for all hosts)
    #
    # Zen applies scheduler tweaks, lower-latency preemption and throughput
    # patches on top of mainline, aimed at interactive and gaming workloads.
    # mkDefault lets a host pick another kernel (e.g. linuxPackages for
    # LTS, linuxPackages_latest for mainline).
    # -----------------------------------------------------------------------
    kernelPackages = lib.mkDefault pkgs.linuxPackages_zen;
  };

  # =========================================================================
  # NETWORKING
  #
  # NetworkManager handles wired, wireless and VPN connections on every
  # host. The firewall is on, with no ports opened globally.
  # =========================================================================
  networking = {
    # NetworkManager manages DHCP and WiFi instead of static
    # networking.interfaces config.
    networkmanager = {
      enable = true;

      # Dispatcher script: when an ethernet interface (en*, eth*, eno*) goes
      # up, WiFi is turned off to save power and avoid split routing; when it
      # goes down, WiFi is turned back on. On hosts without WiFi the nmcli
      # call changes nothing.
      dispatcherScripts = [
        {
          source = pkgs.writeShellScript "ethernet-wifi-exclusive" ''
            IFACE="$1"
            ACTION="$2"
            case "$IFACE" in
              en*|eth*|eno*)
                case "$ACTION" in
                  up)        ${config.networking.networkmanager.package}/bin/nmcli radio wifi off ;;
                  down)      ${config.networking.networkmanager.package}/bin/nmcli radio wifi on  ;;
                esac
                ;;
            esac
          '';
          type = "basic";
        }
      ];
    };

    # nftables/iptables firewall: blocks all incoming connections except
    # ports opened explicitly. services.openssh opens port 22 itself.
    firewall = {
      enable = true;
      # Ports for every host would go here; host-specific ports are opened
      # in that host's own file.
      # allowedTCPPorts = [ ];
      # allowedUDPPorts = [ ];
    };
  };

  # =========================================================================
  # SSH — Secure Shell daemon
  #
  # Runs on every host for remote access, which headless servers depend on.
  #   PermitRootLogin = "no"           no root login over SSH
  #   PasswordAuthentication = false   keys only
  # Also available, not set here: ports (default [ 22 ]), openFirewall
  # (default true), KbdInteractiveAuthentication, AllowUsers / AllowGroups,
  # X11Forwarding, startWhenNeeded (socket activation), hostKeys.
  # =========================================================================
  services.openssh = {
    enable = true;
    settings = {
      # No root login over SSH; log in as a user and use sudo.
      PermitRootLogin = "no";
      # SSH keys only, no passwords. A host without an authorised key
      # cannot be reached over SSH.
      PasswordAuthentication = false;
    };
  };

  # =========================================================================
  # LOCALE & TIME
  #
  # Same timezone and locale on every host. extraLocaleSettings sets each
  # LC_* category separately (all en_US.UTF-8 here).
  # =========================================================================
  time.timeZone = "America/New_York"; # IANA zone name

  i18n = {
    defaultLocale = "en_US.UTF-8";
    extraLocaleSettings = {
      LC_ADDRESS        = "en_US.UTF-8";
      LC_IDENTIFICATION = "en_US.UTF-8";
      LC_MEASUREMENT    = "en_US.UTF-8";
      LC_MONETARY       = "en_US.UTF-8";
      LC_NAME           = "en_US.UTF-8";
      LC_NUMERIC        = "en_US.UTF-8";
      LC_PAPER          = "en_US.UTF-8";
      LC_TELEPHONE      = "en_US.UTF-8";
      LC_TIME           = "en_US.UTF-8";
    };
  };

  # =========================================================================
  # SOUND — PipeWire
  #
  # PipeWire is the audio stack. It replaces PulseAudio and JACK while
  # staying compatible with both; WirePlumber is the session manager that
  # routes between apps and devices.
  #   alsa.enable / alsa.support32Bit   ALSA apps, including 32-bit ones
  #   pulse.enable                      PulseAudio server emulation
  #   wireplumber.enable                session manager
  #   extraConfig.pipewire.<file>       drop-in pipewire.conf fragments
  # Also available, not set here: jack.enable (JACK emulation),
  # extraConfig.pipewire-pulse / client, configPackages.
  #
  # Server hosts turn it off with services.pipewire.enable = lib.mkForce false.
  # =========================================================================
  services.pipewire = {
    enable = true;
    # Compatibility layers so PulseAudio and ALSA apps work unchanged
    alsa.enable = true;
    alsa.support32Bit = true; # Needed for some games and older software
    pulse.enable = true;      # PulseAudio compatibility
    wireplumber.enable = true;
    # x11-bell (plays the X11 beep) crashes the whole daemon with SIGSEGV
    # when the X server goes away (e.g. Umbriel's on-demand Xwayland
    # restarting), dropping every audio stream. Nothing needs the X11 bell,
    # so the module is turned off.
    extraConfig.pipewire."99-no-x11-bell"."context.properties"."module.x11.bell" = false;
  };

  # =========================================================================
  # NIX SETTINGS
  #
  # Configuration for the Nix package manager itself.
  #   settings.*               nix.conf (features, caches, trust, fallback)
  #   daemonCPUSchedPolicy / daemonIOSchedClass   build daemon priority
  #   gc.*                     automatic garbage collection
  #   optimise.automatic       periodic store hard-linking
  # =========================================================================
  # Allow unfree packages (Steam, Nvidia drivers, etc.) system-wide. This
  # NixOS option is what module evaluation reads; the flake.nix pkgs import
  # setting does not carry over into it.
  nixpkgs.config.allowUnfree = true;

  nix = {
    settings = {
      # The `nix` command and flakes.
      experimental-features = [ "nix-command" "flakes" ];

      # Binary caches with pre-built packages, each with its signing key in
      # trusted-public-keys.
      substituters = [
        "https://cache.nixos.org"           # Official NixOS cache
        "https://nix-community.cachix.org"  # Community packages
        "https://cosmic.cachix.org"         # Pre-built COSMIC packages
      ];
      trusted-public-keys = [
        "cache.nixos.org-1:6NCHdD59X431o0gWypbMrAURkbJ16ZPMQFGspcDShjY="
        "nix-community.cachix.org-1:L/J5ArMSr0xyNkTPoaFNiYmUoYMfdXZAo2MnGpvgDyU="
        "cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85d/E="
      ];

      # If a substituter is down or a narinfo lookup fails, build locally
      # instead of failing the whole rebuild; otherwise a cache outage
      # fails `nru` on every host.
      fallback = true;

      # Users allowed extra daemon rights (add caches, import unsigned
      # paths): root and the wheel group
      trusted-users = [ "root" "@wheel" ];

      # max-jobs and cores are set per host in ./build-capacity.nix from
      # that host's specs; one fleet-wide pair cannot suit both a 24c/31G
      # desktop and a 4c/7G mini PC.
    };

    # Keep the build daemon out of the way of everything else. idle
    # scheduling only yields when something else wants the CPU or disk, so a
    # rebuild on an otherwise idle machine still runs at full speed.
    daemonCPUSchedPolicy = "idle";
    daemonIOSchedClass   = "idle";

    # Weekly garbage collection of generations older than 30 days.
    # Also available: randomizedDelaySec, persistent (run a missed job at
    # next boot, default true).
    gc = {
      automatic = true;
      dates = "weekly";      # systemd OnCalendar expression
      options = "--delete-older-than 30d"; # passed to nix-collect-garbage
    };

    # Periodically hard-link identical files in the store to save space
    # (optimise.dates sets when; default daily 03:45).
    optimise.automatic = true;
  };

  # =========================================================================
  # MEMORY SAFETY NET FOR BUILDS
  #
  # zram is a compressed swap device in RAM. Build data compresses around
  # 3:1, so a device sized at 50% of RAM buys roughly 30% more effective
  # memory for the cost of some CPU. The point is not capacity, it is that a
  # memory spike during a rebuild degrades into slowness instead of the
  # kernel OOM-killer picking a victim. priority 100 puts it ahead of the
  # disk swapfile (-1), which is far too slow to absorb compiler pressure.
  #
  # zramSwap also offers algorithm (default zstd), memoryMax and
  # writebackDevice; not set here.
  #
  # MemoryHigh is a soft limit: crossing it throttles the daemon's cgroup
  # into reclaim. MemoryMax would be a hard kill, which only moves the OOM
  # from the kernel into systemd.
  # =========================================================================
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    priority = 100;
  };

  systemd.services.nix-daemon.serviceConfig.MemoryHigh = "70%";

  # =========================================================================
  # FONTS
  #
  # Full Nerd Fonts collection, every patched family. builtins.attrValues
  # turns the nerd-fonts attrset into a list (lib.isDerivation drops
  # non-package entries), so all families (JetBrainsMono, FiraCode,
  # CascadiaCode, Hack, etc.) are installed. nerd-fonts.symbols-only is the
  # icon-only font that acts as a system-wide fallback for Nerd Font glyphs.
  #
  # noto-fonts-color-emoji is left out on purpose: it would claim
  # the private-use-area codepoints that Nerd Fonts uses for icons,
  # causing fastfetch and terminal apps to render colored emoji boxes
  # instead of the actual icon glyphs.
  # =========================================================================
  fonts.packages = lib.filter lib.isDerivation (builtins.attrValues pkgs.nerd-fonts);

  # =========================================================================
  # BASE PACKAGES
  #
  # Packages installed on every host, desktops, laptops and servers alike.
  # Only tools useful everywhere belong here; desktop packages go in
  # modules/system/graphical.
  # =========================================================================
  environment.systemPackages = with pkgs; [
    # Core utilities
    git          # Version control — needed to manage this config
    curl         # HTTP requests from the command line
    wget         # File downloads
    htop         # Interactive process viewer
    btop         # Modern resource monitor (prettier than htop)
    unzip        # Archive extraction
    tree         # Directory tree viewer
    jq           # JSON processor — used by Claude Code hooks and shell scripts

    # Native host for the pywalfox Firefox/Thunderbird extension
    pywalfox-native


    # Network tools
    iproute2     # ip command for network management
    nmap         # Network scanner (finds hosts on the network)
    dig          # DNS lookup tool
    rsync        # Fast file sync — local copies, remote backups, deploy scripts

    # Text editors (minimal, for emergency server access)
    nano         # Simple editor, available on every host
    # Shell tools
    fastfetch    # System info display — useful on desktops AND servers via SSH

    # Node.js — needed for MCP servers (npx) and Claude Code hooks
    nodejs

    # Nix version diff — shows added/removed/updated packages between two
    # system closures. Used by _nixos_run to display what changed after rebuild.
    nvd
  ];

  # ===========================================================================
  # Environment variables for AI tools
  # ===========================================================================
  environment.sessionVariables = {
    # Enable Exa web search in OpenCode
    OPENCODE_ENABLE_EXA = "true";
  };

  # =========================================================================
  # POLKIT — allow wheel group to manage systemd units without interactive auth
  #
  # systemd requires polkit authorisation for `systemd-run` transient units
  # even when called as root, and nixos-rebuild passes --no-ask-password,
  # so polkit cannot prompt and the call fails. The first rule grants the
  # wheel group YES for systemd1 actions, so nixos-rebuild switch works
  # without a polkit agent. It also covers login1 inhibit actions, so
  # systemd-inhibit (used by nru/nrb to block sleep during rebuilds) does
  # not ask for a password. The second rule lets fwupd-refresh refresh LVFS
  # metadata.
  # =========================================================================
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if ((action.id.indexOf("org.freedesktop.systemd1.") === 0 ||
           action.id.indexOf("org.freedesktop.login1.inhibit-") === 0) &&
          subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
    // Allow the fwupd-refresh system user to refresh LVFS metadata without
    // an interactive polkit session. The NixOS fwupd module omits this rule,
    // causing fwupd-refresh.service to always fail with "Failed to obtain auth".
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.fwupd.refresh-remote" &&
          subject.user == "fwupd-refresh") {
        return polkit.Result.YES;
      }
    });
  '';

  # =========================================================================
  # KERNEL SYSCTL TWEAKS
  #
  # fs.inotify.max_user_watches — how many filesystem watches the kernel
  # allows per user. VSCode, the Claude Code extension and Obsidian watch
  # every file in open folders; with large repos and the vault open at once,
  # 524288 (the NixOS default) runs out. 1048576 (1M) leaves headroom.
  # Applies to every host, servers included (Syncthing, Immich and the
  # torrent client watch large trees too).
  # =========================================================================
  boot.kernel.sysctl."fs.inotify.max_user_watches" = lib.mkForce 1048576;

  # =========================================================================
  # BLUETOOTH
  #
  # Enabled on every host that has an adapter.
  #   powerOnBoot = false (mkDefault)   adapter stays off until turned on;
  #                                     graphical.nix sets it true
  #   btusb in boot.kernelModules       /sys/class/bluetooth exists before
  #                                     bluetoothd checks
  #                                     ConditionPathIsDirectory
  #
  # blueman: provides the Bluetooth management GUI and D-Bus activation.
  # The blueman package ships /etc/xdg/autostart/blueman.desktop which would
  # auto-start the tray applet in every graphical session. We suppress it
  # system-wide via environment.etc: /etc/xdg comes first in
  # XDG_CONFIG_DIRS, so this Hidden=true file shadows the package's copy in
  # /run/current-system/sw/etc/xdg/autostart/. Each DE has its own
  # Bluetooth UI (COSMIC panel, KDE tray, Noctalia bar), so no second tray
  # icon is needed; blueman-manager can still be started by hand for
  # pairing.
  # =========================================================================
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = lib.mkDefault false;
  services.blueman.enable = true;
  environment.etc."xdg/autostart/blueman.desktop".text = ''
    [Desktop Entry]
    Hidden=true
  '';
  boot.kernelModules = lib.mkAfter [ "btusb" ];

  # =========================================================================
  # FWUPD — firmware update daemon
  #
  # Updates firmware (BIOS, SSD, peripherals) from LVFS, from the command
  # line or a GUI (GNOME Software, KDE Discover).
  # Run: fwupdmgr refresh && fwupdmgr update
  # =========================================================================
  services.fwupd.enable = true;

  # =========================================================================
  # TAILSCALE — mesh VPN
  #
  # Runs on every host so all of them are reachable from anywhere without
  # port forwarding. After first boot on each host: sudo tailscale up
  # Also available, not set here: openFirewall, useRoutingFeatures
  # ("client" / "server" / "both" for exit nodes and subnet routes),
  # authKeyFile (log in unattended), extraUpFlags, port.
  # =========================================================================
  services.tailscale.enable = true;

  # =========================================================================
  # SYSTEM STATE VERSION
  #
  # The NixOS release whose defaults apply to stateful data (databases,
  # state directories). It stays at the release first installed with;
  # changing it does not upgrade anything and can break existing state.
  # =========================================================================
  system.stateVersion = "24.11";
}
