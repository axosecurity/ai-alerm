#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.ai-alarm"
PREVIEW_PID=""

cleanup() {
  tput cnorm 2>/dev/null || printf "\033[?25h"
  stty echo icanon 2>/dev/null || true
  if [ -n "$PREVIEW_PID" ] && kill -0 "$PREVIEW_PID" 2>/dev/null; then
    kill "$PREVIEW_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT INT TERM

show_help() {
  cat << 'EOF'
╔═══════════════════════════════════════════════════════════════════╗
║                  AI-ALARM INSTALLER & SELECTOR                    ║
╚═══════════════════════════════════════════════════════════════════╝

USAGE:
    ./install.sh [OPTIONS]
    npx github:axosecurity/ai-alerm [OPTIONS]

OPTIONS:
    --select-only [agent]   Only launch interactive sound selector (-s)
                            Optional agent: claude, codex, antigravity, opencode, global
    --add <path|url>        Import custom sound to ~/.ai-alarm/sound/
    --open                  Open sound library in Finder / File Manager
    --remove <name>         Remove sound track from library
    --project               Also write hook to project workspace (.agents/hooks.json)
    --help | -help          Show this documentation manual (-h, --ask, -ask)

WHAT THE INSTALLER DOES:
    1. Sets up the permanent global sound library at: ~/.ai-alarm/sound/
    2. Lets you choose default and per-agent sounds using interactive arrow keys
    3. Installs 'alarm' and 'notify' to your PATH (/opt/homebrew/bin or ~/.local/bin)
    4. Automatically configures native Stop hooks for:
       - Claude Code (~/.claude/settings.json)
       - OpenAI Codex (~/.codex/config.toml)
       - Google Antigravity (~/.gemini/config/hooks.json, CLI, 2.0, IDE)
       - OpenCode (~/.config/opencode/plugins/task-finished-alarm.ts)
EOF
  exit 0
}

case "${1:-}" in
  --help|-help|-h|--ask|-ask|help)
    show_help
    ;;
esac

# -------------------------------------------------------------
# Global Sound Library Sync
# -------------------------------------------------------------
mkdir -p "$INSTALL_DIR/sound"
if [ "$SCRIPT_DIR" != "$INSTALL_DIR" ]; then
  shopt -s nullglob nocaseglob
  for track in "$SCRIPT_DIR/sound"/*.{mp3,wav,m4a,aac,ogg,flac,aiff}; do
    if [ -f "$track" ]; then
      base="$(basename "$track")"
      if [ ! -f "$INSTALL_DIR/sound/$base" ]; then
        cp "$track" "$INSTALL_DIR/sound/$base"
      fi
    fi
  done
  cp "$SCRIPT_DIR/alarm" "$INSTALL_DIR/alarm" 2>/dev/null || true
  cp "$SCRIPT_DIR/notify" "$INSTALL_DIR/notify" 2>/dev/null || true
  cp "$SCRIPT_DIR/install.sh" "$INSTALL_DIR/install.sh" 2>/dev/null || true
  chmod +x "$INSTALL_DIR/alarm" "$INSTALL_DIR/notify" "$INSTALL_DIR/install.sh" 2>/dev/null || true
fi

# Clean path helper (strips surrounding quotes, unescapes, expands tilde)
clean_input_path() {
  local raw="$1"
  node -e '
    let p = process.argv[1] ? process.argv[1].trim() : "";
    if ((p.startsWith("\"") && p.endsWith("\"")) || (p.startsWith("\x27") && p.endsWith("\x27"))) {
      p = p.slice(1, -1);
    }
    if (p.startsWith("~")) p = process.env.HOME + p.slice(1);
    p = p.replace(/\\ /g, " ");
    console.log(p);
  ' "$raw" 2>/dev/null || echo "$raw"
}

# Add sound function
add_sound_file() {
  local input="$1"
  local target_name="${2:-}"
  input="$(clean_input_path "$input")"

  if [ -z "$input" ]; then
    echo "⚠ Error: No file path or URL provided."
    return 1
  fi

  mkdir -p "$INSTALL_DIR/sound"

  # Case A: URL download
  if [[ "$input" =~ ^https?:// ]]; then
    local filename
    filename="$(basename "$input" | cut -d? -f1)"
    [ -n "$target_name" ] && filename="$target_name"
    if [[ ! "$filename" =~ \.(mp3|wav|m4a|aac|ogg|flac|aiff)$ ]]; then
      filename="${filename}.mp3"
    fi
    echo "→ Downloading audio from URL: $input"
    if curl -fsSL "$input" -o "$INSTALL_DIR/sound/$filename"; then
      echo "✓ Successfully imported to $INSTALL_DIR/sound/$filename"
      ADDED_SOUND_BASENAME="$filename"
      return 0
    else
      echo "⚠ Download failed."
      return 1
    fi
  fi

  # Case B: Local file
  if [ ! -f "$input" ]; then
    echo "⚠ Error: File not found at: $input"
    return 1
  fi

  local base
  base="$(basename "$input")"
  [ -n "$target_name" ] && base="$target_name"
  cp "$input" "$INSTALL_DIR/sound/$base"
  echo "✓ Successfully imported: $INSTALL_DIR/sound/$base"
  ADDED_SOUND_BASENAME="$base"
  return 0
}

# Open command handler
if [ "${1:-}" = "--open" ] || [ "${1:-}" = "open" ]; then
  mkdir -p "$INSTALL_DIR/sound"
  if command -v open >/dev/null 2>&1; then
    open "$INSTALL_DIR/sound"
    echo "✓ Opened sound library in Finder: $INSTALL_DIR/sound"
  elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open "$INSTALL_DIR/sound"
    echo "✓ Opened sound library: $INSTALL_DIR/sound"
  else
    echo "Sound library located at: $INSTALL_DIR/sound"
  fi
  exit 0
fi

# Add command handler
if [ "${1:-}" = "--add" ] || [ "${1:-}" = "add" ]; then
  add_sound_file "$2" "${3:-}"
  exit $?
fi

# Remove command handler
if [ "${1:-}" = "--remove" ] || [ "${1:-}" = "remove" ]; then
  TARGET_RM="$2"
  FOUND=false
  shopt -s nullglob nocaseglob
  for f in "$INSTALL_DIR/sound"/*; do
    if [ "$(basename "$f")" = "$TARGET_RM" ] || [ "$(basename "$f" | cut -d. -f1)" = "$TARGET_RM" ]; then
      rm -f "$f"
      echo "✓ Removed sound: $f"
      FOUND=true
    fi
  done
  if [ "$FOUND" = false ]; then
    echo "⚠ Sound '$TARGET_RM' not found in $INSTALL_DIR/sound"
  fi
  exit 0
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
  elif command -v paplay >/dev/null 2>&1; then
    (paplay "$audio_file") &
    PREVIEW_PID=$!
  elif command -v mpv >/dev/null 2>&1; then
    (mpv --no-video "$audio_file" >/dev/null 2>&1) &
    PREVIEW_PID=$!
  elif command -v ffplay >/dev/null 2>&1; then
    (ffplay -nodisp -autoexit "$audio_file" >/dev/null 2>&1) &
    PREVIEW_PID=$!
  elif command -v aplay >/dev/null 2>&1; then
    (aplay "$audio_file") &
    PREVIEW_PID=$!
  fi
}

# -------------------------------------------------------------
# Reusable Arrow-Key Menu
# -------------------------------------------------------------
run_menu() {
  local header="$1"
  shift
  local is_sound_menu="$1"
  shift
  local -a items=("$@")
  local num_items=${#items[@]}
  local current=0

  local TTY_DEV="/dev/tty"
  if [ ! -r "$TTY_DEV" ]; then
    TTY_DEV="/dev/stdin"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo "$header"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  if [ "$is_sound_menu" = true ]; then
    echo " Controls: [↑ / ↓] Navigate   [Space] Preview   [Enter] Select   [q] Cancel"
  else
    echo " Controls: [↑ / ↓] Navigate   [Enter] Select   [q] Cancel"
  fi
  echo ""

  tput civis 2>/dev/null || printf "\033[?25l"
  stty -echo -icanon 2>/dev/null || true

  local first_render=true
  render_options() {
    local sel=$1
    if [ "$first_render" = false ]; then
      printf "\033[%dA" "$num_items"
    fi
    first_render=false

    for i in "${!items[@]}"; do
      if [ "$i" -eq "$sel" ]; then
        printf "\033[2K \033[1;32m ❯ [●] %s\033[0m\n" "${items[$i]}"
      else
        printf "\033[2K   [ ] %s\n" "${items[$i]}"
      fi
    done
  }

  while true; do
    render_options "$current"
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
      " ") # Spacebar preview
        if [ "$is_sound_menu" = true ] && [ "$current" -lt ${#GLOBAL_SOUND_FILES[@]} ]; then
          play_preview "${GLOBAL_SOUND_FILES[$current]}"
        fi
        ;;
      "") # Enter
        stop_preview
        break
        ;;
      "q"|"Q")
        stop_preview
        tput cnorm 2>/dev/null || printf "\033[?25h"
        stty echo icanon 2>/dev/null || true
        echo ""
        echo "Selection cancelled."
        return 1
        ;;
    esac
  done

  tput cnorm 2>/dev/null || printf "\033[?25h"
  stty echo icanon 2>/dev/null || true
  MENU_SELECTED_INDEX=$current
  return 0
}

# -------------------------------------------------------------
# Interactive Selector Flow
# -------------------------------------------------------------
select_audio_flow() {
  local target_agent="${1:-}"

  # Step 1: Select Target Agent if not specified
  if [ -z "$target_agent" ]; then
    local targets=(
      "🌐 Global Default (All Agents Fallback)"
      "🟣 Claude Code"
      "🟢 OpenAI Codex"
      "🔵 Google Antigravity"
      "🟡 OpenCode"
    )
    if ! run_menu " 🎯 Choose Target to Configure Sound For:" false "${targets[@]}"; then
      return 0
    fi
    case "$MENU_SELECTED_INDEX" in
      0) target_agent="global" ;;
      1) target_agent="claude" ;;
      2) target_agent="codex" ;;
      3) target_agent="antigravity" ;;
      4) target_agent="opencode" ;;
    esac
  fi

  # Step 2: Dynamically Load Multi-Format Sounds from Global Library
  shopt -s nullglob nocaseglob
  GLOBAL_SOUND_FILES=( "$INSTALL_DIR"/sound/*.{mp3,wav,m4a,aac,ogg,flac,aiff} )

  local sound_titles=()
  local sound_basenames=()
  for sf in "${GLOBAL_SOUND_FILES[@]}"; do
    sound_basenames+=("$(basename "$sf")")
    sound_titles+=("$(basename "$sf" | cut -d. -f1)")
  done

  # Add dynamic actions to menu
  local action_add_idx=${#sound_titles[@]}
  sound_titles+=("➕ [Import / Add Custom Sound (File or URL)...]")
  local action_open_idx=${#sound_titles[@]}
  sound_titles+=("📂 [Open Sound Library in Finder]")

  local header_label="Global Default"
  case "$target_agent" in
    claude) header_label="Claude Code" ;;
    codex) header_label="OpenAI Codex" ;;
    antigravity) header_label="Google Antigravity" ;;
    opencode) header_label="OpenCode" ;;
  esac

  if ! run_menu " 🔔 Select Sound Track for: $header_label" true "${sound_titles[@]}"; then
    return 0
  fi

  # Handle Action: Import Custom Sound
  if [ "$MENU_SELECTED_INDEX" -eq "$action_add_idx" ]; then
    echo ""
    echo "Enter audio file path or URL (or drag & drop file here):"
    read -r user_sound_input < /dev/tty
    if add_sound_file "$user_sound_input"; then
      chosen_file="$ADDED_SOUND_BASENAME"
    else
      return 1
    fi
  # Handle Action: Open in Finder
  elif [ "$MENU_SELECTED_INDEX" -eq "$action_open_idx" ]; then
    if command -v open >/dev/null 2>&1; then
      open "$INSTALL_DIR/sound"
      echo "✓ Opened $INSTALL_DIR/sound in Finder."
      echo "Drop your audio files there, then run 'alarm --select' again."
    fi
    return 0
  else
    chosen_file="${sound_basenames[$MENU_SELECTED_INDEX]}"
  fi

  # Step 3: Link Sound
  if [ "$target_agent" = "global" ]; then
    ln -sf "sound/$chosen_file" "$INSTALL_DIR/alarm_sound.mp3"
    [ "$SCRIPT_DIR" != "$INSTALL_DIR" ] && ln -sf "sound/$chosen_file" "$SCRIPT_DIR/alarm_sound.mp3" 2>/dev/null || true
    echo ""
    echo " ✓ Set Global Default sound → $chosen_file"
  else
    ln -sf "sound/$chosen_file" "$INSTALL_DIR/alarm_sound_${target_agent}.mp3"
    [ "$SCRIPT_DIR" != "$INSTALL_DIR" ] && ln -sf "sound/$chosen_file" "$SCRIPT_DIR/alarm_sound_${target_agent}.mp3" 2>/dev/null || true
    echo ""
    echo " ✓ Set $header_label custom sound → $chosen_file"
  fi
}

# If --select-only is passed, run audio selection flow and exit
if [ "${1:-}" = "--select-only" ] || [ "${1:-}" = "-s" ]; then
  select_audio_flow "${2:-}"
  exit 0
fi

# =============================================================
# Full Master Installation
# =============================================================
echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║          AI-ALARM UNIVERSAL AGENT HOOKS SETUP             ║"
echo "╚═══════════════════════════════════════════════════════════╝"

# 1. Interactive Sound Selection for Global Default
select_audio_flow "global"

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
    
    let exists = false;
    for (const item of settings.hooks.Stop) {
      if (item.hooks) {
        for (const h of item.hooks) {
          if (h.command && h.command.includes("alarm")) {
            h.command = process.argv[1] + " claude";
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
            command: process.argv[1] + " claude",
            timeout: 15
          }
        ]
      });
    }
    fs.mkdirSync(path.dirname(settingsPath), { recursive: true });
    fs.writeFileSync(settingsPath, JSON.stringify(settings, null, 2) + "\n");
    console.log("  ✓ Claude Code hook configured (command: alarm claude)");
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
  command = "$TARGET_ALARM_BIN codex"
  timeout = 15
  trust_level = "trusted"
EOF
    echo "  ✓ Codex Stop hook configured (command: alarm codex)"
  fi
fi

# --- C. Google Antigravity (CLI, Antigravity 2.0, IDE) ---
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
          command: process.argv[1] + " antigravity",
          timeout: 15
        }
      ]
    };
    fs.writeFileSync(hooksPath, JSON.stringify(hooks, null, 2) + "\n");
    console.log("  ✓ Antigravity global hook configured: ~/.gemini/config/hooks.json");

    // Mirror to Antigravity CLI, Antigravity 2.0, and Antigravity IDE directories
    const flavors = ["antigravity", "antigravity-cli", "antigravity-ide"];
    for (const f of flavors) {
      const fDir = path.join(process.env.HOME, ".gemini", f);
      if (fs.existsSync(fDir)) {
        const fHook = path.join(fDir, "hooks.json");
        try {
          if (!fs.existsSync(fHook)) {
            fs.symlinkSync(hooksPath, fHook);
          }
        } catch(e) {}
      }
    }
  ' "$TARGET_ALARM_BIN" 2>/dev/null || echo "  ⚠ Antigravity hook configuration skipped."
fi

# Optional: Project-local workspace hook (.agents/hooks.json)
if [ -d ".agents" ] || [ "${1:-}" = "--project" ] || [ "${2:-}" = "--project" ]; then
  mkdir -p .agents
  node -e '
    const fs = require("fs");
    const hooksPath = ".agents/hooks.json";
    let hooks = {};
    if (fs.existsSync(hooksPath)) {
      try { hooks = JSON.parse(fs.readFileSync(hooksPath, "utf8")); } catch(e){}
    }
    hooks["task-finished-alarm"] = {
      Stop: [
        {
          type: "command",
          command: process.argv[1] + " antigravity",
          timeout: 15
        }
      ]
    };
    fs.writeFileSync(hooksPath, JSON.stringify(hooks, null, 2) + "\n");
    console.log("  ✓ Project workspace hook configured in .agents/hooks.json");
  ' "$TARGET_ALARM_BIN" 2>/dev/null || true
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
        await \$\`$TARGET_ALARM_BIN opencode\`
      }
    },
  }
}
EOF
  echo "  ✓ OpenCode plugin hook configured in $OPENCODE_PLUGINS/task-finished-alarm.ts"
fi

echo ""
echo "🎉 Setup complete! All AI agents are configured with task completion hooks."
echo "📁 Global sound library: $INSTALL_DIR/sound/"
echo "💡 Help manual: Run 'alarm --help' or 'alarm -ask'"
echo "💡 Change sounds: Run 'alarm --select'"
echo "💡 Add custom sound: Run 'alarm add <file_or_url>' or 'alarm open'"
echo ""
