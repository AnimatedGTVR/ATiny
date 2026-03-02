#!/usr/bin/env bash

state_home="${XDG_STATE_HOME:-$HOME/.local/state}"
state_root="$state_home/tinypm"
legacy_state_root="$state_home/atiny"
state_db="$state_root/packages.tsv"
legacy_state_db="$legacy_state_root/packages.tsv"

ensure_state_dir() {
    mkdir -p "$state_root"
}

state_db_exists() {
    [[ -f "$state_db" || -f "$legacy_state_db" ]]
}

active_state_db() {
    if [[ -f "$state_db" ]]; then
        printf '%s\n' "$state_db"
    elif [[ -f "$legacy_state_db" ]]; then
        printf '%s\n' "$legacy_state_db"
    else
        printf '%s\n' "$state_db"
    fi
}

tracked_provider_for() {
    local package="$1"
    local db_file

    state_db_exists || return 1
    db_file="$(active_state_db)"
    awk -F '\t' -v pkg="$package" '$1 == pkg { print $2; found=1 } END { exit(found ? 0 : 1) }' "$db_file"
}

tracked_timestamp_for() {
    local package="$1"
    local db_file

    state_db_exists || return 1
    db_file="$(active_state_db)"
    awk -F '\t' -v pkg="$package" '$1 == pkg { print $3; found=1 } END { exit(found ? 0 : 1) }' "$db_file"
}

record_tracked_package() {
    local package="$1"
    local provider="$2"
    local added_at
    local tmp_file
    local db_file

    ensure_state_dir
    added_at="$(date -Iseconds)"
    tmp_file="$(mktemp)"
    db_file="$(active_state_db)"

    if [[ -f "$db_file" ]]; then
        awk -F '\t' -v pkg="$package" '$1 != pkg' "$db_file" >"$tmp_file"
    fi

    printf '%s\t%s\t%s\n' "$package" "$provider" "$added_at" >>"$tmp_file"
    mv "$tmp_file" "$state_db"
}

forget_tracked_package() {
    local package="$1"
    local tmp_file
    local db_file

    state_db_exists || return 0
    tmp_file="$(mktemp)"
    db_file="$(active_state_db)"
    awk -F '\t' -v pkg="$package" '$1 != pkg' "$db_file" >"$tmp_file"
    mv "$tmp_file" "$state_db"
}

print_tracked_packages() {
    local db_file

    if ! state_db_exists; then
        echo "No packages are currently tracked by TinyPM."
        return
    fi

    db_file="$(active_state_db)"
    awk -F '\t' 'BEGIN { printf "%-40s %-10s %s\n", "PACKAGE", "PROVIDER", "ADDED" } { printf "%-40s %-10s %s\n", $1, $2, $3 }' "$db_file"
}

tracked_package_count() {
    local db_file

    state_db_exists || {
        printf '%s\n' "0"
        return
    }

    db_file="$(active_state_db)"
    awk 'END { print NR+0 }' "$db_file"
}
