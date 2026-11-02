{ ... }:

{
  wayland.windowManager.hyprland = {
    enable = true;

    # O compositor e o portal vêm de programs.hyprland, em configuration.nix.
    package = null;
    portalPackage = null;

    configType = "lua";
    extraConfig = builtins.readFile ../../dotfiles/43pr/config/hypr/hyprland.lua;
  };
}
