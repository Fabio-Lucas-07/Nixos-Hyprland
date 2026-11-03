# Tema 43PR: barra e menus em Quickshell, tema dinâmico e configurações dos aplicativos.
{ config, lib, pkgs, ... }:

let
  # Os arquivos ficam editáveis no repositório, como no instalador original do tema.
  repoConfig = "/etc/nixos/config/dotfiles/43pr/config";
  source = ./config;

  # Escritos pelo tema ou pelos aplicativos: cada PC recebe uma cópia própria.
  perMachineFiles = [
    "gtk-3.0/settings.ini"
    "gtk-4.0/settings.ini"
    "quickshell/Theme.qml"
    "btop/btop.conf"
    "nwg-look/config"
    "xed/accels"
  ];

  # Gerado pelo módulo do Hyprland em config/sessions/hyprland.
  mainHyprlandConfig = "hypr/hyprland.lua";

  relativePath = file: lib.removePrefix "${toString source}/" (toString file);
  allFiles = map relativePath (lib.filesystem.listFilesRecursive source);
  linkedFiles = builtins.filter
    (file: file != mainHyprlandConfig && !(builtins.elem file perMachineFiles))
    allFiles;
in
{
  home.packages = with pkgs; [
    awww
    brightnessctl
    cava
    cliphist
    dmidecode
    eza
    ffmpegthumbnailer
    gammastep
    glib
    gnome-themes-extra
    hyprlock
    hyprpicker
    jq
    libnotify
    lm_sensors
    ncdu
    networkmanagerapplet
    nvtopPackages.full
    pavucontrol
    rofi
    unzip
    wl-clipboard
    xdg-utils
    xed-editor
  ];

  services.hyprpolkitagent.enable = true;

  programs.starship = {
    enable = true;
    enableFishIntegration = true;
    enableZshIntegration = false;
    enableBashIntegration = false;
  };

  xdg.configFile = lib.genAttrs linkedFiles (file: {
    source = config.lib.file.mkOutOfStoreSymlink "${repoConfig}/${file}";
  });

  # Um link quebrado de uma configuração antiga, como ~/.config/matugen, faz o `mkdir`
  # do Home Manager falhar, e a ativação para sem instalar nenhuma dot.
  home.activation.removeStaleLinks = lib.hm.dag.entryBefore [ "checkLinkTargets" ] ''
    for file in ${lib.escapeShellArgs linkedFiles}; do
      path="${config.xdg.configHome}/$file"
      while [ "$path" != "${config.xdg.configHome}" ]; do
        if [ -L "$path" ] && [ ! -e "$path" ]; then
          run rm "$path"
        fi
        path="''${path%/*}"
      done
    done
  '';

  home.activation.seedPerMachineFiles = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    for file in ${lib.escapeShellArgs perMachineFiles}; do
      target="${config.xdg.configHome}/$file"
      if [ ! -e "$target" ] && [ -f "${repoConfig}/$file" ]; then
        run mkdir -p "$(dirname "$target")"
        run cp "${repoConfig}/$file" "$target"
        run chmod u+w "$target"
      fi
    done
  '';
}
