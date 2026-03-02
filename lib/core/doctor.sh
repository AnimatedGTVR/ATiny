#!/usr/bin/env bash

doctor() {
    local path_state="missing"
    local gui_state="terminal-only"
    local flatpak_state="missing"
    local snap_state="missing"
    local apt_state="missing"

    case ":${PATH:-}:" in
        *":$script_dir:"*) path_state="present" ;;
    esac

    if [[ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
        gui_state="available"
    fi

    if backend_has_cmd flatpak; then
        flatpak_state="available"
    fi

    if backend_has_cmd snap; then
        snap_state="available"
    fi

    if backend_has_cmd apt-get; then
        apt_state="available"
    fi

    printf 'TinyPM doctor\n'
    printf '%s\n' '------------------------------------------------------------'
    printf '  %-16s %s\n' 'script_dir' "$script_dir"
    printf '  %-16s %s\n' 'path' "$path_state"
    printf '  %-16s %s\n' 'tinypm' "$(command -v tinypm 2>/dev/null || echo missing)"
    printf '  %-16s %s\n' 'atiny' "$(command -v atiny 2>/dev/null || echo missing)"
    printf '  %-16s %s\n' 'ainstall' "$(command -v ainstall 2>/dev/null || echo missing)"
    printf '  %-16s %s\n' 'search' "$(command -v search 2>/dev/null || echo missing)"
    printf '  %-16s %s\n' 'term' "$(command -v term 2>/dev/null || echo missing)"
    printf '  %-16s %s\n' 'start' "$(command -v start 2>/dev/null || echo missing)"
    printf '  %-16s %s\n' 'supdate' "$(command -v supdate 2>/dev/null || echo missing)"
    printf '  %-16s %s\n' 'tinypm-app' "$(command -v tinypm-app 2>/dev/null || echo missing)"
    printf '  %-16s %s\n' 'backend_mode' "$([[ "$use_host_backend" -eq 1 ]] && echo host || echo local)"
    printf '  %-16s %s\n' 'auth_mode' "$(backend_auth_mode)"
    printf '  %-16s %s\n' 'state_db' "$(active_state_db)"
    printf '  %-16s %s\n' 'gui' "$gui_state"
    printf '  %-16s %s\n' 'flatpak' "$flatpak_state"
    printf '  %-16s %s\n' 'snap' "$snap_state"
    printf '  %-16s %s\n' 'apt' "$apt_state"
}
