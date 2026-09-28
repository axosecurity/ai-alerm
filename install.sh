#!/usr/bin/env bash
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="${HOME}/.ai-alarm"
PREVIEW_PID=""
CURRENT_PLAYING_FILE=""

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
    --select-only [agent]   Launch interactive sound selector (-s)
    --search <query>        Search sound library by name, tag, or description
    --update                Update community sound library from GitHub (sync)
    --add <path|url>        Import custom sound to ~/.ai-alarm/sound/
    --open                  Open sound library in Finder / File Manager
    --remove <name>         Remove sound track from library
    --project               Also write hook to project workspace (.agents/hooks.json)
    --help | -help          Show this documentation manual (-h, --ask, -ask)
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
  if [ -f "$SCRIPT_DIR/sound/sounds.json" ] && [ ! -f "$INSTALL_DIR/sound/sounds.json" ]; then
    cp "$SCRIPT_DIR/sound/sounds.json" "$INSTALL_DIR/sound/sounds.json"
  fi
  cp "$SCRIPT_DIR/alarm" "$INSTALL_DIR/alarm" 2>/dev/null || true
  cp "$SCRIPT_DIR/notify" "$INSTALL_DIR/notify" 2>/dev/null || true
  cp "$SCRIPT_DIR/install.sh" "$INSTALL_DIR/install.sh" 2>/dev/null || true
  chmod +x "$INSTALL_DIR/alarm" "$INSTALL_DIR/notify" "$INSTALL_DIR/install.sh" 2>/dev/null || true
fi

# Clean path helper
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

# -------------------------------------------------------------
# Community Sound Library Updater (from GitHub)
# -------------------------------------------------------------
update_sound_library() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " 🔄 Updating Sound Library from GitHub..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  local GITHUB_RAW="https://raw.githubusercontent.com/axosecurity/ai-alerm/master"
  local TMP_JSON="/tmp/ai_alarm_sounds_update.json"

  if ! curl -fsSL "$GITHUB_RAW/sound/sounds.json" -o "$TMP_JSON" 2>/dev/null; then
    echo "⚠ Unable to reach GitHub. Please check internet connection."
    return 1
  fi

  mkdir -p "$INSTALL_DIR/sound"
  local downloaded_count=0

  node -e '
    const fs = require("fs");
    const path = require("path");
    const { execSync } = require("child_process");

    const tmpJson = process.argv[1];
    const installSoundDir = process.argv[2];
    const githubRaw = process.argv[3];

    let remoteCatalog = {};
    try {
      remoteCatalog = JSON.parse(fs.readFileSync(tmpJson, "utf8"));
    } catch(e) {
      process.exit(1);
    }

    let localCatalog = {};
    const localJsonPath = path.join(installSoundDir, "sounds.json");
    if (fs.existsSync(localJsonPath)) {
      try { localCatalog = JSON.parse(fs.readFileSync(localJsonPath, "utf8")); } catch(e){}
    }

    let newCount = 0;
    for (const [filename, meta] of Object.entries(remoteCatalog)) {
      const localFile = path.join(installSoundDir, filename);
      if (!fs.existsSync(localFile)) {
        console.log(`  ↓ Downloading: ${meta.title || filename}...`);
        try {
          execSync(`curl -fsSL "${githubRaw}/sound/${filename}" -o "${localFile}"`);
          newCount++;
        } catch(err) {
          console.log(`  ⚠ Failed to download ${filename}`);
        }
      }
      localCatalog[filename] = meta;
    }

    fs.writeFileSync(localJsonPath, JSON.stringify(localCatalog, null, 2) + "\n");
    console.log(`✓ Sound catalog updated! ${newCount} new community tracks added.`);
  ' "$TMP_JSON" "$INSTALL_DIR/sound" "$GITHUB_RAW"

  rm -f "$TMP_JSON"
}

# Update handler
if [ "${1:-}" = "--update" ] || [ "${1:-}" = "update" ] || [ "${1:-}" = "sync" ] || [ "${1:-}" = "--sync" ]; then
  update_sound_library
  exit $?
fi

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

# Search command handler
search_sounds_cli() {
  local query="$1"
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " 🔍 Sound Library Search: \"$query\""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

  node -e '
    const fs = require("fs");
    const path = require("path");

    const soundDir = process.argv[1];
    const q = process.argv[2].toLowerCase();

    let catalog = {};
    const jsonPath = path.join(soundDir, "sounds.json");
    if (fs.existsSync(jsonPath)) {
      try { catalog = JSON.parse(fs.readFileSync(jsonPath, "utf8")); } catch(e){}
    }

    const files = fs.readdirSync(soundDir).filter(f => /\.(mp3|wav|m4a|aac|ogg|flac|aiff)$/i.test(f));
    let matches = 0;

    for (const file of files) {
      const meta = catalog[file] || {};
      const title = meta.title || file;
      const desc = meta.description || "";
      const cat = meta.category || "custom";
      const tags = (meta.tags || []).join(" ");
      const matchText = `${file} ${title} ${desc} ${cat} ${tags}`.toLowerCase();

      if (matchText.includes(q)) {
        matches++;
        console.log(`\n  ♪ \x1b[1;32m${title}\x1b[0m (${meta.duration || "?"}) [\x1b[36m${cat}\x1b[0m]`);
        if (desc) console.log(`    Description: ${desc}`);
        if (meta.contributor) console.log(`    Contributor: @${meta.contributor}`);
        console.log(`    File: ${file}`);
        console.log(`    Select: alarm set "${file}"`);
      }
    }

    if (matches === 0) {
      console.log("  (No matching sounds found)");
    } else {
      console.log(`\nFound ${matches} match(es).`);
    }
  ' "$INSTALL_DIR/sound" "$query"
}

if [ "${1:-}" = "--search" ] || [ "${1:-}" = "search" ]; then
  search_sounds_cli "${2:-}"
  exit 0
fi

# Set sound command handler
if [ "${1:-}" = "set" ] || [ "${1:-}" = "--set" ]; then
  TARGET_SOUND="$2"
  TARGET_AGENT="${3:-global}"
  if [ -z "$TARGET_SOUND" ]; then
    echo "Usage: alarm set <sound_filename> [agent]"
    exit 1
  fi
  MATCH_FILE=""
  shopt -s nullglob nocaseglob
  for f in "$INSTALL_DIR/sound"/*; do
    if [ "$(basename "$f")" = "$TARGET_SOUND" ] || [ "$(basename "$f" | cut -d. -f1)" = "$TARGET_SOUND" ]; then
      MATCH_FILE="$(basename "$f")"
      break
    fi
  done
  if [ -z "$MATCH_FILE" ]; then
    echo "⚠ Error: Sound '$TARGET_SOUND' not found in $INSTALL_DIR/sound"
    exit 1
  fi
  if [ "$TARGET_AGENT" = "global" ]; then
    ln -sf "sound/$MATCH_FILE" "$INSTALL_DIR/alarm_sound.mp3"
    echo "✓ Set Global Default sound → $MATCH_FILE"
  else
    ln -sf "sound/$MATCH_FILE" "$INSTALL_DIR/alarm_sound_${TARGET_AGENT}.mp3"
    echo "✓ Set $TARGET_AGENT sound → $MATCH_FILE"
  fi
  exit 0
fi

stop_preview() {
  if [ -n "$PREVIEW_PID" ] && kill -0 "$PREVIEW_PID" 2>/dev/null; then
    kill "$PREVIEW_PID" 2>/dev/null || true
    PREVIEW_PID=""
    CURRENT_PLAYING_FILE=""
  fi
}

play_preview() {
  local audio_file="$1"
  if [ "$CURRENT_PLAYING_FILE" = "$audio_file" ] && [ -n "$PREVIEW_PID" ] && kill -0 "$PREVIEW_PID" 2>/dev/null; then
    stop_preview
    return
  fi

  stop_preview
  CURRENT_PLAYING_FILE="$audio_file"
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
# Rich Interactive Sound Selector with Search & Category Filter
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

    local TTY_DEV="/dev/tty"
    [ ! -r "$TTY_DEV" ] && TTY_DEV="/dev/stdin"

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " 🎯 Choose Target to Configure Sound For:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Controls: [↑ / ↓] Navigate   [Enter] Select   [q] Cancel"
    echo ""

    local cur=0
    local first=true
    tput civis 2>/dev/null || printf "\033[?25l"
    stty -echo -icanon 2>/dev/null || true

    while true; do
      if [ "$first" = false ]; then
        printf "\033[%dA" "${#targets[@]}"
      fi
      first=false
      for i in "${!targets[@]}"; do
        if [ "$i" -eq "$cur" ]; then
          printf "\033[2K \033[1;32m ❯ [●] %s\033[0m\n" "${targets[$i]}"
        else
          printf "\033[2K   [ ] %s\n" "${targets[$i]}"
        fi
      done

      local ch=""
      local r=""
      IFS= read -rsn1 ch < "$TTY_DEV" || true
      if [[ "$ch" == $'\033' ]]; then
        read -rsn2 -t 1 r < "$TTY_DEV" || true
        ch+="$r"
      fi

      case "$ch" in
        $'\033[A'|"k"|"K") [ "$cur" -gt 0 ] && cur=$((cur - 1)) || cur=$((${#targets[@]} - 1)) ;;
        $'\033[B'|"j"|"J") [ "$cur" -lt $((${#targets[@]} - 1)) ] && cur=$((cur + 1)) || cur=0 ;;
        "") break ;;
        "q"|"Q")
          tput cnorm 2>/dev/null || printf "\033[?25h"
          stty echo icanon 2>/dev/null || true
          return 0
          ;;
      esac
    done

    tput cnorm 2>/dev/null || printf "\033[?25h"
    stty echo icanon 2>/dev/null || true

    case "$cur" in
      0) target_agent="global" ;;
      1) target_agent="claude" ;;
      2) target_agent="codex" ;;
      3) target_agent="antigravity" ;;
      4) target_agent="opencode" ;;
    esac
  fi

  local header_label="Global Default"
  case "$target_agent" in
    claude) header_label="Claude Code" ;;
    codex) header_label="OpenAI Codex" ;;
    antigravity) header_label="Google Antigravity" ;;
    opencode) header_label="OpenCode" ;;
  esac

  # Step 2: Interactive Sound List with Category Filter & Search
  local active_category="all"
  local search_query=""

  local TTY_DEV="/dev/tty"
  [ ! -r "$TTY_DEV" ] && TTY_DEV="/dev/stdin"

  while true; do
    # Load items using Node helper
    local JSON_RESULT
    JSON_RESULT="$(node -e '
      const fs = require("fs");
      const path = require("path");

      const soundDir = process.argv[1];
      const activeCat = process.argv[2].toLowerCase();
      const query = process.argv[3].toLowerCase();

      let catalog = {};
      const catPath = path.join(soundDir, "sounds.json");
      if (fs.existsSync(catPath)) {
        try { catalog = JSON.parse(fs.readFileSync(catPath, "utf8")); } catch(e){}
      }

      const files = fs.readdirSync(soundDir).filter(f => /\.(mp3|wav|m4a|aac|ogg|flac|aiff)$/i.test(f));
      const categories = new Set(["all"]);

      for (const f of files) {
        if (catalog[f] && catalog[f].category) categories.add(catalog[f].category.toLowerCase());
      }

      const list = [];
      for (const f of files) {
        const meta = catalog[f] || {};
        const title = meta.title || f.replace(/\.[^.]+$/, "");
        const cat = (meta.category || "custom").toLowerCase();
        const desc = meta.description || "";
        const dur = meta.duration || "";
        const tags = (meta.tags || []).join(" ");
        const matchText = `${f} ${title} ${desc} ${cat} ${tags}`.toLowerCase();

        if (activeCat !== "all" && cat !== activeCat) continue;
        if (query && !matchText.includes(query)) continue;

        let display = title;
        if (dur) display += ` (${dur})`;
        if (desc) display += ` — [${desc}]`;

        list.push({ file: f, title, display, category: cat });
      }

      console.log(JSON.stringify({ list, categories: Array.from(categories) }));
    ' "$INSTALL_DIR/sound" "$active_category" "$search_query")"

    local ITEM_COUNT
    ITEM_COUNT="$(node -e 'console.log(JSON.parse(process.argv[1]).list.length)' "$JSON_RESULT")"

    local ALL_CATEGORIES=()
    while IFS= read -r c; do
      ALL_CATEGORIES+=("$c")
    done < <(node -e 'JSON.parse(process.argv[1]).categories.forEach(c => console.log(c))' "$JSON_RESULT")

    local DISPLAY_LIST=()
    local FILE_LIST=()
    while IFS= read -r line; do
      DISPLAY_LIST+=("$line")
    done < <(node -e 'JSON.parse(process.argv[1]).list.forEach(i => console.log(i.display))' "$JSON_RESULT")

    while IFS= read -r line; do
      FILE_LIST+=("$line")
    done < <(node -e 'JSON.parse(process.argv[1]).list.forEach(i => console.log(i.file))' "$JSON_RESULT")

    # Add interactive actions
    local act_add_idx=${#DISPLAY_LIST[@]}
    DISPLAY_LIST+=("➕ [Import / Add Custom Sound (File or URL)...]")
    local act_update_idx=${#DISPLAY_LIST[@]}
    DISPLAY_LIST+=("🔄 [Update Community Sounds from GitHub]")
    local act_open_idx=${#DISPLAY_LIST[@]}
    DISPLAY_LIST+=("📂 [Open Sound Library in Finder]")

    local total_rows=${#DISPLAY_LIST[@]}
    local current_idx=0
    local first_draw=true

    tput civis 2>/dev/null || printf "\033[?25l"
    stty -echo -icanon 2>/dev/null || true

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " 🔔 Select Alert Sound Track for: $header_label"
    echo " Filter: [\x1b[36m$active_category\x1b[0m] (press 'c' to cycle) | Search: \"\x1b[33m$search_query\x1b[0m\" (press '/' to filter)"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Controls: [↑ / ↓] Navigate   [Space] ▶ Play/Stop Preview   [Enter] Select   [q] Cancel"
    echo ""

    local need_rerender=false
    while true; do
      if [ "$first_draw" = false ]; then
        printf "\033[%dA" "$total_rows"
      fi
      first_draw=false

      for idx in "${!DISPLAY_LIST[@]}"; do
        local playing_tag=""
        if [ "$idx" -lt "$ITEM_COUNT" ]; then
          local cur_f="${FILE_LIST[$idx]}"
          if [ "$CURRENT_PLAYING_FILE" = "$INSTALL_DIR/sound/$cur_f" ] && [ -n "$PREVIEW_PID" ] && kill -0 "$PREVIEW_PID" 2>/dev/null; then
            playing_tag=" \033[1;33m▶ Playing...\033[0m"
          fi
        fi

        if [ "$idx" -eq "$current_idx" ]; then
          printf "\033[2K \033[1;32m ❯ [●] %s%s\033[0m\n" "${DISPLAY_LIST[$idx]}" "$playing_tag"
        else
          printf "\033[2K   [ ] %s%s\n" "${DISPLAY_LIST[$idx]}" "$playing_tag"
        fi
      done

      local key=""
      local key_rest=""
      IFS= read -rsn1 key < "$TTY_DEV" || true
      if [[ "$key" == $'\033' ]]; then
        read -rsn2 -t 1 key_rest < "$TTY_DEV" || true
        key+="$key_rest"
      fi

      case "$key" in
        $'\033[A'|"k"|"K")
          [ "$current_idx" -gt 0 ] && current_idx=$((current_idx - 1)) || current_idx=$((total_rows - 1))
          ;;
        $'\033[B'|"j"|"J")
          [ "$current_idx" -lt $((total_rows - 1)) ] && current_idx=$((current_idx + 1)) || current_idx=0
          ;;
        " ") # Space (toggle preview)
          if [ "$current_idx" -lt "$ITEM_COUNT" ]; then
            play_preview "$INSTALL_DIR/sound/${FILE_LIST[$current_idx]}"
          fi
          ;;
        "c"|"C") # Cycle category
          stop_preview
          local cat_idx=0
          for ci in "${!ALL_CATEGORIES[@]}"; do
            if [ "${ALL_CATEGORIES[$ci]}" = "$active_category" ]; then
              cat_idx=$ci
              break
            fi
          done
          cat_idx=$(( (cat_idx + 1) % ${#ALL_CATEGORIES[@]} ))
          active_category="${ALL_CATEGORIES[$cat_idx]}"
          break
          ;;
        "/") # Enter Search mode
          stop_preview
          tput cnorm 2>/dev/null || printf "\033[?25h"
          stty echo icanon 2>/dev/null || true
          echo ""
          printf "Search (empty to reset): "
          read -r search_query < "$TTY_DEV"
          tput civis 2>/dev/null || printf "\033[?25l"
          stty -echo -icanon 2>/dev/null || true
          break
          ;;
        "") # Enter (Confirm)
          stop_preview
          tput cnorm 2>/dev/null || printf "\033[?25h"
          stty echo icanon 2>/dev/null || true

          # Handle Action: Import Custom Sound
          if [ "$current_idx" -eq "$act_add_idx" ]; then
            echo ""
            echo "Enter audio file path or URL (or drag & drop file here):"
            read -r user_in < "$TTY_DEV"
            if add_sound_file "$user_in"; then
              chosen_file="$ADDED_SOUND_BASENAME"
            else
              return 1
            fi
          # Handle Action: Update Library
          elif [ "$current_idx" -eq "$act_update_idx" ]; then
            update_sound_library
            active_category="all"
            search_query=""
            break
          # Handle Action: Open Finder
          elif [ "$current_idx" -eq "$act_open_idx" ]; then
            open "$INSTALL_DIR/sound" 2>/dev/null || xdg-open "$INSTALL_DIR/sound" 2>/dev/null || true
            echo "✓ Opened sound library. Drop files here, then re-select."
            return 0
          else
            chosen_file="${FILE_LIST[$current_idx]}"
          fi

          # Link chosen sound
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
          return 0
          ;;
        "q"|"Q")
          stop_preview
          tput cnorm 2>/dev/null || printf "\033[?25h"
          stty echo icanon 2>/dev/null || true
          echo ""
          echo "Selection cancelled."
          return 0
          ;;
      esac
    done
  done
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

select_audio_flow "global"

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
echo "💡 Search sounds: Run 'alarm search <query>'"
echo "💡 Update from GitHub: Run 'alarm update'"
echo ""
