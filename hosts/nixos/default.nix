# PC principal: desktop AMD + NVIDIA, com Secure Boot (Lanzaboote).
{ ... }:

{
  imports = [ ./hardware-configuration.nix ];

  machine = {
    gpu = "nvidia";
    secureBoot = true;
  };

  hardware.cpu.amd.updateMicrocode = true;
  powerManagement.cpuFreqGovernor = "performance";
  time.hardwareClockInLocalTime = true;

  system.stateVersion = "26.05";
}
