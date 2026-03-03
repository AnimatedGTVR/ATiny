#!/usr/bin/env bash

native_pm_resolve() {
    local requested="${1:-native}"

    if [[ "$requested" == "native" || "$requested" == "apt" ]]; then
        detect_native_pm
        return
    fi

    if is_native_provider "$requested"; then
        printf '%s\n' "$requested"
        return
    fi

    die "unknown native package manager: $requested"
}

package_in_apt() {
    local package="$1"
    local pm

    pm="$(native_pm_resolve "${2:-native}")" || return 1

    case "$pm" in
        apt) backend_run dpkg -s "$package" >/dev/null 2>&1 ;;
        dnf) backend_run rpm -q "$package" >/dev/null 2>&1 ;;
        pacman) backend_run pacman -Q "$package" >/dev/null 2>&1 ;;
        xbps) backend_run xbps-query -Rs "^$package$" >/dev/null 2>&1 ;;
        zypper) backend_run rpm -q "$package" >/dev/null 2>&1 ;;
        apk) backend_run apk info -e "$package" >/dev/null 2>&1 ;;
        emerge)
            if backend_has_cmd qlist; then
                backend_run qlist -I "$package" >/dev/null 2>&1
            else
                backend_run sh -lc 'ls /var/db/pkg/* 2>/dev/null | grep -F "/$1-" >/dev/null 2>&1' sh "$package"
            fi
            ;;
    esac
}

apt_install() {
    local package="$1"
    local pm

    pm="$(native_pm_resolve "${2:-native}")"

    case "$pm" in
        apt) run_with_spinner "Installing $package with APT" backend_run_root apt-get install -y "$package" ;;
        dnf) run_with_spinner "Installing $package with DNF" backend_run_root dnf install -y "$package" ;;
        pacman) run_with_spinner "Installing $package with Pacman" backend_run_root pacman -S --noconfirm "$package" ;;
        xbps) run_with_spinner "Installing $package with XBPS" backend_run_root xbps-install -Sy "$package" ;;
        zypper) run_with_spinner "Installing $package with Zypper" backend_run_root zypper --non-interactive install "$package" ;;
        apk) run_with_spinner "Installing $package with APK" backend_run_root apk add "$package" ;;
        emerge) run_with_spinner "Installing $package with Portage" backend_run_root emerge --ask=n "$package" ;;
    esac
}

apt_search() {
    local query="$1"
    local pm

    pm="$(native_pm_resolve "${2:-native}")"

    case "$pm" in
        apt) backend_run apt-cache search "$query" ;;
        dnf) backend_run dnf search "$query" ;;
        pacman) backend_run pacman -Ss "$query" ;;
        xbps) backend_run xbps-query -Rs "$query" ;;
        zypper) backend_run zypper search "$query" ;;
        apk) backend_run apk search "$query" ;;
        emerge) backend_run emerge --search "$query" ;;
    esac
}

apt_remove() {
    local package="$1"
    local pm

    pm="$(native_pm_resolve "${2:-native}")"

    case "$pm" in
        apt) run_with_spinner "Removing $package from APT" backend_run_root apt-get remove -y "$package" ;;
        dnf) run_with_spinner "Removing $package from DNF" backend_run_root dnf remove -y "$package" ;;
        pacman) run_with_spinner "Removing $package from Pacman" backend_run_root pacman -Rns --noconfirm "$package" ;;
        xbps) run_with_spinner "Removing $package from XBPS" backend_run_root xbps-remove -Ry "$package" ;;
        zypper) run_with_spinner "Removing $package from Zypper" backend_run_root zypper --non-interactive remove "$package" ;;
        apk) run_with_spinner "Removing $package from APK" backend_run_root apk del "$package" ;;
        emerge) run_with_spinner "Removing $package from Portage" backend_run_root emerge --ask=n --depclean "$package" ;;
    esac
}

apt_list() {
    local pm

    pm="$(native_pm_resolve "${1:-native}")"

    case "$pm" in
        apt) backend_run dpkg-query -W ;;
        dnf) backend_run dnf list installed ;;
        pacman) backend_run pacman -Q ;;
        xbps) backend_run xbps-query -l ;;
        zypper) backend_run zypper search --installed-only ;;
        apk) backend_run apk info ;;
        emerge)
            if backend_has_cmd qlist; then
                backend_run qlist -I
            else
                backend_run sh -lc 'find /var/db/pkg -mindepth 2 -maxdepth 2 -type d -printf "%f\n" 2>/dev/null | sort'
            fi
            ;;
    esac
}

apt_update() {
    local pm

    pm="$(native_pm_resolve "${1:-native}")"

    case "$pm" in
        apt)
            run_with_spinner "Updating APT package lists" backend_run_root apt-get update
            run_with_spinner "Upgrading APT packages" backend_run_root apt-get upgrade -y
            ;;
        dnf)
            run_with_spinner "Upgrading DNF packages" backend_run_root dnf upgrade -y
            ;;
        pacman)
            run_with_spinner "Upgrading Pacman packages" backend_run_root pacman -Syu --noconfirm
            ;;
        xbps)
            run_with_spinner "Upgrading XBPS packages" backend_run_root xbps-install -Syu
            ;;
        zypper)
            run_with_spinner "Refreshing Zypper metadata" backend_run_root zypper --non-interactive refresh
            run_with_spinner "Upgrading Zypper packages" backend_run_root zypper --non-interactive update
            ;;
        apk)
            run_with_spinner "Refreshing APK indexes" backend_run_root apk update
            run_with_spinner "Upgrading APK packages" backend_run_root apk upgrade
            ;;
        emerge)
            run_with_spinner "Syncing Portage" backend_run_root emerge --sync
            run_with_spinner "Upgrading Portage world set" backend_run_root emerge -uDN --with-bdeps=y @world
            ;;
    esac
}
