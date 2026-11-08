# Notebook: Alienware 16 Aurora (Intel Core 5 210H + RTX 4050), com Windows no mesmo disco.
{ config, lib, pkgs, ... }:

let
  systemctl = "${config.systemd.package}/bin/systemctl";
  dgpuPowerControl = "/sys/bus/pci/devices/0000:01:00.0/power/control";
in
{
  imports = [ ./hardware-configuration.nix ];

  machine = {
    gpu = "nvidia-hybrid";
    # O módulo fechado é o que já entra em D3cold neste notebook.
    nvidiaOpen = false;
    secureBoot = true;
    laptop = true;
    prime = {
      nvidiaBusId = "PCI:1:0:0";
      integratedVendor = "intel";
      integratedBusId = "PCI:0:2:0";
    };
  };

  hardware.enableRedistributableFirmware = true;

  # Controla a potência pelas tabelas térmicas do firmware, como na configuração anterior com niri.
  services.thermald.enable = true;

  # A Steam roda em resolução real no XWayland e precisa da própria escala para não ficar minúscula.
  environment.sessionVariables.STEAM_FORCE_DESKTOPUI_SCALING = "1.5";

  # Este firmware só oferece s2idle, então o driver precisa usar S0ix ao suspender.
  hardware.nvidia.moduleParams.nvidia = {
    NVreg_EnableS0ixPowerManagement = 1;
    NVreg_TemporaryFilePath = "/var/tmp";
  };

  # nvidia-powerd libera até 65 W na GPU, mas pode impedir o D3cold: só roda na tomada.
  hardware.nvidia.dynamicBoost.enable = true;
  systemd.services.nvidia-powerd.wantedBy = lib.mkForce [ ];

  # Na tomada, a NVIDIA fica ligada; na bateria, volta a desligar quando ociosa.
  systemd.services.nvidia-on-ac = {
    description = "Mantém a NVIDIA ligada enquanto o notebook está na tomada";
    wantedBy = [ "multi-user.target" ];
    after = [ "dbus.service" "systemd-modules-load.service" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecCondition = pkgs.writeShellScript "nvidia-on-ac-condition" ''
        read -r online </sys/class/power_supply/AC/online
        [ "$online" = 1 ]
      '';
      ExecStart = pkgs.writeShellScript "nvidia-on-ac-start" ''
        echo on >${dgpuPowerControl}
        ${systemctl} start --no-block nvidia-powerd.service
      '';
      ExecStop = pkgs.writeShellScript "nvidia-on-ac-stop" ''
        ${systemctl} stop --no-block nvidia-powerd.service
        echo auto >${dgpuPowerControl}
      '';
    };
  };

  # O Bluetooth do MT7925 às vezes não responde ao iniciar ("Failed to send wmt func ctrl
  # (-110)") e fica sem funcionar até reiniciar. Desligar a suspensão automática do USB dele
  # é a correção mais usada para esse erro.
  boot.extraModprobeConfig = "options btusb enable_autosuspend=0";

  boot.blacklistedKernelModules = [
    "xe" # A iGPU usa o i915; o xe carregava sem controlar nenhum dispositivo.
    "spd5118" # Falha com erro -6 em toda retomada; só lê a temperatura da RAM.
    "dell_smm_hwmon" # Cada leitura para a CPU em SMM; as ventoinhas seguem em alienware_wmi.
  ];

  # Com o cabo desligado, a porta Ethernet ativa (e sem ASPM) impede estados ociosos profundos.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10ec", ATTR{device}=="0x8168", ATTR{power/control}="auto"
    ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="AC", ATTR{online}=="1", RUN+="${systemctl} start --no-block nvidia-on-ac.service"
    ACTION=="change", SUBSYSTEM=="power_supply", KERNEL=="AC", ATTR{online}=="0", RUN+="${systemctl} stop --no-block nvidia-on-ac.service"
  '';

  # Só para hibernar: a zram tem prioridade maior e continua sendo a swap do dia a dia.
  # O systemd grava a posição do arquivo na EFI ao hibernar, sem precisar de resume_offset.
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 17 * 1024;
    }
  ];

  # O Windows mantém o relógio do hardware em horário local.
  time.hardwareClockInLocalTime = true;

  system.stateVersion = "26.05";
}
