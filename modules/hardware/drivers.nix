# ===========================================================================
# modules/hardware/drivers.nix — GPU and CPU driver configuration
#
# Picks GPU drivers, graphics libraries and CPU microcode from one host
# option. Every host must set exactly one value (there is no default):
#
#   hardware.gpu = "amd";          # AMD CPU + AMD GPU (most hosts)
#   hardware.gpu = "intel";        # Intel CPU + Intel integrated graphics
#   hardware.gpu = "nvidia-hybrid"; # AMD CPU + Nvidia GPU (e.g. Asus-A15)
#
# Upstream hardware.graphics options:
#   enable / enable32Bit             OpenGL/Vulkan, plus 32-bit libs (Steam)
#   extraPackages / extraPackages32  VA-API, OpenCL and other driver add-ons
#   package / package32              Mesa build to use (not set here)
# ===========================================================================

{ config, pkgs, lib, ... }:

# hardware.gpu — this module's one option; each block below is enabled by
# its value.
{
  options.hardware.gpu = lib.mkOption {
    type = lib.types.enum [ "amd" "intel" "nvidia-hybrid" ];
    # No default: evaluation fails if a host forgets to set it.
    description = "GPU type for this host. Must be set in every host config.";
  };

  # One lib.mkIf block per GPU type, combined with lib.mkMerge.
  config = lib.mkMerge [

    # =========================================================================
    # AMD — used by most desktops and laptops
    #
    # amdgpu is the open-source AMD kernel driver; Mesa (RADV, radeonsi)
    # provides Vulkan, OpenGL and VA-API video decoding on top of it.
    # =========================================================================
    (lib.mkIf (config.hardware.gpu == "amd") {
      # Load amdgpu in the initrd, before the root filesystem mounts, so the
      # console switches to the GPU's framebuffer early without a black flash.
      boot.initrd.kernelModules = [ "amdgpu" ];

      services.xserver.videoDrivers = [ "amdgpu" ];

      # AMD GPU firmware blobs (PSP, SMU, DCN, GFX) ship in linux-firmware,
      # a redistributable package. Without them amdgpu loads but cannot
      # initialise the GPU. (enableAllFirmware would add non-redistributable
      # blobs too.)
      hardware.enableRedistributableFirmware = true;

      hardware = {
        # Enable general OpenGL/Vulkan support
        graphics = {
          enable = true;
          # 32-bit support is required for Steam and many games
          enable32Bit = true;
          # OpenCL for GPU compute through ROCm. VA-API video decoding needs
          # nothing extra: Mesa's radeonsi driver includes it.
          extraPackages = with pkgs; [
            rocmPackages.clr # OpenCL support for GPU compute
            rocmPackages.clr.icd # registers clr with the OpenCL loader (/etc/OpenCL/vendors); without it: CL error -1001
          ];
          # 32-bit RADV comes with the 32-bit Mesa that enable32Bit installs
        };

        # AMD CPU microcode updates, loaded at boot; they fix CPU bugs
        # without a BIOS update.
        cpu.amd.updateMicrocode = true;
      };
    })

    # =========================================================================
    # INTEL — used by MinisForum UN1250 and Radxa X4 (headless servers)
    #
    # Intel integrated graphics use the i915 kernel driver. On headless
    # servers this mainly loads the right module so boot logs no GPU errors,
    # and gives VA-API decoding to services that transcode.
    # =========================================================================
    (lib.mkIf (config.hardware.gpu == "intel") {
      boot.initrd.kernelModules = [ "i915" ];

      services.xserver.videoDrivers = [ "intel" ];

      hardware = {
        graphics = {
          enable = true;
          enable32Bit = true;
          # Intel media driver for hardware video decoding (VA-API)
          extraPackages = with pkgs; [
            intel-media-driver  # For newer Intel (Broadwell and later, covers i5-1250P)
            intel-vaapi-driver  # Older fallback driver
            libvdpau-va-gl      # VDPAU over VA-API bridge (for some video players)
          ];
        };

        # Intel CPU microcode updates
        cpu.intel.updateMicrocode = true;

        # linux-firmware: i915 GuC/HuC/DMC blobs plus the board's WiFi/BT
        # firmware (MinisForum's MediaTek MT7902 Bluetooth needs it).
        enableRedistributableFirmware = true;
      };
    })

    # =========================================================================
    # NVIDIA HYBRID — used by Asus-A15
    #
    # Hybrid graphics means there are TWO GPUs:
    #   - The AMD integrated GPU (always on, handles the display output)
    #   - The Nvidia discrete GPU (more powerful, used for demanding tasks)
    #
    # PRIME offloading lets the system use the Nvidia GPU on demand
    # (e.g. for a game) while the AMD iGPU handles everything else, which
    # saves battery compared to keeping Nvidia always on.
    #
    # hardware.nvidia options used below, and others available:
    #   modesetting.enable          kernel modesetting (needed for PRIME)
    #   prime.offload.enable        Nvidia only on request (nvidia-offload)
    #   prime.sync.enable           always render on Nvidia (alternative)
    #   prime.reverseSync.enable    Nvidia drives the external outputs
    #   prime.amdgpuBusId / nvidiaBusId   PCI bus IDs, set per host
    #   powerManagement.enable      save VRAM across suspend
    #   powerManagement.finegrained power the dGPU off when idle (offload)
    #   open                        open-source kernel module
    #   package / branch            driver build (default branch "stable")
    #   nvidiaSettings              install the nvidia-settings GUI
    #   dynamicBoost.enable, nvidiaPersistenced, gsp.enable, videoAcceleration
    # =========================================================================
    (lib.mkIf (config.hardware.gpu == "nvidia-hybrid") {
      # amdgpu in the initrd for the display; the Nvidia modules come from
      # videoDrivers = [ "nvidia" ].
      boot.initrd.kernelModules = [ "amdgpu" ];

      services.xserver.videoDrivers = [ "nvidia" ];

      hardware = {
        graphics = {
          enable = true;
          enable32Bit = true;
        };

        nvidia = {
          # Kernel modesetting, required for PRIME. The driver package is the
          # default "stable" branch.
          modesetting.enable = true;

          # PRIME offloading — Nvidia GPU activates only when asked.
          # Apps can request the Nvidia GPU by running with:
          #   nvidia-offload <application>
          # Everything else uses the AMD iGPU automatically.
          prime = {
            offload = {
              enable = true;
              enableOffloadCmd = true; # Adds the `nvidia-offload` helper command
            };
            # amdgpuBusId and nvidiaBusId are machine-specific and are set in
            # the host config (e.g. hosts/Asus-A15/Asus-A15.nix), not here.
          };

          # Saves VRAM across suspend/resume on hybrid systems
          powerManagement = {
            enable = true;
            finegrained = true; # Allows Nvidia GPU to fully power down when idle
          };

          # Open-source Nvidia kernel module (Turing and newer GPUs) instead
          # of the proprietary one
          open = true;
        };

        # AMD microcode for the CPU side
        cpu.amd.updateMicrocode = true;
      };
    })

  ]; # end mkMerge
}
