# Notebook: Alienware 16 Aurora (Intel Core 5 210H + RTX 4050), com Windows no mesmo disco.
{ config, lib, pkgs, ... }:

let
  sudo = "/run/wrappers/bin/sudo";
  systemctl = "${config.systemd.package}/bin/systemctl";
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

  # Este firmware só oferece s2idle, então o driver precisa usar S0ix ao suspender.
  hardware.nvidia.moduleParams.nvidia = {
    NVreg_EnableS0ixPowerManagement = 1;
    NVreg_TemporaryFilePath = "/var/tmp";
  };

  # nvidia-powerd libera até 65 W na GPU, mas pode impedir o D3cold:
  # só roda enquanto há um jogo em `gamemoderun`.
  hardware.nvidia.dynamicBoost.enable = true;
  systemd.services.nvidia-powerd.wantedBy = lib.mkForce [ ];
  programs.gamemode.settings.custom = {
    start = "${sudo} ${systemctl} start nvidia-powerd.service";
    end = "${sudo} ${systemctl} stop nvidia-powerd.service";
  };

  boot.blacklistedKernelModules = [
    "xe" # A iGPU usa o i915; o xe carregava sem controlar nenhum dispositivo.
    "spd5118" # Falha com erro -6 em toda retomada; só lê a temperatura da RAM.
    "dell_smm_hwmon" # Cada leitura para a CPU em SMM; as ventoinhas seguem em alienware_wmi.
  ];

  # Com o cabo desligado, a porta Ethernet ativa (e sem ASPM) impede estados ociosos profundos.
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10ec", ATTR{device}=="0x8168", ATTR{power/control}="auto"
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
