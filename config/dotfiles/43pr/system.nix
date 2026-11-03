# Partes do tema 43PR que exigem configuração do sistema.
{ pkgs, ... }:

{
  # Tela de bloqueio.
  security.pam.services.hyprlock = { };

  # Bateria na barra e lixeira/montagem no gerenciador de arquivos.
  services.upower.enable = true;
  services.gvfs.enable = true;

  # O tema define o modo claro ou escuro pelo gsettings, que não acha os schemas sem isto.
  environment.sessionVariables.GSETTINGS_SCHEMA_DIR =
    "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";

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
