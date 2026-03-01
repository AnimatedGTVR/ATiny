 #!/usr/bin/env bash
set -euo pipefail

# ATiny One-Liner Installer v1

ATINY_PREFIX="${ATINY_PREFIX:-$HOME/.atiny}"
BIN_DIR="$ATINY_PREFIX/bin"
LOG_DIR="$ATINY_PREFIX/logs"

echo "[ATiny] Installing to $ATINY_PREFIX ..."

mkdir -p "$BIN_DIR" "$LOG_DIR"

# Clone or update repo
if [ -d "$ATINY_PREFIX/repo" ]; then
    echo "[ATiny] Repo exists, updating..."
    cd "$ATINY_PREFIX/repo"
    git pull --rebase origin main || true
else
    git clone https://github.com/AnimatedGTVR/ATiny.git "$ATINY_PREFIX/repo"
    cd "$ATINY_PREFIX/repo"
fi

# Copy core script
cp -f src/atiny "$BIN_DIR/atiny"
chmod +x "$BIN_DIR/atiny"

# Create symlinks
for c in ainstall finstall sinstall term fterm sterm search fsearch ssearch supdate list run start helptiny mantiny; do
    ln -sf "$BIN_DIR/atiny" "$BIN_DIR/$c"
done

# Add PATH to shell rc safely
SHELL_RC="$HOME/.bashrc"
if [ -n "$ZSH_VERSION" ]; then SHELL_RC="$HOME/.zshrc"; fi

if ! grep -q "$BIN_DIR" "$SHELL_RC" 2>/dev/null; then
    echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$SHELL_RC"
    echo "[ATiny] Added $BIN_DIR to PATH in $SHELL_RC."
    echo "[ATiny] Restart terminal or run: source $SHELL_RC"
fi

echo "[ATiny] ATiny v1 installed successfully! Test with: atiny --version"
