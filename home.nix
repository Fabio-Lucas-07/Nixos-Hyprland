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
  # Injeta os programas automaticamente e define a sessão do Niri
  imports = [
    ./config/sessions/niri
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
        gtk.enable = true;
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
      "https://github.com/yeyushengfan258/ArcMidnight-Cursors/archive/refs/heads/main.zip"
      "sha256-VgOpt0rukW0+rSkLFoF9O0xO/qgwieAchAev1vjaqPE="
      "ArcMidnight-Cursors";

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "adw-gtk3-dark";
    };
  };

  home.sessionVariables = {};

  services.easyeffects.enable = true;

  gtk = {
    enable = true;

    gtk3.extraCss = ''@import url("file:///home/fabio/.cache/matugen/colors-gtk.css");'';
    gtk4.extraCss = ''@import url("file:///home/fabio/.cache/matugen/colors-gtk.css");'';

    gtk3.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
      gtk-theme-name = "adw-gtk3-dark";
    };

    gtk4.extraConfig = {
      gtk-application-prefer-dark-theme = 1;
    };
  };

  qt = {
    enable = true;
    platformTheme.name = "qt6ct";
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
    config.common.default = "*";
  };

  programs.home-manager.enable = true;

  fonts.fontconfig.enable = true;
}
