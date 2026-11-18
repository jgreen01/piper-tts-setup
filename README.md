# Piper TTS Setup

Natural text-to-speech for Linux with intelligent fallback.

## Features

- **Piper TTS** — neural voice (en_US-lessac-medium) via local HTTP server
- **espeak-ng fallback** — automatic switch under high CPU load or if server is down
- **Clipboard reader** — highlight text, press Ctrl+1 to hear it read aloud
- **Streaming** — audio starts playing before full synthesis is complete
- **Sentence splitting** — prevents CPU hangs on long text
- **CPU capped** — systemd CPUQuota limits server to 1 core
- **Wayland + X11** — works on both display servers

## Quick Install

```bash
git clone https://github.com/jgreen01/piper-tts-setup.git
cd piper-tts-setup
./install.sh
```

The installer is interactive — it prompts before each step.

## What Gets Installed

| Component | Location |
|-----------|----------|
| TTS server + venv + voice | `~/.local/share/piper-tts/` |
| `speak` command | `~/bin/speak` |
| `read-clipboard.sh` | `~/bin/read-clipboard.sh` |
| systemd service | `~/.config/systemd/user/piper-tts.service` |
| Claude agent (optional) | `~/.claude/agents/speak.md` |

## Usage

```bash
# Speak from terminal
speak "hello world"

# Pipe text
echo "some text" | speak

# Read highlighted text (GNOME keybinding)
# Ctrl+1 to start, Ctrl+1 again to stop

# Adjust speed (piper length_scale: lower = faster)
SPEAK_SPEED=0.7 speak "faster speech"

# Adjust load threshold for espeak-ng fallback
SPEAK_LOAD_THRESHOLD=4 speak "more aggressive fallback"
```

## Requirements

- Ubuntu 22.04+ / Debian 12+ (or similar)
- Python 3.10+
- ~100MB disk (venv + voice model)
- ~165MB RAM (server idle)

## Uninstall

```bash
systemctl --user stop piper-tts.service
systemctl --user disable piper-tts.service
rm -rf ~/.local/share/piper-tts
rm ~/.config/systemd/user/piper-tts.service
rm ~/bin/speak ~/bin/read-clipboard.sh
systemctl --user daemon-reload
```

## License

MIT — see [LICENSE](LICENSE).
