#!/usr/bin/env bash
# Instala esta configuração em um PC com NixOS já instalado (UEFI, x86_64).
#
#   ./install.sh [--host NOME] [--generate-only]
#
# Cria hosts/<NOME> com o hardware detectado, coloca o repositório em
# /etc/nixos e prepara o sistema para iniciar com ele no próximo boot.
#
#   --host NOME        Nome do PC. Sem esta opção, o script pergunta.
#   --generate-only    Só gera hosts/<NOME>, sem alterar o sistema.

set -euo pipefail

TARGET_DIR=/etc/nixos
MAIN_USER=fabio
POWER_SUPPLY_DIR="${POWER_SUPPLY_DIR:-/sys/class/power_supply}"

repo_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
host=""
generate_only=false

die() {
    printf 'Erro: %s\n' "$1" >&2
    exit 1
}

info() {
    printf '\n==> %s\n' "$1"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --host)
            [[ $# -ge 2 ]] || die "--host precisa de um nome."
            host="$2"
            shift 2
            ;;
        --generate-only)
            generate_only=true
            shift
            ;;
        -h | --help)
            sed -n '2,10p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
            exit 0
            ;;
        *)
            die "opção desconhecida: $1"
            ;;
    esac
done

# Uma instalação nova do NixOS não traz git nem lspci.
if ! command -v git >/dev/null || ! command -v lspci >/dev/null; then
    command -v nix-shell >/dev/null || die "este script precisa ser executado no NixOS."
    args=("$0")
    [[ -n "$host" ]] && args+=(--host "$host")
    [[ "$generate_only" == true ]] && args+=(--generate-only)
    exec nix-shell -p git pciutils --run "$(printf '%q ' "${args[@]}")"
fi

grep -q '^ID=nixos$' /etc/os-release || die "este script precisa ser executado no NixOS."
[[ "$(uname -m)" == "x86_64" ]] || die "só há suporte para x86_64."
[[ -d /sys/firmware/efi ]] || die "só há suporte para boot UEFI; este PC iniciou em modo BIOS."

default_host_name() {
    printf 'pc-%s' "$(head -c 6 /etc/machine-id)"
}

root_uuid_in() {
    grep -A1 'fileSystems."/"' "$1" | grep -oE 'by-uuid/[^"]+' | cut -d/ -f2 || true
}

# Evita aplicar a configuração de outro PC, que deixaria este sem iniciar.
check_existing_host() {
    local hardware_file="$repo_dir/hosts/$host/hardware-configuration.nix"
    local configured current

    configured="$(root_uuid_in "$hardware_file")"
    current="$(findmnt -no UUID /)"

    if [[ -n "$configured" && "$configured" != "$current" ]]; then
        die "hosts/$host pertence a outro PC (disco raiz $configured). Escolha outro nome com --host."
    fi
}

# Converte "01:00.0" (hexadecimal) para "PCI:1:0:0" (decimal).
pci_bus_id() {
    local address="$1" bus device function
    bus="${address%%:*}"
    device="${address#*:}"
    device="${device%%.*}"
    function="${address##*.}"
    printf 'PCI:%d:%d:%d' "$((16#$bus))" "$((16#$device))" "$((16#$function))"
}

is_laptop() {
    compgen -G "$POWER_SUPPLY_DIR/BAT*" >/dev/null
}

# Define as variáveis gpu, nvidia_open e as de PRIME.
detect_gpu() {
    local devices nvidia_line integrated_line

    devices="$(lspci | grep -E 'VGA compatible controller|3D controller|Display controller' || true)"
    nvidia_line="$(grep -i 'nvidia' <<<"$devices" | head -n1 || true)"
    integrated_line="$(grep -iE 'intel|advanced micro devices|\bamd\b|\bati\b' <<<"$devices" | head -n1 || true)"

    gpu=generic
    nvidia_open=true
    prime_nvidia=""
    prime_integrated=""
    prime_vendor=""

    if [[ -n "$nvidia_line" ]]; then
        gpu=nvidia

        # O módulo aberto exige GTX 16xx, RTX ou mais nova.
        if ! grep -qE 'RTX|GTX 16[0-9]{2}|\b(T[0-9]{3,4}|A[0-9]{3,4}|MX[45][0-9]{2})\b' <<<"$nvidia_line"; then
            nvidia_open=false
        fi

        if [[ -n "$integrated_line" ]] && is_laptop; then
            gpu=nvidia-hybrid
            prime_nvidia="$(pci_bus_id "${nvidia_line%% *}")"
            prime_integrated="$(pci_bus_id "${integrated_line%% *}")"
            if grep -qi 'intel' <<<"$integrated_line"; then
                prime_vendor=intel
            else
                prime_vendor=amd
            fi
        fi
    elif grep -qiE 'advanced micro devices|\bamd\b|\bati\b' <<<"$devices"; then
        gpu=amd
    elif grep -qi 'intel' <<<"$devices"; then
        gpu=intel
    fi
}

write_host_config() {
    local dir="$repo_dir/hosts/$host"
    local state_version

    state_version="$(nixos-version | cut -d. -f1,2)"
    mkdir -p "$dir"
    nixos-generate-config --show-hardware-config >"$dir/hardware-configuration.nix"

    {
        printf '# Gerado por install.sh.\n{ ... }:\n\n{\n'
        printf '  imports = [ ./hardware-configuration.nix ];\n\n'
        printf '  machine = {\n    gpu = "%s";\n' "$gpu"
        if [[ "$gpu" == nvidia* && "$nvidia_open" == false ]]; then
            printf '    nvidiaOpen = false;\n'
        fi
        if [[ "$gpu" == nvidia-hybrid ]]; then
            printf '    prime = {\n'
            printf '      nvidiaBusId = "%s";\n' "$prime_nvidia"
            printf '      integratedVendor = "%s";\n' "$prime_vendor"
            printf '      integratedBusId = "%s";\n' "$prime_integrated"
            printf '    };\n'
        fi
        if is_laptop; then
            printf '    laptop = true;\n'
        fi
        printf '  };\n\n'
        printf '  hardware.enableRedistributableFirmware = true;\n\n'
        printf '  system.stateVersion = "%s";\n}\n' "$state_version"
    } >"$dir/default.nix"
}

# ---------------------------------------------------------------------------

if [[ -z "$host" ]]; then
    suggestion="$(default_host_name)"
    read -r -p "Nome deste PC [$suggestion]: " host
    host="${host:-$suggestion}"
fi

[[ "$host" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$ ]] \
    || die "nome inválido: use letras, números e hífen."

if [[ -d "$repo_dir/hosts/$host" ]]; then
    check_existing_host
    info "Usando a configuração existente de hosts/$host"
else
    detect_gpu
    info "Hardware detectado: GPU = $gpu"
    write_host_config
    git -C "$repo_dir" add "hosts/$host"
    info "Configuração criada em hosts/$host"
fi

if [[ "$generate_only" == true ]]; then
    exit 0
fi

if [[ "$repo_dir" != "$TARGET_DIR" ]]; then
    if [[ -e "$TARGET_DIR" ]]; then
        backup="$TARGET_DIR.backup-$(date +%Y%m%d-%H%M%S)"
        info "Guardando o $TARGET_DIR atual em $backup"
        sudo mv "$TARGET_DIR" "$backup"
    fi
    sudo cp -a "$repo_dir" "$TARGET_DIR"
fi

# O usuário precisa existir e ter senha antes do reboot: `nixos-rebuild boot`
# não o cria na hora, e sem senha não daria para entrar na tela de login.
if ! id "$MAIN_USER" >/dev/null 2>&1; then
    info "Criando o usuário $MAIN_USER"
    sudo useradd -m -g users "$MAIN_USER"
fi

if [[ "$(sudo passwd -S "$MAIN_USER" | awk '{print $2}')" != "P" ]]; then
    info "Defina a senha do usuário $MAIN_USER"
    sudo passwd "$MAIN_USER"
fi

info "Montando o sistema (pode demorar na primeira vez)"
sudo env "PATH=$PATH" NIX_CONFIG="experimental-features = nix-command flakes" \
    nixos-rebuild boot --flake "$TARGET_DIR#$host"

# Os temas e configurações são editados pelo usuário em /etc/nixos.
sudo chown -R "$MAIN_USER:users" "$TARGET_DIR"

info "Pronto. Reinicie para entrar no Hyprland."
printf 'Para guardar este PC no repositório:\n'
printf '  cd %s && git commit -m "feat: add host %s" && git push\n' "$TARGET_DIR" "$host"
