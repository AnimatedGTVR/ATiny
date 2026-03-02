#!/usr/bin/env bash

spinner="$script_dir/_spinner"
version_cmd="$script_dir/version"
use_host_backend=0

if [[ "${container:-}" == "flatpak" ]] && command -v flatpak-spawn >/dev/null 2>&1; then
    use_host_backend=1
fi

die() {
    echo "tinypm: $*" >&2
    exit 1
}

has_cmd() {
    command -v "$1" >/dev/null 2>&1
}

backend_run() {
    if [[ "$use_host_backend" -eq 1 ]]; then
        flatpak-spawn --host "$@"
        return
    fi

    "$@"
}

backend_exec() {
    if [[ "$use_host_backend" -eq 1 ]]; then
        exec flatpak-spawn --host "$@"
    fi

    exec "$@"
}

host_run() {
    if [[ "$use_host_backend" -eq 1 ]]; then
        flatpak-spawn --host "$@"
        return
    fi

    "$@"
}

host_has_cmd() {
    local cmd="$1"

    if [[ "$use_host_backend" -eq 1 ]]; then
        flatpak-spawn --host sh -lc 'command -v "$1" >/dev/null 2>&1' sh "$cmd" 2>/dev/null
        return
    fi

    command -v "$cmd" >/dev/null 2>&1
}

graphical_session_available() {
    [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]
}

backend_run_root() {
    if [[ "$use_host_backend" -eq 1 ]]; then
        if graphical_session_available && host_has_cmd pkexec; then
            flatpak-spawn --host env \
                DISPLAY="${DISPLAY:-}" \
                WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
                XAUTHORITY="${XAUTHORITY:-}" \
                DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-}" \
                XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" \
                pkexec "$@"
            return
        fi

        if host_has_cmd sudo; then
            flatpak-spawn --host sudo "$@"
            return
        fi

        flatpak-spawn --host "$@"
        return
    fi

    if graphical_session_available && has_cmd pkexec; then
        env \
            DISPLAY="${DISPLAY:-}" \
            WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-}" \
            XAUTHORITY="${XAUTHORITY:-}" \
            DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-}" \
            XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-}" \
            pkexec "$@"
        return
    fi

    if has_cmd sudo; then
        sudo "$@"
        return
    fi

    "$@"
}

backend_auth_mode() {
    if [[ "$use_host_backend" -eq 1 ]]; then
        if graphical_session_available && host_has_cmd pkexec; then
            printf '%s\n' 'pkexec'
            return
        fi
        if host_has_cmd sudo; then
            printf '%s\n' 'sudo'
            return
        fi
        printf '%s\n' 'direct'
        return
    fi

    if graphical_session_available && has_cmd pkexec; then
        printf '%s\n' 'pkexec'
    elif has_cmd sudo; then
        printf '%s\n' 'sudo'
    else
        printf '%s\n' 'direct'
    fi
}

backend_has_cmd() {
    local cmd="$1"

    if [[ "$use_host_backend" -eq 1 ]]; then
        flatpak-spawn --host sh -lc 'command -v "$1" >/dev/null 2>&1' sh "$cmd" 2>/dev/null
        return
    fi

    command -v "$cmd" >/dev/null 2>&1
}

backend_os_name() {
    if [[ "$use_host_backend" -eq 1 ]]; then
        flatpak-spawn --host sh -lc '
            if command -v lsb_release >/dev/null 2>&1; then
                lsb_release -d | cut -f2
            elif [ -r /etc/os-release ]; then
                . /etc/os-release
                printf "%s\n" "${PRETTY_NAME:-$NAME}"
            else
                uname -s
            fi
        '
        return
    fi

    if command -v lsb_release >/dev/null 2>&1; then
        lsb_release -d | cut -f2
    elif [[ -r /etc/os-release ]]; then
        . /etc/os-release
        printf "%s\n" "${PRETTY_NAME:-$NAME}"
    else
        uname -s
    fi
}

normalize_provider() {
    case "${1:-auto}" in
        flatpack) echo "flatpak" ;;
        *) echo "${1:-auto}" ;;
    esac
}

provider_from_flag() {
    case "${1:-}" in
        -f|--flat|--flatpak) echo "flatpak" ;;
        -s|--snp|--snap) echo "snap" ;;
        -n|--nat|--native|--apt) echo "apt" ;;
        auto|flatpak|snap|apt|flatpack) normalize_provider "$1" ;;
        *) return 1 ;;
    esac
}

ensure_provider_available() {
    case "$(normalize_provider "$1")" in
        flatpak) backend_has_cmd flatpak || die "flatpak is not installed" ;;
        snap) backend_has_cmd snap || die "snap is not installed" ;;
        apt) backend_has_cmd apt-get || die "apt-get is not installed" ;;
        auto)
            backend_has_cmd flatpak || backend_has_cmd snap || backend_has_cmd apt-get || die "flatpak, snap, and apt-get are all unavailable"
            ;;
        *) die "unknown provider: $1" ;;
    esac
}

pick_install_provider() {
    local requested
    requested="$(normalize_provider "${1:-auto}")"

    case "$requested" in
        flatpak|snap|apt)
            ensure_provider_available "$requested"
            echo "$requested"
            ;;
        auto)
            if backend_has_cmd flatpak; then
                echo "flatpak"
            elif backend_has_cmd snap; then
                echo "snap"
            elif backend_has_cmd apt-get; then
                echo "apt"
            else
                die "flatpak, snap, and apt-get are all unavailable"
            fi
            ;;
        *)
            die "unknown provider: $requested"
            ;;
    esac
}

pick_installed_provider() {
    local package="$1"
    local requested
    requested="$(normalize_provider "${2:-auto}")"

    case "$requested" in
        flatpak|snap|apt)
            ensure_provider_available "$requested"
            echo "$requested"
            ;;
        auto)
            if backend_has_cmd flatpak && package_in_flatpak "$package"; then
                echo "flatpak"
            elif backend_has_cmd snap && package_in_snap "$package"; then
                echo "snap"
            elif backend_has_cmd apt-get && package_in_apt "$package"; then
                echo "apt"
            elif backend_has_cmd flatpak; then
                echo "flatpak"
            elif backend_has_cmd snap; then
                echo "snap"
            elif backend_has_cmd apt-get; then
                echo "apt"
            else
                die "flatpak, snap, and apt-get are all unavailable"
            fi
            ;;
        *)
            die "unknown provider: $requested"
            ;;
    esac
}

pick_runner_provider() {
    local package="$1"
    local requested
    requested="$(normalize_provider "${2:-auto}")"

    case "$requested" in
        flatpak|snap)
            ensure_provider_available "$requested"
            echo "$requested"
            ;;
        apt)
            die "run is not supported for apt packages"
            ;;
        auto)
            if backend_has_cmd flatpak && package_in_flatpak "$package"; then
                echo "flatpak"
            elif backend_has_cmd snap && package_in_snap "$package"; then
                echo "snap"
            else
                die "run only works for installed flatpak or snap apps"
            fi
            ;;
        *)
            die "unknown provider: $requested"
            ;;
    esac
}
