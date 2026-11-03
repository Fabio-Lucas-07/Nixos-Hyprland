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

  dpms = action: ''/run/current-system/sw/bin/hyprctl dispatch 'hl.dsp.dpms({ action = "${action}" })' '';
  # "[!n]*" ignora o nvidia_0, que o brightnessctl escolheria mas não controla a tela do híbrido.
  brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl -c backlight -d '[!n]*'";
  loginctl = "${config.systemd.package}/bin/loginctl";

  # Parte de suspend-then-hibernate do hook da NVIDIA (lib/systemd/system-sleep/nvidia).
  # O resto dele chama chvt sem o kbd no PATH, e a tela ficaria preta na suspensão comum.
  nvidiaSleepHook = pkgs.writeShellScript "nvidia-suspend-then-hibernate-hook" ''
    if [ "$2" = suspend-then-hibernate ] && [ -f /proc/driver/nvidia/suspend ]; then
      case "$1:$SYSTEMD_SLEEP_ACTION" in
        post:*) echo resume >/proc/driver/nvidia/suspend ;;
        pre:hibernate) echo hibernate >/proc/driver/nvidia/suspend ;;
        pre:suspend-after-failed-hibernate) echo suspend >/proc/driver/nvidia/suspend ;;
      esac
    fi
  '';

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
          then config.boot.kernelPackages.nvidiaPackages.stable.overrideAttrs (old: {
            # Corrigem Oops do kernel sem solução oficial até o driver 615:
            # - imagem da GPU integrada em monitor da NVIDIA (open-gpu-kernel-modules, discussão 1356);
            # - eventos ACPI em paralelo, comuns na bateria (fórum da NVIDIA, tópico 385856).
            patches = (old.patches or [ ]) ++ [
              ../patches/nvidia-drm-null-pmemory.patch
              ../patches/nvidia-acpi-notify-mutex.patch
            ];
          })
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

      # Com as duas abertas, um monitor conectado na NVIDIA funciona na hora. Sem monitor nela,
      # o Hyprland destrói o que tinha criado na placa, e ela desliga sozinha.
      environment.sessionVariables.AQ_DRM_DEVICES = "/dev/dri/igpu:/dev/dri/dgpu";

      # O console ocuparia o monitor assim que conectado e manteria a NVIDIA ligada sem sessão.
      hardware.nvidia.moduleParams.nvidia-drm.fbdev = lib.mkForce 0;

      # O módulo do NixOS só prepara o driver para suspend e hibernate. Sem isto,
      # suspend-then-hibernate falha com -EIO e o notebook continua ligado.
      systemd.services.nvidia-suspend-then-hibernate = {
        description = "NVIDIA system suspend-then-hibernate actions";
        path = [ pkgs.kbd ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${config.hardware.nvidia.package.out}/bin/nvidia-sleep.sh 'suspend'";
        };
        before = [ "systemd-suspend-then-hibernate.service" ];
        requiredBy = [ "systemd-suspend-then-hibernate.service" ];
      };
      systemd.services.nvidia-resume = {
        after = [ "systemd-suspend-then-hibernate.service" ];
        requiredBy = [ "systemd-suspend-then-hibernate.service" ];
      };
      environment.etc."systemd/system-sleep/nvidia-suspend-then-hibernate".source = nvidiaSleepHook;
    })
    (lib.mkIf (isHybrid && cfg.prime.integratedVendor == "intel") {
      hardware.graphics.extraPackages = with pkgs; [ intel-media-driver vpl-gpu-rt ];
      environment.sessionVariables.LIBVA_DRIVER_NAME = "iHD";
      # Jogos com VSync desligado renderizavam milhares de quadros a mais que a tela mostra,
      # esquentando o chip que a GPU Intel divide com a CPU. Isto limita o OpenGL da Mesa à
      # frequência do monitor; um jogo pode voltar ao ilimitado com `vblank_mode=0 %command%`.
      environment.sessionVariables.vblank_mode = "3";
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
