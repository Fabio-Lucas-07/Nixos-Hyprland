# Tudo o que muda de um PC para outro. Os valores ficam em hosts/<nome>/default.nix.
{ config, lib, pkgs, ... }:

let
  cfg = config.machine;
  usesNvidia = builtins.elem cfg.gpu [ "nvidia" "nvidia-hybrid" ];
in
{
  options.machine = {
    gpu = lib.mkOption {
      type = lib.types.enum [ "nvidia" "nvidia-hybrid" "amd" "intel" "generic" ];
      default = "generic";
      description = ''
        GPU deste PC. "nvidia-hybrid" é para notebooks com GPU integrada e
        NVIDIA: a tela roda na integrada e `nvidia-offload` usa a NVIDIA.
      '';
    };

    nvidiaOpen = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Usa o módulo aberto da NVIDIA (exige GTX 16xx, RTX ou mais nova).";
    };

    prime = {
      nvidiaBusId = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "PCI:1:0:0";
      };
      integratedVendor = lib.mkOption {
        type = lib.types.enum [ "amd" "intel" ];
        default = "intel";
      };
      integratedBusId = lib.mkOption {
        type = lib.types.str;
        default = "";
        example = "PCI:0:2:0";
      };
    };

    secureBoot = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Inicia pelo Lanzaboote. As chaves são próprias de cada PC e precisam
        existir em /etc/secureboot antes de ativar.
      '';
    };
  };

  config = lib.mkMerge [
    # Boot
    {
      boot.loader.efi.canTouchEfiVariables = true;
      boot.loader.systemd-boot.configurationLimit = 2;
    }
    (lib.mkIf cfg.secureBoot {
      boot.loader.systemd-boot.enable = lib.mkForce false;
      boot.lanzaboote = {
        enable = true;
        pkiBundle = "/etc/secureboot";
      };
    })
    (lib.mkIf (!cfg.secureBoot) {
      boot.loader.systemd-boot.enable = true;
    })

    # NVIDIA
    (lib.mkIf usesNvidia {
      services.xserver.videoDrivers = [ "nvidia" ];
      hardware.graphics.extraPackages = with pkgs; [ nvidia-vaapi-driver ];

      hardware.nvidia = {
        modesetting.enable = true;
        powerManagement.enable = false;
        powerManagement.finegrained = false;
        open = cfg.nvidiaOpen;
        nvidiaSettings = true;
        package = config.boot.kernelPackages.nvidiaPackages.beta;
      };
    })
    (lib.mkIf (cfg.gpu == "nvidia") {
      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = "nvidia";
        GBM_BACKEND = "nvidia-drm";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      };
    })
    (lib.mkIf (cfg.gpu == "nvidia-hybrid") {
      hardware.nvidia.prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        nvidiaBusId = cfg.prime.nvidiaBusId;
        amdgpuBusId = lib.mkIf (cfg.prime.integratedVendor == "amd") cfg.prime.integratedBusId;
        intelBusId = lib.mkIf (cfg.prime.integratedVendor == "intel") cfg.prime.integratedBusId;
      };
    })

    # Outras GPUs
    (lib.mkIf (cfg.gpu == "amd") {
      services.xserver.videoDrivers = [ "amdgpu" ];
    })
    (lib.mkIf (cfg.gpu == "intel") {
      hardware.graphics.extraPackages = with pkgs; [ intel-media-driver ];
    })
  ];
}
