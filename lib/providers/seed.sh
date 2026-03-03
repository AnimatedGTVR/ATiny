#!/usr/bin/env bash

seed_root="${XDG_DATA_HOME:-$HOME/.local/share}/tinypm/seed"
seed_packages_dir="$seed_root/packages"
seed_bin_dir="$seed_root/bin"
seed_recipe_file="$script_dir/share/seed.tsv"

seed_recipe_entries() {
    [[ -r "$seed_recipe_file" ]] || return 1
    cat "$seed_recipe_file"
}

seed_has_recipes() {
    [[ -r "$seed_recipe_file" ]] && [[ -s "$seed_recipe_file" ]]
}

seed_ensure_dirs() {
    mkdir -p "$seed_packages_dir" "$seed_bin_dir"
}

seed_package_row() {
    local package="$1"

    seed_recipe_entries | awk -F '\t' -v pkg="$package" '$1 == pkg { print; found=1; exit } END { exit(found ? 0 : 1) }'
}

package_in_seed() {
    [[ -x "$seed_bin_dir/$1" ]]
}

seed_download_cmd() {
    if backend_has_cmd curl; then
        printf '%s\n' curl
    elif backend_has_cmd wget; then
        printf '%s\n' wget
    else
        return 1
    fi
}

seed_download_to() {
    local url="$1"
    local destination="$2"
    local downloader

    downloader="$(seed_download_cmd)" || die "seed requires curl or wget"

    case "$downloader" in
        curl) backend_run curl -L --fail --output "$destination" "$url" ;;
        wget) backend_run wget -O "$destination" "$url" ;;
    esac
}

seed_install() {
    local package="$1"
    local row name package_type url exec_name description package_dir file_path wrapper_path

    row="$(seed_package_row "$package")" || die "seed package not found: $package"
    IFS=$'\t' read -r name package_type url exec_name description <<EOI
$row
EOI

    seed_ensure_dirs
    package_dir="$seed_packages_dir/$name"
    file_path="$package_dir/$exec_name"
    wrapper_path="$seed_bin_dir/$name"

    mkdir -p "$package_dir"

    case "$package_type" in
        binary)
            run_with_spinner "Downloading $name with Seed" seed_download_to "$url" "$file_path"
            chmod +x "$file_path"
            ;;
        *)
            die "unsupported seed package type: $package_type"
            ;;
    esac

    cat >"$wrapper_path" <<EOW
#!/usr/bin/env bash
exec "$file_path" "\$@"
EOW
    chmod +x "$wrapper_path"
}

seed_search() {
    local query="${1:-}"

    printf "%-20s %-10s %-18s %s\n" "PACKAGE" "TYPE" "COMMAND" "DESCRIPTION"
    if [[ -z "$query" ]]; then
        seed_recipe_entries | awk -F '\t' '{ printf "%-20s %-10s %-18s %s\n", $1, $2, $4, $5 }'
        return
    fi

    seed_recipe_entries | awk -F '\t' -v q="$query" '
        BEGIN { q=tolower(q) }
        {
            line=tolower($0)
            if (index(line, q) > 0) {
                printf "%-20s %-10s %-18s %s\n", $1, $2, $4, $5
            }
        }'
}

seed_remove() {
    local package="$1"

    [[ -d "$seed_packages_dir/$package" || -x "$seed_bin_dir/$package" ]] || die "seed package is not installed: $package"
    rm -rf "$seed_packages_dir/$package"
    rm -f "$seed_bin_dir/$package"
}

seed_list() {
    printf "%-20s %-18s %s\n" "PACKAGE" "COMMAND" "LOCATION"
    [[ -d "$seed_bin_dir" ]] || return 0

    find "$seed_bin_dir" -maxdepth 1 -type f -perm -u+x | sort | while IFS= read -r path; do
        package="$(basename "$path")"
        printf "%-20s %-18s %s\n" "$package" "$package" "$path"
    done
}

seed_run() {
    [[ -x "$seed_bin_dir/$1" ]] || die "seed package is not installed: $1"
    backend_exec "$seed_bin_dir/$1"
}

seed_update() {
    local package

    [[ -d "$seed_packages_dir" ]] || {
        echo "No Seed packages are currently installed."
        return
    }

    while IFS= read -r package; do
        [[ -n "$package" ]] || continue
        seed_install "$package"
    done <<EOU
$(find "$seed_packages_dir" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
EOU
}
