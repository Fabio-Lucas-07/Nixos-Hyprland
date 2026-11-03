{ config, pkgs, ... }:

let
  # 1. Define o caminho para a pasta de programas
  programsDir = ./config/programs;

  # 2. Lê o conteúdo do diretório
  files = builtins.readDir programsDir;

  # 3. Filtra apenas as pastas (ignorando arquivos soltos)
  directories = builtins.filter 
    (name: files.${name} == "directory") 
    (builtins.attrNames files);

  # 4. Mapeia os nomes para os caminhos de importação
  programImports = map (name: programsDir + "/${name}") directories;
in
{
  # Injeta os programas automaticamente e define a sessão do Hyprland
  imports = [
    ./config/sessions/hyprland
    ./config/dotfiles/43pr
  ] ++ programImports;

  home.username = "fabio";
  home.homeDirectory = "/home/fabio";
  home.stateVersion = "25.11";
  
  home.file.".config/VSCodium/product.json".text = builtins.toJSON {
  extensionsGallery = {
    serviceUrl = "https://marketplace.visualstudio.com/_apis/public/gallery";
    itemUrl = "https://marketplace.visualstudio.com/items";
  };
};
  home.packages = with pkgs; [
    adwaita-icon-theme
    adw-gtk3
    libsForQt5.qt5ct
    qt6Packages.qt6ct
  ];

  home.pointerCursor =
    let
      getFrom = url: hash: name: {
        enable = true;
        x11.enable = true;
        name = name;
        size = 24;
        package =
          pkgs.runCommand "moveUp" {} ''
            mkdir -p $out/share/icons
            ln -s ${pkgs.fetchzip {
              url = url;
              hash = hash;
            }}/dist $out/share/icons/${name}
          '';
      };
    in
    getFrom
      "https://github.com/yeyushengfan258/ArcMidnight-Cursors/archive/7f7d140a41fc134e72747d1052965b2c308b99de.zip"
      "sha256-VgOpt0rukW0+rSkLFoF9O0xO/qgwieAchAev1vjaqPE="
      "ArcMidnight-Cursors";

  home.sessionVariables = {};

  services.easyeffects.enable = true;

  qt = {
    enable = true;
    platformTheme.name = "qt6ct";
  };

  programs.fish = {
    enable = true;

    interactiveShellInit = ''
      set -e IN_NIX_SHELL
      set -e name
      fastfetch --config examples/32.jsonc
    '';

    # `nv programa` abre o programa na GPU NVIDIA.
    shellAbbrs.nv = "nvidia-offload";


  };
  
  programs.home-manager.enable = true;

  fonts.fontconfig.enable = true;
}
