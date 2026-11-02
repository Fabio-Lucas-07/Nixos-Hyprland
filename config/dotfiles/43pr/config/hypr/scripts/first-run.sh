#!/usr/bin/env bash
# Na primeira sessão de cada PC: instala o wallpaper padrão e gera o tema.
state="${XDG_STATE_HOME:-$HOME/.local/state}/43pr/state.json"
[[ -f "$state" ]] && grep -q '"wallpaper":' "$state" && exit 0

source_image="$HOME/.config/43pr/default-wallpaper.jpg"
wallpaper="$HOME/Pictures/Wallpapers/default-wallpaper.jpg"

mkdir -p "$(dirname "$wallpaper")"
[[ -e "$wallpaper" ]] || cp -L "$source_image" "$wallpaper"

python3 "$HOME/.config/43pr/bin/theme.py" wallpaper "$wallpaper"
python3 "$HOME/.config/43pr/bin/theme.py" apply
