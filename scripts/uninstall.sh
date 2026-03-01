#!/usr/bin/env bash
set -euo pipefail

ATINY_PREFIX="${ATINY_PREFIX:-$HOME/.atiny}"
BIN_DIR="$ATINY_PREFIX/bin"
LOG_DIR="$ATINY_PREFIX/logs"

echo "[ATiny] Removing runtime from $ATINY_PREFIX ..."

# Remove all symlinks and core script
for c in ainstall finstall sinstall term fterm sterm search fsearch ssearch supdate list run start helptiny mantiny atiny; do
    if [ -e "$BIN_DIR/$c" ]; then
        rm -f "$BIN_DIR/$c"
    fi
done

# Remove logs folder
rm -rf "$LOG_DIR"

# Optional: remove bin folder if empty
rmdir "$BIN_DIR" 2>/dev/null || true

# Remove PATH from rc files safely
SHELL_RC="$HOME/.bashrc"
if [ -n "$ZSH_VERSION" ]; then
    SHELL_RC="$HOME/.zshrc"
fi

# Remove any lines containing ~/.atiny/bin
if grep -q "$BIN_DIR" "$SHELL_RC" 2>/dev/null; then
    sed -i "\|$BIN_DIR|d" "$SHELL_RC"
    echo "[ATiny] Removed $BIN_DIR from PATH in $SHELL_RC."
fi

echo "[ATiny] Uninstallation complete!"
