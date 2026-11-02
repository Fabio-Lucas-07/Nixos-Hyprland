#!/usr/bin/env bash
# Confere a economia de energia de um notebook híbrido.
#
#   ./power-check.sh            Mostra o estado atual, sem acordar a NVIDIA.
#   ./power-check.sh --resume   Compara estado e desempenho antes e depois de
#                               suspender por 30 s. Rode em um terminal comum,
#                               de preferência na tomada (o terminal do VSCodium
#                               bloqueia o sudo).

set -uo pipefail

read_file() {
    cat "$1" 2>/dev/null || printf -- '-'
}

nvidia_device() {
    local device
    for device in /sys/bus/pci/devices/*; do
        if [[ "$(read_file "$device/vendor")" == 0x10de && "$(read_file "$device/class")" == 0x03* ]]; then
            printf '%s' "$device"
            return
        fi
    done
}

# Estado que pode mudar em uma retomada.
power_state() {
    local rapl=/sys/class/powercap/intel-rapl:0 cpu=/sys/devices/system/cpu
    printf 'tomada            %s\n' "$(read_file /sys/class/power_supply/AC/online)"
    printf 'perfil firmware   %s\n' "$(read_file /sys/firmware/acpi/platform_profile)"
    printf 'perfil ppd        %s\n' "$(powerprofilesctl get 2>/dev/null)"
    printf 'epp               %s\n' "$(sort -u "$cpu"/cpu*/cpufreq/energy_performance_preference | tr '\n' ' ')"
    printf 'freq máxima       %s\n' "$(sort -u "$cpu"/cpu*/cpufreq/scaling_max_freq | tr '\n' ' ')"
    printf 'no_turbo          %s\n' "$(read_file "$cpu/intel_pstate/no_turbo")"
    printf 'max_perf_pct      %s\n' "$(read_file "$cpu/intel_pstate/max_perf_pct")"
    printf 'PL1 / PL2 (uW)    %s / %s\n' "$(read_file "$rapl/constraint_0_power_limit_uw")" "$(read_file "$rapl/constraint_1_power_limit_uw")"
    printf 'clocksource       %s\n' "$(read_file "$cpu/../clocksource/clocksource0/current_clocksource")"
    printf 'dGPU              %s\n' "$(dgpu_state)"
}

dgpu_state() {
    local device
    device="$(nvidia_device)"
    [[ -n "$device" ]] || { printf 'não encontrada'; return; }
    printf '%s %s' "$(read_file "$device/power/runtime_status")" "$(read_file "$device/power_state")"
}

# Tempo em ms para gerar o hash de 1,2 GB, em uma thread e em todas.
benchmark() {
    local start end i
    hash_once() { dd if=/dev/zero bs=1M count=1200 2>/dev/null | sha256sum >/dev/null; }

    start=$(date +%s%N)
    hash_once
    end=$(date +%s%N)
    printf 'uma thread        %d ms\n' "$(((end - start) / 1000000))"

    start=$(date +%s%N)
    for ((i = 0; i < $(nproc); i++)); do hash_once & done
    wait
    end=$(date +%s%N)
    printf 'todas as threads  %d ms\n' "$(((end - start) / 1000000))"
}

# Acorda a NVIDIA por alguns segundos, por isso só roda em --resume.
gpu_power_limit() {
    nvidia-smi --query-gpu=power.limit --format=csv,noheader 2>/dev/null | sed 's/^/limite dGPU       /'
}

show_setup() {
    local device
    device="$(nvidia_device)"

    printf '== Estado atual\n'
    power_state
    printf 'igpu              %s\n' "$(readlink -e /dev/dri/igpu || printf 'sem /dev/dri/igpu')"
    printf 'AQ_DRM_DEVICES    %s\n' "${AQ_DRM_DEVICES:-não definido}"
    if [[ -n "$device" ]]; then
        printf 'dGPU ativa/susp.  %s ms / %s ms\n' "$(read_file "$device/power/runtime_active_time")" "$(read_file "$device/power/runtime_suspended_time")"
    fi
    grep -hE 'Video Memory:|Status:' /proc/driver/nvidia/gpus/*/power 2>/dev/null | sed 's/  */ /g; s/^ */driver            /'

    printf '\n== Swap e hibernação\n'
    swapon --show=NAME,TYPE,SIZE,PRIO --noheadings
    printf 'modos de energia  %s\n' "$(read_file /sys/power/state)"
    printf 'pode hibernar     %s\n' "$(busctl call org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager CanHibernate 2>/dev/null)"

    printf '\n== Processos com a NVIDIA aberta\n'
    if command -v fuser >/dev/null; then
        fuser -v /dev/nvidia0 /dev/dri/dgpu 2>&1 | tail -n +2
    fi
}

resume_test() {
    printf '== Antes\n'
    power_state
    gpu_power_limit
    benchmark
    sleep 20

    printf '\n== Suspendendo por 30 s\n'
    sudo rtcwake -m no -s 30 >/dev/null || exit 1
    systemctl suspend || exit 1
    sleep 15

    printf '\n== Depois\n'
    power_state
    gpu_power_limit
    benchmark
    sleep 20
    printf '\n== Depois de 20 s ocioso\n'
    printf 'dGPU              %s\n' "$(dgpu_state)"
    journalctl -b -k --no-pager --since "-3min" 2>/dev/null | grep -E 'PM: suspend|NVRM|failed' || true
}

case "${1:-}" in
    --resume) resume_test ;;
    "") show_setup ;;
    *) sed -n '2,8p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
