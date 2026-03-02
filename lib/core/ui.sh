#!/usr/bin/env bash

usage() {
    cat <<'EOF'
TinyPM: a tiny package manager for Flatpak, Snap, and APT

Usage:
  tinypm install [-f|-s|-n] <package>
  tinypm search [-f|-s|-n] <query>
  tinypm remove [-f|-s|-n] <package>
  tinypm list [-f|-s|-n]
  tinypm run [-f|-s] <app>
  tinypm start [-f|-s] <app>
  tinypm update [-f|-s|-n]
  tinypm info <package>
  tinypm managed
  tinypm apps
  tinypm discover [query]
  tinypm doctor
  tinypm version
  tinypm app
  tinypm-app

Shortcuts:
  ainstall [-f|-s|-n] <package>
  search   [-f|-s|-n] <query>
  term     [-f|-s|-n] <package>
  start    [-f|-s] <app>
  supdate  [-f|-s|-n]

Compatibility:
  atiny <same commands as tinypm>

Flags:
  -f, --flat, --flatpak  use Flatpak
  -s, --snp, --snap      use Snap
  -n, --nat, --native    use native APT

Notes:
  `discover` is a small built-in starter catalog, not every package available
  from Flatpak, Snap, or APT.
EOF
}

run_with_spinner() {
    local message="$1"
    shift

    if [[ $# -gt 0 ]] && declare -F "$1" >/dev/null 2>&1; then
        local func_name="$1"
        shift

        export use_host_backend
        export -f die
        export -f has_cmd
        export -f backend_run
        export -f backend_exec
        export -f host_run
        export -f host_has_cmd
        export -f backend_has_cmd
        export -f graphical_session_available
        export -f backend_run_root
        export -f backend_auth_mode
        export -f "$func_name"

        "$spinner" "$message" -- bash -lc 'func_name="$1"; shift; "$func_name" "$@"' bash "$func_name" "$@"
        return
    fi

    "$spinner" "$message" -- "$@"
}
