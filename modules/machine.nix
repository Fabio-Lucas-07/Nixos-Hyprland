# Tudo o que muda de um PC para outro. Os valores ficam em hosts/<nome>/default.nix.
{ config, lib, pkgs, ... }:

let
  cfg = config.machine;
  usesNvidia = builtins.elem cfg.gpu [ "nvidia" "nvidia-hybrid" ];
  isHybrid = cfg.gpu == "nvidia-hybrid";

  # Converte "PCI:1:0:0" (decimal) para "pci-0000:01:00.0", o formato do ID_PATH no udev.
  pciIdPath = busId:
    let
      parts = lib.splitString ":" busId;
      hex = number: lib.toLower (lib.fixedWidthString 2 "0" (lib.toHexString (lib.toInt number)));
    in
    "pci-0000:${hex (builtins.elemAt parts 1)}:${hex (builtins.elemAt parts 2)}.${builtins.elemAt parts 3}";

  # A saída HDMI fica ligada à NVIDIA, que não entra em repouso nesta sessão.
  hdmiSession = (pkgs.writeTextDir "share/wayland-sessions/hyprland-hdmi.desktop" ''
    [Desktop Entry]
    Name=Hyprland (HDMI)
    Comment=Hyprland com as saídas da NVIDIA ativas; a placa fica ligada
    Exec=${pkgs.writeShellScript "hyprland-hdmi" ''
      export AQ_DRM_DEVICES=/dev/dri/igpu:/dev/dri/dgpu
      exec ${config.programs.hyprland.package}/bin/start-hyprland
    ''}
    Type=Application
    DesktopNames=Hyprland
  '').overrideAttrs (_: {
    passthru.providedSessions = [ "hyprland-hdmi" ];
  });

  dpms = action: ''/run/current-system/sw/bin/hyprctl dispatch 'hl.dsp.dpms({ action = "${action}" })' '';
  brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
  loginctl = "${config.systemd.package}/bin/loginctl";

  suspendOnBattery = pkgs.writeShellScript "suspend-on-battery" ''
    for file in /sys/class/power_supply/A*/online; do
      read -r online <"$file"
      [ "$online" = 1 ] && exit 0
    done
    exec ${config.systemd.package}/bin/systemctl suspend-then-hibernate
  '';
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

    laptop = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Ativa a economia de energia, a tampa e o bloqueio por inatividade de notebooks.";
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
        powerManagement.enable = isHybrid;
        powerManagement.finegrained = isHybrid;
        open = cfg.nvidiaOpen;
        nvidiaSettings = true;
        package =
          if isHybrid
          then config.boot.kernelPackages.nvidiaPackages.stable
          else config.boot.kernelPackages.nvidiaPackages.beta;
      };
    })
    (lib.mkIf (cfg.gpu == "nvidia") {
      environment.sessionVariables = {
        LIBVA_DRIVER_NAME = "nvidia";
        GBM_BACKEND = "nvidia-drm";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      };
    })
    (lib.mkIf isHybrid {
      hardware.nvidia.prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        nvidiaBusId = cfg.prime.nvidiaBusId;
        amdgpuBusId = lib.mkIf (cfg.prime.integratedVendor == "amd") cfg.prime.integratedBusId;
        intelBusId = lib.mkIf (cfg.prime.integratedVendor == "intel") cfg.prime.integratedBusId;
      };

      # O número de /dev/dri/cardN muda entre boots; estes nomes não.
      # O ID_PATH exato deixa de fora o framebuffer provisório do boot.
      services.udev.extraRules = ''
        ACTION!="remove", SUBSYSTEM=="drm", KERNEL=="card[0-9]*", ENV{ID_PATH}=="${pciIdPath cfg.prime.integratedBusId}", SYMLINK+="dri/igpu"
        ACTION!="remove", SUBSYSTEM=="drm", KERNEL=="card[0-9]*", ENV{ID_PATH}=="${pciIdPath cfg.prime.nvidiaBusId}", SYMLINK+="dri/dgpu"
      '';

      # O Hyprland abre só a integrada, e a NVIDIA fica livre para desligar.
      environment.sessionVariables.AQ_DRM_DEVICES = "/dev/dri/igpu";
      services.displayManager.sessionPackages = [ hdmiSession ];
    })
    (lib.mkIf (isHybrid && cfg.prime.integratedVendor == "intel") {
      hardware.graphics.extraPackages = with pkgs; [ intel-media-driver vpl-gpu-rt ];
      environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
    })

    # Notebook
    (lib.mkIf cfg.laptop {
      services.fwupd.enable = true;

      boot.kernel.sysctl = {
        "kernel.nmi_watchdog" = 0;
        "vm.dirty_writeback_centisecs" = 1500;
      };

      # Na bateria, a tampa suspende e hiberna depois: em s2idle a bateria continua descendo.
      services.logind.settings.Login = {
        HandleLidSwitch = "suspend-then-hibernate";
        HandleLidSwitchExternalPower = "suspend";
        HandleLidSwitchDocked = "ignore";
      };
      systemd.sleep.settings.Sleep.HibernateDelaySec = "2h";

      home-manager.users.fabio.services.hypridle = {
        enable = true;
        settings = {
          general = {
            lock_cmd = "${pkgs.procps}/bin/pidof hyprlock || ${pkgs.hyprlock}/bin/hyprlock";
            before_sleep_cmd = "${loginctl} lock-session";
            after_sleep_cmd = dpms "on";
          };
          listener = [
            {
              timeout = 180;
              on-timeout = "${brightnessctl} -s set 30%";
              on-resume = "${brightnessctl} -r";
            }
            {
              timeout = 300;
              on-timeout = "${loginctl} lock-session";
            }
            {
              timeout = 330;
              on-timeout = dpms "off";
              on-resume = dpms "on";
            }
            {
              timeout = 900;
              on-timeout = "${suspendOnBattery}";
            }
          ];
        };
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
