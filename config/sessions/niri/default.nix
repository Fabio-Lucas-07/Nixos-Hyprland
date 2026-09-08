{ pkgs, ... }:

{
  xdg.configFile."niri/config.kdl" = {
    source = ./config.kdl;
    force = true; # Isso forçará o Home Manager a sobrescrever o arquivo existente
  };
}
