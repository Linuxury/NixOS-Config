# ===========================================================================
# modules/system/graphical/graphical.nix — Shared base for all graphical machines
#
# Shared base for every host with a desktop: network-share browsing,
# Flatpak, Qt/GTK glue, NumLock, Bluetooth tuning, backlight, shared apps,
# default applications and fonts. Turn it on by importing it from a desktop
# or laptop host; headless servers never import it, so they get none of
# these graphical tools.
#
# It does not depend on the DE: it works the same under COSMIC, KDE,
# Hyprland, Niri or any other, and stays in a host's imports when the DE
# module changes.
#
# The following are intentionally NOT imported here — they are per-host:
#   firefox, helium, fluxer, openrgb, kdeconnect,
#   lemokey-keychron, zen-browser, zed, lm-studio.
#
# Import placement: hosts/<name>/<name>.nix
#   imports = [
#     system/core.nix
#     system/graphical/graphical.nix   ← here, before the DE module
#     compositors/hyprland/hyprland.nix  ← or desktops/{cosmic,kde,...}
#     ...
#   ]
# ===========================================================================

{ config, lib, pkgs, ... }:

let
  # Shared Flatpak updater — used by nru (_nru_flatpak_bar in the zsh repo)
  # and by the weekly timers below, so the update and failure logic lives in
  # one place. Usage: nixos-flatpak-update --user | --system
  # Prints one machine-readable line per result, prefixed with the scope:
  #   <scope> skipped <reason> | <scope> uptodate
  #   <scope> updated <app-id> <name> | <scope> failed <app-id> <error message>
  # Exits 1 if any app failed to update.
  flatpakUpdate = pkgs.writeShellApplication {
    name = "nixos-flatpak-update";
    runtimeInputs = with pkgs; [ flatpak gnugrep gnused coreutils ];
    text = ''
      case "''${1:-}" in
        --user|--system) flag="$1"; scope="''${1#--}" ;;
        *) echo "usage: nixos-flatpak-update --user|--system" >&2; exit 2 ;;
      esac

      if ! flatpak remote-list --system 2>/dev/null | grep -q flathub; then
        echo "$scope skipped no-flathub"; exit 0
      fi

      # com.hypixel.HytaleLauncher is a permanent exception: the hytale module
      # deletes its origin remote right after install, so it can never resolve
      # updates until Hytale ships on Flathub.
      if ! list=$(flatpak remote-ls --updates "$flag" --columns=application,name 2>&1); then
        # Errors can span lines (GPG's "Signature made …" comes before the
        # actual reason), so keep the whole message from "error:" on.
        msg=$(sed -n '/^error:/,$p' <<<"$list" | paste -sd' ')
        echo "$scope failed - ''${msg:-$(head -1 <<<"$list")}"; exit 1
      fi
      list=$(grep -v '^com\.hypixel\.HytaleLauncher' <<<"$list" || true)
      if [[ -z "$list" ]]; then echo "$scope uptodate"; exit 0; fi

      out=$(flatpak update "$flag" --noninteractive -y 2>&1) || true
      rc=0
      while IFS=$'	' read -r app name; do
        err=$(grep -iE "(unable to update|failed|error).*$app" <<<"$out" | head -1 || true)
        if [[ -n "$err" ]]; then
          echo "$scope failed $app $err"; rc=1
        else
          echo "$scope updated $app $name"
        fi
      done <<<"$list"
      exit "$rc"
    '';
  };
in
{
  imports = [
    # Fast-fail pre-check for the Torrents CIFS automount. Applies only to
    # hosts with /mnt/Torrents in fileSystems; a no-op elsewhere.
    ./torrents-precheck.nix

    # Login avatars — copies each user's icon from the Assets flake input
    # into the SDDM and AccountsService locations so greeters show it.
    ./user-avatars.nix

    # Affinity v3 (Wine) — inactive until a host sets
    # programs.affinity.enable = true.
    ./affinity.nix
  ];

  # =========================================================================
  # GVfs — GNOME Virtual Filesystem
  #
  # Provides virtual filesystem support so graphical file managers can
  # browse network shares (SMB/Samba), remote filesystems, and more.
  #
  # Works with any file manager that uses GIO/GVfs as a backend:
  #   COSMIC Files, Dolphin (KDE), Nautilus (GNOME), Thunar (XFCE), etc.
  #
  # The gvfs package in nixpkgs is built with Samba support; the samba
  # package below provides the libsmbclient it needs at runtime.
  # (services.gvfs.package could swap in another gvfs build.)
  # =========================================================================
  services.gvfs.enable = true;

  # =========================================================================
  # Avahi — mDNS client, required for "Browse Network" in the above
  #
  # gvfs's network:// backend (gvfsd-dnssd) discovers SMB/FTP/etc. hosts
  # over mDNS by querying a local avahi-daemon via D-Bus — without one
  # running on this machine, the Network pane stays empty no matter how
  # correctly gvfs/Samba are configured otherwise. Set here so every DE/WM
  # gets network browsing the same way.
  #   nssmdns4      resolve .local names through NSS (IPv4)
  #   openFirewall  open UDP 5353 for mDNS
  # Also available, not set here: nssmdns6, publish settings (advertise this
  # host), wideArea, extraServiceFiles.
  # =========================================================================
  services.avahi = {
    enable       = true;
    nssmdns4     = true; # resolve .local hostnames once a share is found
    openFirewall = true; # let mDNS multicast (UDP 5353) through
  };

  # =========================================================================
  # Flatpak — App distribution for packages not in nixpkgs
  #
  # Needed by user services such as hytale-flatpak-install and
  # fluxer-flatpak-install. The activation script adds the Flathub remote at
  # system scope (keeps an existing one) and imports the pinned Flathub
  # signing key into an existing remote that has none.
  # =========================================================================
  services.flatpak.enable = true;
  system.activationScripts.flatpak-flathub = let
    # ponytail: pinned key expires 2027-06-14; refresh the hash when Flathub re-publishes it.
    flathubKey = pkgs.fetchurl {
      url = "https://dl.flathub.org/repo/flathub.gpg";
      hash = "sha256-i9wgq8ThnAeWRgvrW/4OeqQThxaZnhnG8tvdeMxBrqo=";
    };
  in {
    text = ''
      ${pkgs.flatpak}/bin/flatpak remote-add --system --if-not-exists flathub \
        https://dl.flathub.org/repo/flathub.flatpakrepo || true
      # --if-not-exists keeps a pre-existing flathub remote that lacks the
      # signing key ("public key not found", Ryzen5800x 2026-10). Repair it.
      if ${pkgs.flatpak}/bin/flatpak remote-list --system --columns=name | ${pkgs.gnugrep}/bin/grep -qx flathub \
         && [ ! -s /var/lib/flatpak/repo/flathub.trustedkeys.gpg ]; then
        ${pkgs.flatpak}/bin/flatpak remote-modify --system --gpg-import=${flathubKey} flathub || true
      fi
    '';
    deps = [ "specialfs" ];
  };

  # zsh-abbr's scratch dir and its job queue default to shared /tmp/zsh-abbr
  # and /tmp/zsh-job-queue, owned by whichever user started zsh first, so
  # every other user gets "permission denied" on each prompt. These point
  # them at per-user dirs. /etc/zshenv runs before Home Manager's .zshrc
  # loads the plugin.
  programs.zsh.shellInit = ''
    export ABBR_TMPDIR="''${XDG_RUNTIME_DIR:-/tmp/$USER}/zsh-abbr"
    export JOB_QUEUE_TMPDIR="''${XDG_RUNTIME_DIR:-/tmp/$USER}/zsh-job-queue"
  '';
  # Home Manager's ~/.zshrc already runs compinit. The system /etc/zshrc
  # would run it again and rewrite the completion dump: ~0.9 s per shell.
  programs.zsh.enableGlobalCompInit = false;

  # NetworkManager-wait-online delays graphical.target by a few seconds
  # (through tailscaled's network-online ordering), so it is off on desktops
  # and laptops. That is safe there: CIFS mounts are automounts, and
  # nixos-upgrade skips the first 20 min after boot (auto-update.nix).
  # Servers keep it, since Radxa-X4's VPN killswitch needs a real
  # network-online.
  systemd.services.NetworkManager-wait-online.enable = false;

  # Weekly unattended Flatpak updates — the "nobody ran nru in a while"
  # backstop. Same script nru uses; skips cleanly where Flathub is absent
  # (child-account hosts). Both timers run Sundays 04:00, Persistent = true
  # (a missed run happens at next boot).

  # nru runs the system-scope update unattended — passwordless for exactly
  # this command (both paths: sudo may see either the store or the profile one).
  security.sudo.extraRules = [{
    users    = [ "linuxury" "babylinux" "alex" ];
    commands = [
      { command = "${flatpakUpdate}/bin/nixos-flatpak-update --system";            options = [ "NOPASSWD" ]; }
      { command = "/run/current-system/sw/bin/nixos-flatpak-update --system";      options = [ "NOPASSWD" ]; }
    ];
  }];

  systemd.user.services.flatpak-auto-update = {
    description = "Update installed Flatpak apps (user scope)";
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = "${flatpakUpdate}/bin/nixos-flatpak-update --user";
    };
  };

  systemd.user.timers.flatpak-auto-update = {
    description = "Weekly Flatpak app update (user scope)";
    wantedBy    = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun 04:00";
      Persistent = true;
    };
  };

  systemd.services.flatpak-auto-update-system = {
    description = "Update installed Flatpak apps and runtimes (system scope)";
    after       = [ "network-online.target" ];
    wants       = [ "network-online.target" ];
    serviceConfig = {
      Type      = "oneshot";
      ExecStart = "${flatpakUpdate}/bin/nixos-flatpak-update --system";
    };
  };

  systemd.timers.flatpak-auto-update-system = {
    description = "Weekly Flatpak update (system scope)";
    wantedBy    = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "Sun 04:00";
      Persistent = true;
    };
  };


  # Qt theming — makes Qt apps follow the active GTK theme.
  # qtbase ships the gtk3 platform theme plugin itself, so no extra package
  # or Qt configurator tool is needed.
  # mkDefault: DE modules win (upstream COSMIC sets qt5ct, KDE sets "kde").
  # Set on environment.variables, not sessionVariables — sessionVariables is
  # copied into variables at normal priority, which drops the mkDefault.
  environment.variables.QT_QPA_PLATFORMTHEME = lib.mkDefault "gtk3";

  # =========================================================================
  # NumLock — enable before the greeter on every graphical host
  #
  # Writes the LED state directly to the kernel before display-manager starts.
  # This is the universal approach: SDDM, cosmic-greeter, and all Wayland
  # compositors read the initial numlock state from the kernel at startup.
  # SDDM hosts also set Numlock = "on" in greeters/sddm.
  # =========================================================================
  systemd.services.numlock-on = {
    description = "Enable NumLock";
    wantedBy = [ "display-manager.service" ];
    before   = [ "display-manager.service" ];
    serviceConfig = {
      Type            = "oneshot";
      RemainAfterExit = true;
      ExecStart       = pkgs.writeShellScript "numlock-on" ''
        for kbd in /sys/class/leds/*::numlock; do
          echo 1 > "$kbd/brightness" 2>/dev/null || true
        done
      '';
    };
  };

  # =========================================================================
  # Bluetooth — graphical host tuning (base service enabled in core)
  #
  # core enables bluetoothd + blueman and suppresses the blueman-applet
  # autostart system-wide. Here we apply settings appropriate for any
  # machine with a display:
  #
  #   powerOnBoot     — adapter comes up immediately; every graphical host
  #                     has at least one paired device (headset, mouse, kb).
  #   FastConnectable — allows more radio bandwidth during connection setup,
  #                     speeding up reconnection at the cost of slightly higher
  #                     power during that window. Fine for desktops/laptops.
  #   AutoEnable      — re-enables the adapter if bluetoothd restarts (e.g.
  #                     after a suspend/resume cycle that resets the adapter).
  #
  # Also available, not set here: package, disabledPlugins, input / network
  # (settings for the input.conf / network.conf files).
  #
  # The Bluetooth UI (COSMIC panel, KDE tray, Noctalia bar) comes from each
  # DE; no compositor module needs to set these.
  # =========================================================================
  hardware.bluetooth = {
    powerOnBoot = true;
    settings = {
      General.FastConnectable = true;
      Policy.AutoEnable      = true;
    };
  };

  # =========================================================================
  # Backlight — brightness control
  #
  # Adds a udev rule that makes /sys/class/backlight/*/brightness writable
  # by the "video" group. No-op on desktops (rule fires only when a backlight
  # device appears). DE-agnostic: works with COSMIC, Hyprland, KDE, etc.
  # =========================================================================
  hardware.acpilight.enable = true;

  # Required for dconf/GSettings to work on non-GNOME desktops.
  # Installs the D-Bus service activation entry so that `dconf load`
  # (used by Home Manager) and GTK apps using GSettings can start
  # dconf-service on demand.
  programs.dconf.enable = true;

  # =========================================================================
  # Shared graphical packages
  #
  # Installed on every host that imports this module (not on servers).
  # =========================================================================
  environment.systemPackages = with pkgs; [
    flatpakUpdate  # nixos-flatpak-update — see the let block above

    # -----------------------------------------------------------------------
    # Terminals
    # -----------------------------------------------------------------------
    kitty       # Primary GPU-accelerated terminal

    # -----------------------------------------------------------------------
    # Media
    # -----------------------------------------------------------------------
    showtime    # GNOME video player — clean GTK4 GUI for casual viewing
    gapless     # Music player — GTK4, gapless playback, fast and lightweight
    loupe       # GNOME image viewer — thumbnails, zoom, EXIF

    # -----------------------------------------------------------------------
    # Documents & office
    # -----------------------------------------------------------------------
    papers                   # GNOME document viewer — PDFs and more (GTK4, modern)
    neovim                   # Fallback text editor — always available on every graphical host

    # -----------------------------------------------------------------------
    # System monitoring
    # -----------------------------------------------------------------------
    mission-center  # Modern system monitor — CPU, RAM, GPU, network at a glance

    # -----------------------------------------------------------------------
    # Wayland / desktop integration
    # -----------------------------------------------------------------------
    wl-clipboard           # wl-copy / wl-paste — Wayland clipboard access from scripts
    xdg-utils              # xdg-open — opens files with the correct default app

    # GSettings schemas for GNOME/GTK desktop preferences.
    # COSMIC does not ship these, but GTK apps like Firefox read
    # org.gnome.desktop.wm.preferences:button-layout from this package
    # to know which window buttons (minimize, maximize, close) to draw.
    # Without it, Firefox CSD defaults to close-only on COSMIC.
    gsettings-desktop-schemas

    # -----------------------------------------------------------------------
    # Shell tools
    # -----------------------------------------------------------------------
    eza   # Modern ls replacement — colors, icons, git status, dir grouping
    tuios # TUI window manager / multiplexer (trial — remove if unused)

    # -----------------------------------------------------------------------
    # Network share client
    #
    # Provides libsmbclient — the library gvfs (above) links against at
    # runtime to browse SMB/Samba shares. Without it, the "Network" view in
    # any file manager cannot connect to the servers.
    # -----------------------------------------------------------------------
    samba

  ];

  # =========================================================================
  # Default applications — shared across all graphical users on this host
  #
  # Set through home-manager.sharedModules so the defaults travel with the
  # packages that provide them. Optional apps set their own MIME defaults in
  # their own modules, so a module that is not imported leaves no entries.
  # Per-user choices (browser) stay in each user's home.nix.
  #
  # Also added here: keybinds.nix (shared keybinds) and an nvim desktop
  # entry.
  # =========================================================================
  home-manager.sharedModules = [
    ./keybinds.nix
    {
    xdg.mimeApps = {
      enable = true;
      defaultApplications = {
        # -----------------------------------------------------------------------
        # File Manager — Nautilus
        # -----------------------------------------------------------------------
        "inode/directory" = "org.gnome.Nautilus.desktop";

        # -----------------------------------------------------------------------
        # Image Viewer — Loupe
        # -----------------------------------------------------------------------
        "image/jpeg"              = "org.gnome.Loupe.desktop";
        "image/png"               = "org.gnome.Loupe.desktop";
        "image/gif"               = "org.gnome.Loupe.desktop";
        "image/webp"              = "org.gnome.Loupe.desktop";
        "image/avif"              = "org.gnome.Loupe.desktop";
        "image/heic"              = "org.gnome.Loupe.desktop";
        "image/jxl"               = "org.gnome.Loupe.desktop";
        "image/bmp"               = "org.gnome.Loupe.desktop";
        "image/tiff"              = "org.gnome.Loupe.desktop";
        "image/svg+xml"           = "org.gnome.Loupe.desktop";
        "image/x-portable-pixmap" = "org.gnome.Loupe.desktop";

        # -----------------------------------------------------------------------
        # Video Player — Showtime
        # -----------------------------------------------------------------------
        "video/mp4"        = "org.gnome.Showtime.desktop";
        "video/x-matroska" = "org.gnome.Showtime.desktop";
        "video/x-msvideo"  = "org.gnome.Showtime.desktop";
        "video/webm"       = "org.gnome.Showtime.desktop";
        "video/quicktime"  = "org.gnome.Showtime.desktop";
        "video/mpeg"       = "org.gnome.Showtime.desktop";
        "video/x-flv"      = "org.gnome.Showtime.desktop";
        "video/ogg"        = "org.gnome.Showtime.desktop";
        "video/x-ms-wmv"   = "org.gnome.Showtime.desktop";

        # -----------------------------------------------------------------------
        # Music Player — Gapless
        # -----------------------------------------------------------------------
        "audio/mpeg"   = "com.github.neithern.g4music.desktop";
        "audio/ogg"    = "com.github.neithern.g4music.desktop";
        "audio/flac"   = "com.github.neithern.g4music.desktop";
        "audio/x-flac" = "com.github.neithern.g4music.desktop";
        "audio/wav"    = "com.github.neithern.g4music.desktop";
        "audio/x-wav"  = "com.github.neithern.g4music.desktop";
        "audio/mp4"    = "com.github.neithern.g4music.desktop";
        "audio/aac"    = "com.github.neithern.g4music.desktop";
        "audio/x-m4a"  = "com.github.neithern.g4music.desktop";
        "audio/opus"   = "com.github.neithern.g4music.desktop";
        "audio/webm"   = "com.github.neithern.g4music.desktop";

        # -----------------------------------------------------------------------
        # Document Viewer — Papers
        # -----------------------------------------------------------------------
        "application/pdf"               = "org.gnome.Papers.desktop";
        "application/x-pdf"             = "org.gnome.Papers.desktop";
        "image/vnd.djvu"                = "org.gnome.Papers.desktop";
        "image/vnd.djvu+multipage"      = "org.gnome.Papers.desktop";
        "application/epub+zip"          = "org.gnome.Papers.desktop";
        "application/vnd.comicbook+zip" = "org.gnome.Papers.desktop";
        "application/x-cbz"             = "org.gnome.Papers.desktop";
        "application/x-cbr"             = "org.gnome.Papers.desktop";

        # -----------------------------------------------------------------------
        # Text Editor — Neovim (fallback, lowest priority)
        # Overridden by VSCodium (plain) or Zed (mkForce) when installed.
        # -----------------------------------------------------------------------
        "text/plain"             = lib.mkDefault "nvim.desktop";
        "application/json"       = lib.mkDefault "nvim.desktop";
        "application/x-yaml"     = lib.mkDefault "nvim.desktop";
        "application/toml"       = lib.mkDefault "nvim.desktop";
        "application/x-shellscript" = lib.mkDefault "nvim.desktop";
        "text/x-shellscript"     = lib.mkDefault "nvim.desktop";
      };
    };

    # Neovim desktop entry — opens in Kitty (available on all graphical hosts)
    xdg.desktopEntries.nvim = {
      name        = "Neovim";
      genericName = "Text Editor";
      comment     = "Hyperextensible Vim-based text editor";
      exec        = "kitty nvim %F";
      terminal    = false;
      categories  = [ "Utility" "TextEditor" ];
      icon        = "nvim";
      mimeType    = [
        "text/plain"
        "application/json"
        "application/x-yaml"
        "application/toml"
        "application/x-shellscript"
        "text/x-shellscript"
      ];
    };

    # Replace an existing hand-edited mimeapps.list instead of failing the
    # activation on the file collision.
    xdg.configFile."mimeapps.list".force = true;
  }];

  # =========================================================================
  # Fonts — basic system-wide font set for every graphical host, whatever
  # the DE/WM. Users can add more in their own home.nix.
  #   enableDefaultPackages   NixOS's default set (DejaVu, Liberation, …)
  #   packages                the fonts below
  # Also available, not set here: fontDir.enable (/run/current-system/sw/
  # share/X11/fonts for X11/Flatpak apps), fontconfig.defaultFonts.
  # =========================================================================
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts               # Wide unicode coverage, clean and readable
      noto-fonts-cjk-sans      # Chinese, Japanese, Korean support
      liberation_ttf           # Free replacements for Arial, Times New Roman etc
      corefonts                # Real Arial, Times New Roman, Verdana, Georgia… (unfree)
      vista-fonts              # Real Calibri, Cambria, Consolas… — Office doc defaults (unfree; viewer-only licence)
      carlito                  # Free Calibri metric clone — use for commercial work
      caladea                  # Free Cambria metric clone — use for commercial work
      # noto-fonts-color-emoji intentionally omitted — it steals the
      # private-use-area codepoints that Nerd Fonts uses for icons,
      # breaking fastfetch and terminal icon rendering.
      # Nerd Fonts (all families) are already installed via system/core.
    ];
    fontconfig = {
      defaultFonts = {
        serif     = [ "Noto Serif" ];
        sansSerif = [ "Noto Sans" ];
        monospace = [ "JetBrainsMono Nerd Font" ];
      };
    };
  };
}
