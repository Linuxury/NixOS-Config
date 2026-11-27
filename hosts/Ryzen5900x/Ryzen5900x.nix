# ===========================================================================
# hosts/Ryzen5900x/Ryzen5900x.nix — AMD Ryzen 9 5900x desktop
#
# Host definition for the personal daily-driver desktop. Hardware: AMD Ryzen 9 5900x,
# AMD Radeon RX 7900 XTX. Type: desktop with no disk encryption (BTRFS directly on the
# partition; see disk.nix).
#
# Enabled here: AMD drivers, the Umbriel compositor with the Noctalia shell and
# noctalia-greeter, gaming, and development tools (AI tools, editors, languages).
# The desktop, compositor and shell options that are not enabled stay in the imports
# block as commented-out lines (Hyprland, Niri, COSMIC, GNOME, KDE, wayle, sddm).
#
# To turn a module on or off, uncomment or comment out its line in the imports block.
# ===========================================================================

{
  config,
  pkgs,
  inputs,
  ...
}:

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
    #   zen-browser  — primary browser (privacy-focused Firefox fork)
    #   thunderbird  — email client
    #   fluxer       — Fluxer chat client (canary, nixpkgs)
    #   kdeconnect   — phone integration
    #   zennotes     — keyboard-first Markdown notes (connects to Media-Server:7879)
    #   nowted       — private offline notes (AppImage, pkgs/nowted)
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
    ../../modules/system/graphical/luciole.nix

    # ==============================================================
    # Desktop Environment — enable ONE (includes shell + greeter)
    # ==============================================================
    #../../modules/desktops/cosmic/cosmic.nix
    #../../modules/desktops/gnome/gnome.nix
    #../../modules/desktops/kde.nix

    # ==============================================================
    # Compositor — enable ONE, pair with Shell + Greeter below
    # ==============================================================
    #../../modules/compositors/hyprland/hyprland.nix
    #../../modules/compositors/niri.nix
    ../../modules/compositors/umbriel/umbriel.nix

    # ==============================================================
    # Shell — enable ONE for the active compositor
    #   wayle    — needs greeters/sddm (imported below)
    #   noctalia — bundles its own greeter (noctalia-greeter/greetd)
    # ==============================================================
    #../../modules/shells/wayle.nix
    ../../modules/shells/noctalia/shell-noctalia.nix

    # ==============================================================
    # Greeter — only needed for wayle; noctalia brings its own
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
    #   goose     — Goose agent, Claude via Claude Code ACP (Pro plan)
    #   local-llm — Ollama + AMD ROCm (7900 XTX — 24 GB VRAM)
    #   lm-studio — GUI LLM runner (requires ai-tools)
    # ==============================================================
    ../../modules/development/ai-tools/ai-tools.nix
    ../../modules/development/ai-tools/claude.nix
    ../../modules/development/ai-tools/opencode.nix
    ../../modules/development/ai-tools/goose.nix
    #../../modules/development/ai-tools/local-llm.nix
    #../../modules/development/ai-tools/lm-studio.nix

    # ==============================================================
    # Development — Editors
    #   neovim   — full IDE: custom config, LSPs, opencode-nvim, claude wrapper
    #   vscodium — GUI editor: Catppuccin theme, Claude Code + OpenCode extensions
    #   zed      — fast Wayland-native editor (Rust), vim mode
    #   helix    — modal terminal editor (hx), default config
    # ==============================================================
    ../../modules/development/editors/neovim/neovim.nix
    ../../modules/development/editors/vscodium/vscodium.nix
    ../../modules/development/editors/vscode/vscode.nix
    ../../modules/development/editors/zed.nix
    ../../modules/development/editors/helix.nix

    # ==============================================================
    # Development — Languages
    #   python — python3, poetry, ruff, httpie
    #   rust   — rustup toolchain, cargo tools, just
    # ==============================================================
    ../../modules/development/languages/python.nix
    ../../modules/development/languages/rust.nix

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
  networking.hostName = "Ryzen5900x";

  # Luciole (modules/system/graphical/luciole.nix) is the default file manager: it opens folders and
  # handles Open/Save dialogs. The Umbriel portal has no FileChooser, so dialogs go to Luciole's
  # portal backend ("luciole"), with GTK as fallback if it is missing.
  xdg.portal.extraPortals = [ inputs.luciole.packages.${pkgs.stdenv.hostPlatform.system}.default ];
  xdg.portal.config.umbriel."org.freedesktop.impl.portal.FileChooser" = [ "luciole" "gtk" ];
  # Home Manager (every user on this host): folders open in Luciole. mkForce overrides the
  # mkDefault Nautilus entry set in graphical.nix.
  home-manager.sharedModules = [{
    xdg.mimeApps.defaultApplications."inode/directory" = pkgs.lib.mkForce "dev.noctalia.luciole.desktop";
  }];

  # Dux Files: the previous default, kept installed as a fallback. To switch back, set
  # portal.enable = true, the FileChooser above to [ "dfiles" ] and the mime entry to
  # "dev.duxlabs.files.desktop".
  #   programs.dux-files.enable          install Dux Files and its D-Bus service (set here)
  #   programs.dux-files.portal.enable   register Dux Files as the file-chooser portal backend (off)
  #   programs.dux-files.package         the package; set below to add a patch
  programs.dux-files.enable = true;
  # Patch for Dux Files: Papirus folder and sidebar icons stay stale after Noctalia recolors them
  # (upstream #46). The patch reloads theme icons 1.5 s after the shell rewrites
  # ~/.cache/dms/dms-colors.json, since Noctalia retargets the folder links within about 1 s and
  # watching the icon files themselves misses the replaced files. Remove the patch once #46 is fixed upstream.
  programs.dux-files.package = pkgs.dux-files.overrideAttrs (old: {
    patches = (old.patches or [ ]) ++ [ ../../pkgs/dux-files/icon-refresh.patch ];
  });

  # ==============================================================
  # Auto-update — primary host (services.nixos-auto-update)
  #   isPrimary  true (set here): this host advances the nixpkgs pin, builds from the local
  #              repo, then commits and pushes flake.lock. Other hosts rebuild from GitHub
  #              and get the new packages. Set it on exactly one host.
  #   enable     unattended updates on non-primary hosts (default true)
  #   primaryUser  user that owns vault writes and notifications (default "linuxury")
  # ==============================================================
  services.nixos-auto-update.isPrimary = true;

  # ==============================================================
  # Local LLM — Ollama with AMD ROCm for the RX 7900 XTX (services.localLlm)
  #   enable      run the local LLM service on demand (commented out)
  #   user        user granted GPU access, added to the render group
  #   model       model to pull and serve (default "qwen2.5:14b")
  #   gfxVersion  GPU target for ROCm: RDNA3 (gfx1100) reports as 11.0.0 (default "11.0.0")
  # Find the value for your GPU with: rocminfo | grep gfx
  # Not active: the local-llm import in the imports block is commented out.
  # ==============================================================
  # services.localLlm = {
  #   enable     = true;
  #   user       = "linuxury";
  #   model      = "qwen2.5:14b";
  #   gfxVersion = "11.0.0";
  # };

  # ==============================================================
  # Default session — session pre-selected by the display manager at login
  #   services.displayManager.defaultSession  session name (set here: "umbriel")
  #   Only GDM, LightDM and SDDM use this option.
  # ==============================================================
  services.displayManager.defaultSession = "umbriel";

  # ==============================================================
  # GPU driver
  #   hardware.gpu  "amd", "intel" or "nvidia-hybrid" (required on every host; set here)
  # ==============================================================
  hardware.gpu = "amd";

  # ==============================================================
  # Hardware toggles — option-gated modules (imported in flake.nix)
  #   hardware.openrgb.enable           OpenRGB: package, udev rules and the server daemon (set here)
  #   hardware.openrgb.motherboard      SMBus platform, "amd" or "intel" (default "amd")
  #   hardware.openrgb.profile          profile loaded at boot; null loads none (default null)
  #   hardware.lemokey-keychron.enable  udev rules for Lemokey and Keychron keyboard web configurators (set here)
  # ==============================================================
  hardware.openrgb.enable = true;
  hardware.lemokey-keychron.enable = true;

  # ==============================================================
  # Network shares — CIFS mounts from the home servers
  #
  # Local disks are declared in disk.nix. Each share below is mounted on first access
  # and unmounted after 60 s idle. The credentials file is written by agenix
  # (age.secrets.smb-credentials, below). Options used on every share:
  #   device                          //server/share to mount
  #   fsType = "cifs"                 SMB/CIFS filesystem (cifs-utils)
  #   credentials=<file>              file holding the username and password
  #   uid=<n>, gid=<n>                owner of files when the server reports none (gid 100 = users)
  #   nofail                          a failed mount does not stop boot
  #   _netdev                         network mount: ordered after the network is up
  #   noauto                          not mounted at boot or by nixos-rebuild switch
  #   x-systemd.automount             mount on first access instead of at boot
  #   x-systemd.idle-timeout=60       unmount after 60 s without access
  #   x-systemd.mount-timeout=2s      give up if the mount command takes longer than 2 s
  #   x-gvfs-hide                     hide the mount from GVfs-based file managers
  # ==============================================================
  fileSystems = {

    # -----------------------------------------------------------------------
    # Media-Server share (10.0.0.3), mounted at /mnt/Media-Server.
    # The share exposes the server's /data directory, which holds media/, shared/ and
    # downloads/. Folder access is enforced by file permissions on the server.
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
        "x-gvfs-hide"
      ];
    };

    # -----------------------------------------------------------------------
    # MinisForum share (//10.0.0.7/GameServers), mounted at /mnt/MinisForum.
    # Used to manage game server files. Automounts on first access and unmounts
    # after 60 s idle. Mount by hand with: sudo mount /mnt/MinisForum
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
        "x-gvfs-hide"
      ];
    };

    # Torrents share (//10.0.0.3/Downloads), same options as above, mounted at /mnt/Torrents.
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
        "x-gvfs-hide"
      ];
    };

  };

  # ==============================================================
  # Drive ownership — the main user owns the root of each XFS drive
  #
  # systemd.tmpfiles.rules creates the mount-point directories: "d" = directory, mode 0755,
  # owner linuxury, group users. A tmpfiles rule can run before a drive is mounted and then
  # set the owner on the bare mount-point directory, not on the XFS root. The oneshot service
  # below waits for the mounts and then changes ownership of the drive roots.
  # ==============================================================
  systemd.tmpfiles.rules = [
    "d /mnt/Warehouse    0755 linuxury users -"
    "d /mnt/Games        0755 linuxury users -"
    "d /mnt/Media-Server 0755 linuxury users -"
    "d /mnt/MinisForum   0755 linuxury users -"
    "d /mnt/Torrents     0755 linuxury users -"
  ];

  # Oneshot service that sets the owner and mode of the Warehouse and Games drive roots.
  #   after / requires   start after the two mount units and fail if either mount fails
  #   wantedBy           start at boot as part of local-fs.target
  #   Type = oneshot     run the script once; RemainAfterExit = true keeps the unit active afterwards
  #   ExecStart          the script (writeShellScript) that runs chown and chmod
  systemd.services."xfs-drive-ownership" = {
    description = "Set linuxury ownership on XFS drive roots";
    after = [
      "mnt-Warehouse.mount"
      "mnt-Games.mount"
    ];
    requires = [
      "mnt-Warehouse.mount"
      "mnt-Games.mount"
    ];
    wantedBy = [ "local-fs.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "xfs-drive-ownership" ''
        chown linuxury:users /mnt/Warehouse
        chown linuxury:users /mnt/Games
        chmod 755 /mnt/Warehouse
        chmod 755 /mnt/Games
      '';
    };
  };

  # ==============================================================
  # Agenix secrets — encrypted files in secrets/, decrypted at boot into /run/agenix/<name>
  #   file   the encrypted .age file (required)
  #   mode   permissions of the decrypted file, chmod style (default "0400")
  #   owner  user that owns the decrypted file (default "0", root)
  #   group  group that owns it (default: the owner's primary group)
  #   path, symlink, enable   other options; defaults used here
  # ==============================================================

  # Samba login used by the CIFS mounts above. Readable by root only.
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
  #   pkgs.linuxPackages                  default kernel (not set here)
  #   pkgs.linuxPackages_latest           mainline latest (commented out)
  #   pkgs.linuxPackages_xanmod_latest    XanMod latest (set here)
  #   pkgs.linuxPackages_zen              Zen kernel (commented out)
  # To switch, comment out the active line and uncomment another one.
  # ==============================================================
  # boot.kernelPackages = pkgs.linuxPackages_latest;          # Vanilla
   boot.kernelPackages = pkgs.linuxPackages_xanmod_latest;   # XanMod
  # boot.kernelPackages = pkgs.linuxPackages_zen;             # Zen

  # ==============================================================
  # AMD Radeon RX 7900 XTX (RDNA3) — driver and boot settings
  #   boot.initrd.kernelModules  load amdgpu in the initrd (set here)
  #   boot.kernelParams          kernel command-line options (set here, listed below)
  # ==============================================================

  # Load amdgpu in the initrd so Plymouth can set up the GPU early enough for its splash
  # screen. Without it, Plymouth falls back to a basic framebuffer that does not work on RDNA3,
  # and kernel messages show through despite quiet and splash.
  boot.initrd.kernelModules = [ "amdgpu" ];

  boot.kernelParams = [
    # Console logging: hide most kernel, udev and systemd messages on the TTY.
    "quiet"                              # reduce kernel messages on the console
    "loglevel=3"                         # kernel: print errors and worse only
    "rd.udev.log_level=3"                # udev in the initrd: errors only
    "udev.log_priority=3"                # udev after boot: errors only
    "rd.systemd.show_status=false"       # hide systemd unit status lines in the initrd
  ];

  # ==============================================================
  # CoreCtrl — GUI for AMD GPU and CPU control (overclocking, fan curves)
  #   programs.corectrl.enable              install CoreCtrl, its D-Bus service and the corectrl group (set here)
  #   programs.corectrl.package             the CoreCtrl package (default pkgs.corectrl)
  #   hardware.amdgpu.overdrive.enable      turn on amdgpu overdrive for overclocking (set here)
  #   hardware.amdgpu.overdrive.ppfeaturemask  kernel value for amdgpu.ppfeaturemask (default 0xfffd7fff:
  #                                            overdrive on, GFXOFF off; 0xffffffff turns everything on)
  #
  # The CoreCtrl polkit rule lets members of the corectrl group run it without a password
  # prompt; linuxury is in that group (users.users.linuxury below).
  # ==============================================================
  programs.corectrl.enable = true;
  # Affinity design suite, off (design apps come from craft-apps).
  # programs.affinity.enable = true;
  hardware.amdgpu.overdrive.enable = true;

  # ==============================================================
  # Multi-monitor support
  #
  # autorandr remembers and restores monitor layouts automatically.
  # ==============================================================
  environment.systemPackages = with pkgs; [
    (writeShellScriptBin "add-host" (builtins.readFile ../../scripts/add-host))  # register a host key + re-key secrets (NixOS-Installer's Secrets step)
    (writeShellScriptBin "install-host" (builtins.readFile ../../scripts/install-host))  # run NixOS-Installer on a live-ISO machine over SSH
    autorandr  # Automatic monitor layout switching
    cifs-utils # Required for CIFS/Samba mounts
    xfsprogs   # XFS filesystem tools (mkfs.xfs, xfs_repair, etc.)
    # corectrl is installed by programs.corectrl.enable above

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
    # Add host-only apps here (none at present).
  ];

  # ==============================================================
  # Main user account (linuxury)
  #   isNormalUser  create a home directory and a login account (set here)
  #   extraGroups   supplementary groups:
  #                   wheel          sudo / administrator rights
  #                   networkmanager change network connections
  #                   video, audio   GPU and sound device access
  #                   input          input device access
  #                   gamemode       group created by the GameMode module (programs.gamemode)
  #                   corectrl       run CoreCtrl without a password (programs.corectrl)
  #                   seat           seatd: DRM and input handoff for Wayland compositors
  #   shell         login shell (zsh)
  # ==============================================================
  users.users.linuxury = {
    isNormalUser = true;
    extraGroups = [
      "wheel"
      "networkmanager"
      "video"
      "audio"
      "input"
      "gamemode"
      "corectrl"
      "seat"
    ];
    shell = pkgs.zsh;

  };

  # Tailscale is enabled in core.nix (services.tailscale.enable). On a new machine, sign in once
  # with: sudo tailscale up

  # zsh: enables the zsh configuration and completions for the system (programs.zsh.enable).
  programs.zsh.enable = true;
}
