#!/usr/bin/env bash

package_in_apt() {
    backend_run dpkg -s "$1" >/dev/null 2>&1
}

apt_install() {
    run_with_spinner "Installing $1 with APT" backend_run_root apt-get install -y "$1"
}

apt_search() {
    backend_run apt-cache search "$1"
}

apt_remove() {
    run_with_spinner "Removing $1 from APT" backend_run_root apt-get remove -y "$1"
}

apt_list() {
    backend_run dpkg-query -W
}

apt_update() {
    run_with_spinner "Updating APT package lists" backend_run_root apt-get update
    run_with_spinner "Upgrading APT packages" backend_run_root apt-get upgrade -y
}
