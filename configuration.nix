{ config, pkgs, lib, ... }:
{
  imports = [
    ./modules/machine.nix
    ./config/dotfiles/43pr/system.nix
  ];

  home-manager.useGlobalPkgs = true;
  home-manager.useUserPackages = true;

  home-manager.users.fabio = {
    imports = [ ./home.nix ];
  };

  #open port 4242 for lan-mouse
  networking.firewall.allowedUDPPorts = [ 4242 ];
  hardware.uinput.enable = true;
    
  boot.kernelPackages = pkgs.linuxPackages;

  boot.kernelModules = [ "tcp_bbr" ];
  boot.kernel.sysctl = {
    "net.ipv4.tcp_congestion_control" = "bbr";
    "net.core.default_qdisc" = "fq";
    "net.core.wmem_max" = 1073741824;
    "net.core.rmem_max" = 1073741824;
    "net.ipv4.tcp_rmem" = "4096 87380 1073741824";
    "net.ipv4.tcp_wmem" = "4096 87380 1073741824";
  };

  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  environment.sessionVariables = {
    NIXOS_OZONE_WL = "1";
    ELECTRON_OZONE_PLATFORM_HINT = "wayland";
    ELECTRON_ENABLE_WAYLAND = "1";
  };

  networking.networkmanager.enable = true;
  services.timesyncd.enable = true;

  time.timeZone = "America/Sao_Paulo";

  i18n.defaultLocale = "en_US.UTF-8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "pt_BR.UTF-8";
    LC_IDENTIFICATION = "pt_BR.UTF-8";
    LC_MEASUREMENT = "pt_BR.UTF-8";
    LC_MONETARY = "pt_BR.UTF-8";
    LC_NAME = "pt_BR.UTF-8";
    LC_NUMERIC = "pt_BR.UTF-8";
    LC_PAPER = "pt_BR.UTF-8";
    LC_TELEPHONE = "pt_BR.UTF-8";
    LC_TIME = "pt_BR.UTF-8";
  };

  services.xserver.enable = true;

  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = false;

  programs.hyprland.enable = true;

  # Sem sessão padrão, o GDM tenta abrir o gnome-session e entra em loop de login.
  services.displayManager.defaultSession = "hyprland";

  # Senhas salvas dos aplicativos e agente SSH.
  services.gnome.gnome-keyring.enable = true;

  services.xserver.xkb = {
    layout = "us";
    variant = "intl";
  };
  console.keyMap = "us-acentos";

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gtk
    ];
    config = {
      hyprland = {
        default = [ "hyprland" "gtk" ];
        "org.freedesktop.impl.portal.Secret" = "gnome-keyring";
      };
      common = {
        default = [ "gtk" ];
      };
    };
  };

  fonts.packages = with pkgs; [
    powerline-fonts
    nerd-fonts.fira-code
    inter
    jetbrains-mono
    nerd-fonts.iosevka
    udev-gothic-nf
    noto-fonts
    liberation_ttf
  ];

  fonts.fontconfig = {
    enable = true;
    hinting.style = "slight";
    subpixel.rgba = "rgb";
  };

  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
  };
  services.blueman.enable = true;

  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = true;

  services.hardware.openrgb = {
    enable = true;
    startupProfile = "Default";
  };

  programs.zsh.enable = true;
  programs.fish = {
   enable = true;
   promptInit = "";
   interactiveShellInit = ''
     set -g fish_greeting ""
   '';
 };

  programs.dconf.enable = true;
  programs.firefox.enable = true;
  services.flatpak.enable = true;
  services.cron.enable = true;
  services.printing.enable = true;
  services.openssh.enable = true;

  programs.steam = {
    enable = true;
    remotePlay.openFirewall = true;
    dedicatedServer.openFirewall = true;
    package = pkgs.steam.override {
      extraArgs = "-system-composer";
    };
  };
  programs.gamemode.enable = true;

  virtualisation.libvirtd.enable = true;
  virtualisation.docker.enable = true;
  programs.virt-manager.enable = true;

  services.power-profiles-daemon.enable = true;

  zramSwap = {
    enable = true;
    memoryPercent = 50;
  };

  services.postgresql = {
    enable = true;
    authentication = ''
      host    all             all             127.0.0.1/32            trust
      host    all             all             ::1/128                 trust
    '';
  };

  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nixpkgs.config.allowUnfree = true;

  nix.gc = {
    automatic = true;
    dates = "daily";
    options = "--delete-older-than 14d";
  };

  users.users."fabio" = {
    isNormalUser = true;
    description = "Fabio";
    extraGroups = [ "networkmanager" "wheel" "video" "adbusers" "libvirtd" "docker" ];
    shell = pkgs.fish;
  };

  users.defaultUserShell = pkgs.fish;

  security.sudo.extraRules = [
    {
      users = [ "fabio" ];
      commands = [
        {
          command = "ALL";
          options = [ "NOPASSWD" ];
        }
      ];
    }
  ];

  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
  };

  environment.pathsToLink = [ "/share/gsettings-schemas" ];

  environment.systemPackages = with pkgs; [
    wget curl git btop fzf direnv zbar p7zip fastfetch
    yq-go wmctrl inotify-tools lavat file pipes clock-rs cbonsai killall
    psmisc eww swappy slurp grim playerctl satty cmatrix sl nodejs gh


    (pkgs.vscodium-fhs.overrideAttrs (oldAttrs: {
    # Altera o product.json empacotado para apontar para o Marketplace oficial
    postInstall = (oldAttrs.postInstall or "") + ''
      jq -s '.[0] * .[1]' $out/lib/vscode/resources/app/product.json \
        <(echo '{"extensionsGallery":{"serviceUrl":"https://marketplace.visualstudio.com/_apis/public/gallery","itemUrl":"https://marketplace.visualstudio.com/items"}}') \
        > $out/lib/vscode/resources/app/product.json.tmp && \
      mv $out/lib/vscode/resources/app/product.json.tmp $out/lib/vscode/resources/app/product.json
    '';
  }))

     maven jdk21 python3 android-tools
    pgadmin4-desktopmode  neovim
    dotnet-sdk pkgsCross.mingwW64.stdenv.cc
    
    lan-mouse
    
    discord brave vesktop telegram-desktop obsidian onlyoffice-desktopeditors
    libreoffice-qt hunspell hunspellDicts.ru_RU hunspellDicts.en_US papers
    kdePackages.kolourpaint mission-center glaxnimate inkscape
    hicolor-icon-theme papirus-icon-theme nwg-look
    insomnia spotify linux-wallpaperengine nautilus

    mpv obs-studio gpu-screen-recorder ffmpeg qbittorrent bottles steam-run
    protonup-qt

    oh-my-fish fish kitty alacritty taskwarrior3 zenity matugen xdg-desktop-portal-gtk
    mpvpaper power-profiles-daemon
    xdg-user-dirs imagemagick

    (quickshell.overrideAttrs (oldAttrs: {
      buildInputs = (oldAttrs.buildInputs or []) ++ (with qt6; [
        qtsvg
        qtmultimedia
        qtimageformats
        qtwayland
        qtdeclarative
        qt5compat
      ]);
    }))
  ];
}
