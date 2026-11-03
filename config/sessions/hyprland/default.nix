{ ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;

    # O compositor e o portal vêm de programs.hyprland, em configuration.nix.
    package = null;
    portalPackage = null;

    # A sessão e o ambiente do systemd são do uwsm, e os dois juntos entram em conflito.
    systemd.enable = false;

    configType = "lua";
    extraConfig = builtins.readFile ../../dotfiles/43pr/config/hypr/hyprland.lua;
  };
}
