#!/bin/bash
#
# Piper TTS Setup — Natural text-to-speech for Linux
#
# Installs:
#   - Piper TTS server (Flask + neural voice model)
#   - speak command (~/bin/speak) with espeak-ng fallback under high CPU load
#   - read-clipboard.sh (~/bin/read-clipboard.sh) for reading highlighted text aloud
#   - systemd user service with CPU quota (1 core max)
#   - Optional: GNOME Ctrl+1 keybinding and Claude Code agent
#
# Supports: Wayland (primary) and X11 (fallback)
# Tested on: Ubuntu 22.04+, Debian 12+
#

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.local/share/piper-tts"
BIN_DIR="$HOME/bin"
VOICE_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx"
VOICE_JSON_URL="https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/lessac/medium/en_US-lessac-medium.onnx.json"
VOICE_NAME="en_US-lessac-medium"

# ── Colors ──
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

ok()   { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
fail() { echo -e "${RED}✗${NC} $1"; }

# ── Step 1: System dependencies ──
echo ""
echo "═══════════════════════════════════════════════"
echo "  Step 1: Install system dependencies"
echo "═══════════════════════════════════════════════"
echo ""
echo "Will install: python3-venv espeak-ng alsa-utils curl"
echo "  Wayland: wl-clipboard"
echo "  X11 fallback: xclip"
echo ""
read -p "Install system packages? [Y/n] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    sudo apt update -qq
    sudo apt install -y python3-venv espeak-ng alsa-utils curl wl-clipboard xclip libnotify-bin
    ok "System packages installed"
else
    warn "Skipped — make sure dependencies are installed"
fi

# ── Step 2: Python venv + piper ──
echo ""
echo "═══════════════════════════════════════════════"
echo "  Step 2: Set up Python venv and Piper TTS"
echo "═══════════════════════════════════════════════"
echo ""
echo "Will create venv at: $INSTALL_DIR/venv"
echo "Will install: piper-tts, flask, pathvalidate"
echo ""
read -p "Continue? [Y/n] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    mkdir -p "$INSTALL_DIR/voices"
    python3 -m venv "$INSTALL_DIR/venv"
    "$INSTALL_DIR/venv/bin/pip" install --quiet --upgrade pip
    "$INSTALL_DIR/venv/bin/pip" install --quiet piper-tts flask pathvalidate
    ok "Python venv created and packages installed"
else
    warn "Skipped"
fi

# ── Step 3: Download voice model ──
echo ""
echo "═══════════════════════════════════════════════"
echo "  Step 3: Download voice model (~61MB)"
echo "═══════════════════════════════════════════════"
echo ""
echo "Voice: $VOICE_NAME (natural US English)"
echo "Destination: $INSTALL_DIR/voices/"
echo ""
if [ -f "$INSTALL_DIR/voices/${VOICE_NAME}.onnx" ]; then
    ok "Voice model already downloaded — skipping"
else
    read -p "Download voice model? [Y/n] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo "Downloading model..."
        wget -q --show-progress -O "$INSTALL_DIR/voices/${VOICE_NAME}.onnx" "$VOICE_URL"
        wget -q --show-progress -O "$INSTALL_DIR/voices/${VOICE_NAME}.onnx.json" "$VOICE_JSON_URL"
        ok "Voice model downloaded"
    else
        warn "Skipped — server won't work without a voice model"
    fi
fi

# ── Step 4: Install server ──
echo ""
echo "═══════════════════════════════════════════════"
echo "  Step 4: Install TTS server"
echo "═══════════════════════════════════════════════"
echo ""
echo "Will copy server.py to: $INSTALL_DIR/"
echo ""
cp "$SCRIPT_DIR/server.py" "$INSTALL_DIR/server.py"
ok "Server installed at $INSTALL_DIR/server.py"

# ── Step 5: Install scripts ──
echo ""
echo "═══════════════════════════════════════════════"
echo "  Step 5: Install speak and read-clipboard scripts"
echo "═══════════════════════════════════════════════"
echo ""
echo "Will install to: $BIN_DIR/"
echo ""
mkdir -p "$BIN_DIR"
cp "$SCRIPT_DIR/bin/speak" "$BIN_DIR/speak"
cp "$SCRIPT_DIR/bin/read-clipboard.sh" "$BIN_DIR/read-clipboard.sh"
chmod +x "$BIN_DIR/speak" "$BIN_DIR/read-clipboard.sh"

# Update read-clipboard.sh to use the installed speak path
sed -i "s|SPEAK_CMD=.*|SPEAK_CMD=\"$BIN_DIR/speak\"|" "$BIN_DIR/read-clipboard.sh"

ok "Scripts installed to $BIN_DIR/"

# Make sure ~/bin is in PATH
if ! echo "$PATH" | grep -q "$BIN_DIR"; then
    warn "$BIN_DIR is not in your PATH"
    echo "  Add this to your ~/.bashrc or ~/.zshrc:"
    echo "    export PATH=\"\$HOME/bin:\$PATH\""
fi

# ── Step 6: Install systemd service ──
echo ""
echo "═══════════════════════════════════════════════"
echo "  Step 6: Install systemd user service"
echo "═══════════════════════════════════════════════"
echo ""
echo "Will create: ~/.config/systemd/user/piper-tts.service"
echo "  - Auto-starts on login"
echo "  - CPU limited to 1 core (CPUQuota=100%)"
echo "  - Auto-restarts on crash"
echo ""
read -p "Install and enable service? [Y/n] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    mkdir -p "$HOME/.config/systemd/user"
    sed "s|__INSTALL_DIR__|$INSTALL_DIR|g" "$SCRIPT_DIR/piper-tts.service" \
        > "$HOME/.config/systemd/user/piper-tts.service"
    systemctl --user daemon-reload
    systemctl --user enable piper-tts.service
    systemctl --user restart piper-tts.service
    ok "Service installed and started"

    # Wait for model to load
    echo "  Waiting for model to load..."
    for i in $(seq 1 15); do
        if curl -s --max-time 1 "http://127.0.0.1:5030" > /dev/null 2>&1; then
            ok "Server is ready"
            break
        fi
        sleep 1
    done
else
    warn "Skipped — you'll need to start the server manually"
fi

# ── Step 7: GNOME keybinding (optional) ──
echo ""
echo "═══════════════════════════════════════════════"
echo "  Step 7: Set up GNOME Ctrl+1 keybinding"
echo "═══════════════════════════════════════════════"
echo ""
echo "This adds a Ctrl+1 shortcut to read highlighted text aloud."
echo "(Toggle — press again to stop)"
echo ""
read -p "Set up keybinding? [Y/n] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    BINDING_PATH="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"
    SLOT="custom0"

    # Find an unused slot
    EXISTING=$(gsettings get org.gnome.settings-daemon.plugins.media-keys custom-keybindings 2>/dev/null || echo "[]")
    if echo "$EXISTING" | grep -q "$SLOT"; then
        # Find next available slot
        for i in $(seq 0 20); do
            if ! echo "$EXISTING" | grep -q "custom${i}"; then
                SLOT="custom${i}"
                break
            fi
        done
    fi

    SLOT_PATH="${BINDING_PATH}/${SLOT}/"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${SLOT_PATH} name "Read Selected Text"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${SLOT_PATH} command "$BIN_DIR/read-clipboard.sh"
    gsettings set org.gnome.settings-daemon.plugins.media-keys.custom-keybinding:${SLOT_PATH} binding "<Primary>1"

    # Add slot to the list if not already there
    if ! echo "$EXISTING" | grep -q "$SLOT"; then
        NEW_LIST=$(echo "$EXISTING" | sed "s|\]|, '${SLOT_PATH}']|" | sed "s|\[, |[|")
        gsettings set org.gnome.settings-daemon.plugins.media-keys custom-keybindings "$NEW_LIST"
    fi

    ok "Ctrl+1 keybinding set"
else
    warn "Skipped — set up manually in Settings → Keyboard → Custom Shortcuts"
fi

# ── Step 8: Claude Code agent (optional) ──
echo ""
echo "═══════════════════════════════════════════════"
echo "  Step 8: Install Claude Code speak agent"
echo "═══════════════════════════════════════════════"
echo ""
if [ -d "$HOME/.claude" ]; then
    echo "Claude Code detected."
    echo "Will copy speak agent to: ~/.claude/agents/speak.md"
    echo ""
    read -p "Install agent? [Y/n] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        mkdir -p "$HOME/.claude/agents"
        cp "$SCRIPT_DIR/claude-agent-speak.md" "$HOME/.claude/agents/speak.md"
        ok "Claude agent installed"
    else
        warn "Skipped"
    fi
else
    warn "Claude Code not detected — skipping agent install"
fi

# ── Done ──
echo ""
echo "═══════════════════════════════════════════════"
echo "  Installation complete!"
echo "═══════════════════════════════════════════════"
echo ""
echo "  Usage:"
echo "    speak \"hello world\"          # speak from terminal"
echo "    echo \"hello\" | speak         # pipe text to speak"
echo "    Ctrl+1                        # read highlighted text"
echo "    Ctrl+1 (again)                # stop reading"
echo ""
echo "  The server runs on http://127.0.0.1:5030"
echo "  Under high CPU load, falls back to espeak-ng automatically."
echo ""

# Quick test
read -p "Run a quick test? [Y/n] " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    "$BIN_DIR/speak" "Piper T T S is installed and working. Hello!"
    ok "If you heard that, everything is working!"
else
    echo "Done."
fi
