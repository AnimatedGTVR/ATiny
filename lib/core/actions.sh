#!/usr/bin/env bash

install_pkg() {
    local package="$1"
    local provider
    provider="$(pick_install_provider "${2:-auto}")"

    case "$provider" in
        flatpak) install_flatpak "$package" ;;
        snap) snap_install "$package" ;;
        apt) apt_install "$package" ;;
    esac

    record_tracked_package "$package" "$provider"
}

search_pkg() {
    local query="$1"
    local provider
    provider="$(normalize_provider "${2:-auto}")"

    case "$provider" in
        flatpak)
            ensure_provider_available flatpak
            flatpak_search "$query"
            ;;
        snap)
            ensure_provider_available snap
            snap_search "$query"
            ;;
        apt)
            ensure_provider_available apt
            apt_search "$query"
            ;;
        auto)
            ensure_provider_available auto
            if backend_has_cmd flatpak; then
                echo "== Flatpak =="
                flatpak_search "$query"
            fi
            if backend_has_cmd snap; then
                if backend_has_cmd flatpak; then
                    echo
                fi
                echo "== Snap =="
                snap_search "$query"
            fi
            if backend_has_cmd apt-cache; then
                if backend_has_cmd flatpak || backend_has_cmd snap; then
                    echo
                fi
                echo "== APT =="
                apt_search "$query"
            fi
            ;;
        *)
            die "unknown provider: $provider"
            ;;
    esac
}

remove_pkg() {
    local package="$1"
    local provider

    if [[ "$(normalize_provider "${2:-auto}")" == "auto" ]] && provider="$(tracked_provider_for "$package" 2>/dev/null)"; then
        :
    else
        provider="$(pick_installed_provider "$package" "${2:-auto}")"
    fi

    case "$provider" in
        flatpak) flatpak_remove "$package" ;;
        snap) snap_remove "$package" ;;
        apt) apt_remove "$package" ;;
    esac

    forget_tracked_package "$package"
}

list_pkgs() {
    local provider
    provider="$(normalize_provider "${1:-auto}")"

    case "$provider" in
        flatpak)
            ensure_provider_available flatpak
            flatpak_list
            ;;
        snap)
            ensure_provider_available snap
            snap_list
            ;;
        apt)
            ensure_provider_available apt
            apt_list
            ;;
        auto)
            ensure_provider_available auto
            if backend_has_cmd flatpak; then
                echo "== Flatpak =="
                flatpak_list
            fi
            if backend_has_cmd snap; then
                if backend_has_cmd flatpak; then
                    echo
                fi
                echo "== Snap =="
                snap_list
            fi
            if backend_has_cmd apt-get; then
                if backend_has_cmd flatpak || backend_has_cmd snap; then
                    echo
                fi
                echo "== APT =="
                apt_list
            fi
            ;;
        *)
            die "unknown provider: $provider"
            ;;
    esac
}

run_pkg() {
    local package="$1"
    local provider

    if [[ "$(normalize_provider "${2:-auto}")" == "auto" ]] && provider="$(tracked_provider_for "$package" 2>/dev/null)"; then
        :
    else
        provider="$(pick_runner_provider "$package" "${2:-auto}")"
    fi

    case "$provider" in
        flatpak) flatpak_run "$package" ;;
        snap) snap_run "$package" ;;
    esac
}

update_pkgs() {
    local provider
    provider="$(normalize_provider "${1:-auto}")"

    case "$provider" in
        flatpak)
            ensure_provider_available flatpak
            flatpak_update
            ;;
        snap)
            ensure_provider_available snap
            snap_update
            ;;
        apt)
            ensure_provider_available apt
            apt_update
            ;;
        auto)
            ensure_provider_available auto
            if backend_has_cmd flatpak; then
                flatpak_update
            fi
            if backend_has_cmd snap; then
                snap_update
            fi
            if backend_has_cmd apt-get; then
                apt_update
            fi
            ;;
        *)
            die "unknown provider: $provider"
            ;;
    esac
}

managed_pkgs() {
    print_tracked_packages
}

info_pkg() {
    local package="$1"
    local tracked_provider="untracked"
    local tracked_added="unknown"
    local available_providers=""

    if tracked_provider="$(tracked_provider_for "$package" 2>/dev/null)"; then
        tracked_added="$(tracked_timestamp_for "$package" 2>/dev/null || echo unknown)"
    else
        tracked_provider="untracked"
    fi

    if backend_has_cmd flatpak && package_in_flatpak "$package"; then
        available_providers="${available_providers} flatpak"
    fi
    if backend_has_cmd snap && package_in_snap "$package"; then
        available_providers="${available_providers} snap"
    fi
    if backend_has_cmd apt-get && package_in_apt "$package"; then
        available_providers="${available_providers} apt"
    fi

    echo "Package: $package"
        echo "Tracked by TinyPM: $tracked_provider"
    if [[ "$tracked_provider" != "untracked" ]]; then
        echo "Tracked since: $tracked_added"
    fi
    if [[ -n "$available_providers" ]]; then
        echo "Installed via:${available_providers}"
    else
        echo "Installed via: not detected"
    fi
}
