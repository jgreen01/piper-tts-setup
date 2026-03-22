#!/bin/bash
#
# Read selected/clipboard text aloud
#
# Keybinding: Ctrl+1 (toggle — press again to stop)

PIDFILE="/tmp/tts-reader.pid"
SPEAK_CMD="$(dirname "$(readlink -f "$0")")/speak"

# ── Toggle: if already running, stop it ──
if [ -f "$PIDFILE" ]; then
    pid=$(cat "$PIDFILE")
    if kill -0 "$pid" 2>/dev/null; then
        pkill -P "$pid" 2>/dev/null
        kill "$pid" 2>/dev/null
        rm -f "$PIDFILE"
        exit 0
    fi
    rm -f "$PIDFILE"
fi

# ── Get selected text ──
TEXT=""

# Try Wayland primary selection first (highlighted text, no Ctrl+C needed)
if command -v wl-paste &>/dev/null; then
    TEXT=$(wl-paste --primary --no-newline 2>/dev/null || true)
fi

# Fallback: Wayland clipboard
if [ -z "$TEXT" ] && command -v wl-paste &>/dev/null; then
    TEXT=$(wl-paste --no-newline 2>/dev/null || true)
fi

# Fallback: X11 (XWayland)
if [ -z "$TEXT" ] && command -v xclip &>/dev/null; then
    TEXT=$(xclip -selection primary -o 2>/dev/null || true)
    [ -z "$TEXT" ] && TEXT=$(xclip -selection clipboard -o 2>/dev/null || true)
fi

# Nothing to read
if [ -z "$TEXT" ] || ! echo "$TEXT" | grep -q '[^[:space:]]'; then
    notify-send -t 2000 "TTS" "No text selected" 2>/dev/null
    exit 0
fi

# ── Clean and speak ──
CLEAN_TEXT=$(printf '%s' "$TEXT" | tr '\n' ' ' | tr -s ' ' | sed 's/[^[:print:]]//g')

("$SPEAK_CMD" "$CLEAN_TEXT") &
echo $! > "$PIDFILE"
