#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.ai-alarm"
PREVIEW_PID=""

cleanup() {
  # Restore cursor and terminal echo
  tput cnorm 2>/dev/null || printf "\033[?25h"
  stty echo icanon 2>/dev/null || true
  if [ -n "$PREVIEW_PID" ] && kill -0 "$PREVIEW_PID" 2>/dev/null; then
    kill "$PREVIEW_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

# Ensure install directory exists and files are present
mkdir -p "$INSTALL_DIR/sound"
if [ "$SCRIPT_DIR" != "$INSTALL_DIR" ]; then
  cp -r "$SCRIPT_DIR/sound/"* "$INSTALL_DIR/sound/" 2>/dev/null || true
  cp "$SCRIPT_DIR/alarm" "$INSTALL_DIR/alarm" 2>/dev/null || true
  cp "$SCRIPT_DIR/notify" "$INSTALL_DIR/notify" 2>/dev/null || true
  cp "$SCRIPT_DIR/install.sh" "$INSTALL_DIR/install.sh" 2>/dev/null || true
  chmod +x "$INSTALL_DIR/alarm" "$INSTALL_DIR/notify" "$INSTALL_DIR/install.sh" 2>/dev/null || true
fi

stop_preview() {
  if [ -n "$PREVIEW_PID" ] && kill -0 "$PREVIEW_PID" 2>/dev/null; then
    kill "$PREVIEW_PID" 2>/dev/null || true
    PREVIEW_PID=""
  fi
}

play_preview() {
  local audio_file="$1"
  stop_preview
  if command -v afplay >/dev/null 2>&1; then
    (afplay "$audio_file") &
    PREVIEW_PID=$!
  elif command -v mpv >/dev/null 2>&1; then
    (mpv --no-video "$audio_file" >/dev/null 2>&1) &
    PREVIEW_PID=$!
  elif command -v ffplay >/dev/null 2>&1; then
    (ffplay -nodisp -autoexit "$audio_file" >/dev/null 2>&1) &
    PREVIEW_PID=$!
  fi
}

select_audio() {
  local sound_files=("$INSTALL_DIR"/sound/*.mp3)
  if [ ${#sound_files[@]} -eq 0 ] || [ ! -f "${sound_files[0]}" ]; then
    echo "⚠ No audio tracks found in $INSTALL_DIR/sound"
    return 1
  fi

  local titles=()
  local file_basenames=()
  for file in "${sound_files[@]}"; do
    local base
    base="$(basename "$file" .mp3)"
    file_basenames+=("$(basename "$file")")
    titles+=("$base")
  done

  local num_items=${#titles[@]}
  local current=0

  # Check if an existing sound is symlinked
  if [ -L "$INSTALL_DIR/alarm_sound.mp3" ]; then
    local current_target
    current_target="$(readlink "$INSTALL_DIR/alarm_sound.mp3" 2>/dev/null || true)"
    current_target="$(basename "$current_target")"
    for i in "${!file_basenames[@]}"; do
      if [ "${file_basenames[$i]}" = "$current_target" ]; then
        current=$i
        break
      fi
    done
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " 🔔 Select Alarm / Zikir Sound for Task Completion"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Controls:"
  echo "   [↑ / ↓] Navigate      [Space] Preview sound"
  echo "   [Enter] Confirm       [q] Quit"
  echo ""

  # Ensure input is taken from terminal tty
  local TTY_DEV="/dev/tty"
  if [ ! -r "$TTY_DEV" ]; then
    TTY_DEV="/dev/stdin"
  fi

  # Hide cursor
  tput civis 2>/dev/null || printf "\033[?25l"
  stty -echo -icanon 2>/dev/null || true

  local first_render=true
  render_menu() {
    local sel=$1
    if [ "$first_render" = false ]; then
      printf "\033[%dA" "$num_items"
    fi
    first_render=false

    for i in "${!titles[@]}"; do
      if [ "$i" -eq "$sel" ]; then
        printf "\033[2K \033[1;32m ❯ [●] %s\033[0m\n" "${titles[$i]}"
      else
        printf "\033[2K   [ ] %s\n" "${titles[$i]}"
      fi
    done
  }

  while true; do
    render_menu "$current"
    local char=""
    local rest=""
    IFS= read -rsn1 char < "$TTY_DEV" || true
    if [[ "$char" == $'\033' ]]; then
      read -rsn2 -t 1 rest < "$TTY_DEV" || true
      char+="$rest"
    fi

    case "$char" in
      $'\033[A'|"k"|"K") # Up
        stop_preview
        if [ "$current" -gt 0 ]; then
          current=$((current - 1))
        else
          current=$((num_items - 1))
        fi
        ;;
      $'\033[B'|"j"|"J") # Down
        stop_preview
        if [ "$current" -lt $((num_items - 1)) ]; then
          current=$((current + 1))
        else
          current=0
        fi
        ;;
      " ") # Preview
        play_preview "${sound_files[$current]}"
        ;;
      "") # Enter
        stop_preview
        break
        ;;
      "q"|"Q")
        stop_preview
        echo ""
        echo "Exiting selection."
        return 0
        ;;
    esac
  done

  # Restore terminal
  tput cnorm 2>/dev/null || printf "\033[?25h"
  stty echo icanon 2>/dev/null || true

  local chosen_file="${file_basenames[$current]}"
  ln -sf "sound/$chosen_file" "$INSTALL_DIR/alarm_sound.mp3"
  if [ "$SCRIPT_DIR" != "$INSTALL_DIR" ]; then
    ln -sf "sound/$chosen_file" "$SCRIPT_DIR/alarm_sound.mp3" 2>/dev/null || true
  fi

  echo ""
  echo " ✓ Selected sound: $chosen_file"
  echo " ✓ Linked to: $INSTALL_DIR/alarm_sound.mp3"
}

# If --select-only is passed, run audio selection and exit
if [ "${1:-}" = "--select-only" ] || [ "${1:-}" = "--select" ]; then
  select_audio
  exit 0
fi

# ==========================================
# Full Installation
# ==========================================
echo ""
echo "╔════════════════════════════════════════════════════╗"
echo "║          AI Alarm - Universal Agent Hooks         ║"
echo "╚════════════════════════════════════════════════════╝"

# 1. Run interactive sound selection
select_audio

# 2. Determine global binary install directory
BIN_DIR=""
if [ -d "/opt/homebrew/bin" ] && [ -w "/opt/homebrew/bin" ]; then
  BIN_DIR="/opt/homebrew/bin"
elif [ -d "/usr/local/bin" ] && [ -w "/usr/local/bin" ]; then
  BIN_DIR="/usr/local/bin"
else
  BIN_DIR="${HOME}/.local/bin"
  mkdir -p "$BIN_DIR"
fi

echo ""
echo "→ Installing binaries to $BIN_DIR..."
ln -sf "$INSTALL_DIR/alarm" "$BIN_DIR/alarm"
ln -sf "$INSTALL_DIR/notify" "$BIN_DIR/notify"
chmod +x "$BIN_DIR/alarm" "$BIN_DIR/notify"
echo "  ✓ Installed: $BIN_DIR/alarm"
echo "  ✓ Installed: $BIN_DIR/notify"

TARGET_ALARM_BIN="$BIN_DIR/alarm"

# 3. Configure Hooks for All AI Coding Agents
echo ""
echo "→ Auto-detecting and configuring AI coding agent hooks..."

# --- A. Claude Code ---
if [ -d "$HOME/.claude" ] || command -v claude >/dev/null 2>&1; then
  node -e '
    const fs = require("fs");
    const path = require("path");
    const settingsPath = path.join(process.env.HOME, ".claude", "settings.json");
    let settings = {};
    if (fs.existsSync(settingsPath)) {
      try { settings = JSON.parse(fs.readFileSync(settingsPath, "utf8")); } catch(e){}
    }
    if (!settings.hooks) settings.hooks = {};
    if (!settings.hooks.Stop) settings.hooks.Stop = [];
    
    // Check if Stop hook pointing to alarm already exists
    let exists = false;
    for (const item of settings.hooks.Stop) {
      if (item.hooks) {
        for (const h of item.hooks) {
          if (h.command && h.command.includes("alarm")) {
            h.command = process.argv[1];
            exists = true;
          }
        }
      }
    }
    if (!exists) {
      settings.hooks.Stop.push({
        hooks: [
          {
            type: "command",
            command: process.argv[1],
            timeout: 15
          }
        ]
      });
    }
    fs.mkdirSync(path.dirname(settingsPath), { recursive: true });
    fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + "\n");
    console.log("  ✓ Claude Code hook configured in ~/.claude/settings.json");
  ' "$TARGET_ALARM_BIN" 2>/dev/null || echo "  ⚠ Claude Code hook configuration skipped."
fi

# --- B. OpenAI Codex ---
if [ -d "$HOME/.codex" ] || command -v codex >/dev/null 2>&1; then
  mkdir -p "$HOME/.codex"
  CODEX_CONFIG="$HOME/.codex/config.toml"
  if [ -f "$CODEX_CONFIG" ] && grep -q 'hooks.Stop' "$CODEX_CONFIG" && grep -q 'alarm' "$CODEX_CONFIG"; then
    echo "  ✓ Codex Stop hook already configured in ~/.codex/config.toml"
  else
    cat >> "$CODEX_CONFIG" << EOF

[[hooks.Stop]]
matcher = "always"

  [[hooks.Stop.hooks]]
  type = "command"
  command = "$TARGET_ALARM_BIN"
  timeout = 15
  trust_level = "trusted"
EOF
    echo "  ✓ Codex Stop hook configured in ~/.codex/config.toml"
  fi
fi

# --- C. Google Antigravity ---
if [ -d "$HOME/.gemini" ] || command -v agy >/dev/null 2>&1; then
  mkdir -p "$HOME/.gemini/config"
  node -e '
    const fs = require("fs");
    const path = require("path");
    const hooksPath = path.join(process.env.HOME, ".gemini", "config", "hooks.json");
    let hooks = {};
    if (fs.existsSync(hooksPath)) {
      try { hooks = JSON.parse(fs.readFileSync(hooksPath, "utf8")); } catch(e){}
    }
    hooks["task-finished-alarm"] = {
      Stop: [
        {
          type: "command",
          command: process.argv[1],
          timeout: 15
        }
      ]
    };
    fs.writeFileSync(hooksPath, JSON.stringify(hooks, null, 2) + "\n");
    console.log("  ✓ Antigravity hook configured in ~/.gemini/config/hooks.json");
  ' "$TARGET_ALARM_BIN" 2>/dev/null || echo "  ⚠ Antigravity hook configuration skipped."
fi

# --- D. OpenCode ---
if [ -d "$HOME/.config/opencode" ] || command -v opencode >/dev/null 2>&1; then
  OPENCODE_PLUGINS="$HOME/.config/opencode/plugins"
  mkdir -p "$OPENCODE_PLUGINS"
  cat > "$OPENCODE_PLUGINS/task-finished-alarm.ts" << EOF
export const TaskFinishedAlarmPlugin = async ({ $ }) => {
  return {
    event: async ({ event }) => {
      if (event.type === "session.idle") {
        await \$\`$TARGET_ALARM_BIN\`
      }
    },
  }
}
EOF
  echo "  ✓ OpenCode plugin hook configured in $OPENCODE_PLUGINS/task-finished-alarm.ts"
fi

echo ""
echo "🎉 Setup complete! All AI agents will now trigger your alarm when tasks finish."
echo "💡 Tip: Run 'alarm --select' at any time to switch your sound."
echo ""
