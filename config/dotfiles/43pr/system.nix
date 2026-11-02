# Partes do tema 43PR que exigem configuração do sistema.
{ pkgs, ... }:

{
  # Tela de bloqueio.
  security.pam.services.hyprlock = { };

  # Bateria na barra e lixeira/montagem no gerenciador de arquivos.
  services.upower.enable = true;
  services.gvfs.enable = true;

  # Lista de layouts de teclado nas configurações.
  environment.systemPackages = [ pkgs.xkeyboard_config ];
  environment.pathsToLink = [ "/share/X11/xkb" ];

  fonts.packages = with pkgs; [
    adwaita-fonts
    font-awesome
    nerd-fonts.jetbrains-mono
    roboto-mono
  ];

  # Guarda arquivos existentes em vez de interromper a ativação em um PC novo.
  home-manager.backupFileExtension = "hm-bak";
}
