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
    --status                Show status and configuration dashboard
    --search <query>        Search sound library by name, tag, or description
    --update                Update community sound library from GitHub (sync)
    --add <path|url>        Import custom sound to ~/.ai-alarm/sound/
    --open                  Open sound library in Finder / File Manager
    --remove <name>         Remove sound track from library
    --project               Also write hook to project workspace (.agents/hooks.json)
    --uninstall             Cleanly remove all hooks, binaries, and data
    --help | -help          Show this documentation manual (-h, --ask, -ask)
EOF
  exit 0
}

show_status_dashboard() {
  node -e '
    const fs = require("fs");
    const path = require("path");
    const home = process.env.HOME;
    const installDir = path.join(home, ".ai-alarm");
    const soundDir = path.join(installDir, "sound");
    const configFile = path.join(installDir, "config.json");

    let config = { volume: 80, muted: false, desktop_notifications: true };
    if (fs.existsSync(configFile)) {
      try { config = Object.assign(config, JSON.parse(fs.readFileSync(configFile, "utf8"))); } catch(e){}
    }

    const vol = Math.max(0, Math.min(100, Number(config.volume) !== undefined ? Number(config.volume) : 80));
    const filled = Math.round(vol / 10);
    const bar = "█".repeat(filled) + "░".repeat(10 - filled);

    let catalog = {};
    const catFile = path.join(soundDir, "sounds.json");
    if (fs.existsSync(catFile)) {
      try { catalog = JSON.parse(fs.readFileSync(catFile, "utf8")); } catch(e){}
    }

    function getSoundInfo(linkName) {
      const linkPath = path.join(installDir, linkName);
      if (fs.existsSync(linkPath)) {
        try {
          const target = fs.readlinkSync(linkPath);
          const base = path.basename(target);
          const meta = catalog[base] || {};
          let info = `\x1b[1;32m${base}\x1b[0m`;
          if (meta.title && meta.title !== base) info += ` ("${meta.title}")`;
          if (meta.duration) info += ` (${meta.duration})`;
          if (meta.category) info += ` [\x1b[36m${meta.category}\x1b[0m]`;
          return info;
        } catch(e){}
      }
      return null;
    }

    const defaultSound = getSoundInfo("alarm_sound.mp3") || "\x1b[33m(none configured)\x1b[0m";
    const claudeSound = getSoundInfo("alarm_sound_claude.mp3") || `\x1b[2m(uses Global Default)\x1b[0m`;
    const codexSound = getSoundInfo("alarm_sound_codex.mp3") || `\x1b[2m(uses Global Default)\x1b[0m`;
    const antigravitySound = getSoundInfo("alarm_sound_antigravity.mp3") || `\x1b[2m(uses Global Default)\x1b[0m`;
    const opencodeSound = getSoundInfo("alarm_sound_opencode.mp3") || `\x1b[2m(uses Global Default)\x1b[0m`;

    let soundCount = 0;
    if (fs.existsSync(soundDir)) {
      soundCount = fs.readdirSync(soundDir).filter(f => /\.(mp3|wav|m4a|aac|ogg|flac|aiff)$/i.test(f)).length;
    }

    const claudePath = path.join(home, ".claude", "settings.json");
    let claudeStatus = "\x1b[31m○ Not installed\x1b[0m";
    if (fs.existsSync(claudePath)) {
      try {
        const c = JSON.parse(fs.readFileSync(claudePath, "utf8"));
        const hasHook = (c.hooks?.Stop || []).some(item => (item.hooks || []).some(h => (h.command || "").includes("alarm")));
        claudeStatus = hasHook ? "\x1b[1;32m✓ Configured\x1b[0m (~/.claude/settings.json)" : "\x1b[33m○ Not configured\x1b[0m";
      } catch(e) { claudeStatus = "\x1b[33m○ Error parsing\x1b[0m"; }
    }

    const codexPath = path.join(home, ".codex", "config.toml");
    let codexStatus = "\x1b[31m○ Not installed\x1b[0m";
    if (fs.existsSync(codexPath)) {
      const content = fs.readFileSync(codexPath, "utf8");
      const hasHook = content.includes("[[hooks.Stop]]") && content.includes("alarm");
      codexStatus = hasHook ? "\x1b[1;32m✓ Configured\x1b[0m (~/.codex/config.toml)" : "\x1b[33m○ Not configured\x1b[0m";
    }

    // Antigravity & Gemini status checks across all 3 interfaces
    const agyCliPaths = [
      path.join(home, ".gemini", "antigravity-cli", "hooks.json"),
      path.join(home, ".antigravity", "hooks.json")
    ];
    const agyIdePaths = [
      path.join(home, ".gemini", "antigravity-ide", "hooks.json"),
      path.join(home, ".antigravity-ide", "hooks.json")
    ];
    const geminiCorePaths = [
      path.join(home, ".gemini", "config", "hooks.json"),
      path.join(home, ".gemini", "antigravity", "hooks.json")
    ];

    function checkHookList(paths) {
      for (const p of paths) {
        if (fs.existsSync(p)) {
          try {
            const h = JSON.parse(fs.readFileSync(p, "utf8"));
            if (h["task-finished-alarm"]) return { configured: true, path: p };
          } catch(e){}
        }
      }
      return { configured: false };
    }

    const cliCheck = checkHookList(agyCliPaths);
    const ideCheck = checkHookList(agyIdePaths);
    const coreCheck = checkHookList(geminiCorePaths);

    const agyCliStatus = cliCheck.configured
      ? `\x1b[1;32m✓ Configured\x1b[0m (${cliCheck.path.replace(home, "~")})`
      : `\x1b[33m○ Not configured\x1b[0m`;

    const agyIdeStatus = ideCheck.configured
      ? `\x1b[1;32m✓ Configured\x1b[0m (${ideCheck.path.replace(home, "~")})`
      : `\x1b[33m○ Not configured\x1b[0m`;

    const geminiCoreStatus = coreCheck.configured
      ? `\x1b[1;32m✓ Configured\x1b[0m (${coreCheck.path.replace(home, "~")})`
      : `\x1b[33m○ Not configured\x1b[0m`;

    const opencodePath = path.join(home, ".config", "opencode", "plugins", "task-finished-alarm.ts");
    let opencodeStatus = fs.existsSync(opencodePath) ? "\x1b[1;32m✓ Configured\x1b[0m (~/.config/opencode/plugins/)" : "\x1b[31m○ Not installed\x1b[0m";

    const wsPath = path.join(process.cwd(), ".agents", "hooks.json");
    let wsStatus = "\x1b[2m○ None\x1b[0m";
    if (fs.existsSync(wsPath)) {
      try {
        const w = JSON.parse(fs.readFileSync(wsPath, "utf8"));
        if (w["task-finished-alarm"]) wsStatus = "\x1b[1;32m✓ Configured\x1b[0m (.agents/hooks.json)";
      } catch(e){}
    }

    const notifTitle = config.notification_title ? String(config.notification_title) : "AI-Alarm";

    console.log(`
╔═══════════════════════════════════════════════════════════════════╗
║                 AI-ALARM STATUS & CONFIGURATION                   ║
╚═══════════════════════════════════════════════════════════════════╝

  \x1b[1mAUDIO SETTINGS\x1b[0m
  ───────────────
  🔊 Volume:              \x1b[1;33m${vol}%\x1b[0m  [\x1b[32m${bar}\x1b[0m]
  🔇 Mute State:          ${config.muted ? "\x1b[1;31mMuted 🔇 (Silent mode)\x1b[0m" : "\x1b[1;32mActive 🔊 (Audio enabled)\x1b[0m"}

  \x1b[1mNOTIFICATION SETTINGS\x1b[0m
  ──────────────────────
  🔔 Desktop Banners:     ${config.desktop_notifications !== false ? "\x1b[1;32mEnabled 🔔\x1b[0m" : "\x1b[33mDisabled 🔕\x1b[0m"}
  🔊 Banner Chime:        ${config.notification_sound ? "\x1b[1;32mEnabled 🔊\x1b[0m" : "\x1b[2mSilent 🔇\x1b[0m"}
  🏷️  Banner Title:        "${notifTitle}"
  🌐 Webhook URL:         ${config.webhook_url ? `\x1b[1;36m${config.webhook_url}\x1b[0m` : "\x1b[2mNone (Slack / Discord)\x1b[0m"}

  \x1b[1mASSIGNED SOUNDS\x1b[0m
  ───────────────
  🌐 Global Default:      ${defaultSound}
  🟣 Claude Code:         ${claudeSound}
  🟢 OpenAI Codex:        ${codexSound}
  🔵 Antigravity:         ${antigravitySound}
  🟡 OpenCode:            ${opencodeSound}

  \x1b[1mAGENT HOOK INTEGRATIONS\x1b[0m
  ───────────────────────
  🟣 Claude Code:         ${claudeStatus}
  🟢 OpenAI Codex:        ${codexStatus}
  🔵 Antigravity CLI:     ${agyCliStatus}
  🔵 Antigravity IDE:     ${agyIdeStatus}
  🔵 Gemini Ecosystem:    ${geminiCoreStatus}
  🟡 OpenCode:            ${opencodeStatus}
  📂 Project Workspace:   ${wsStatus}

  \x1b[1mSYSTEM & PATHS\x1b[0m
  ──────────────
  📁 Sound Library:       ${soundDir} (${soundCount} tracks)
  ⚙️  Config File:         ${configFile}
  🚀 Alarm Command:       ${process.argv[1] || "alarm"}
`);
  ' "$(which alarm 2>/dev/null || echo "$INSTALL_DIR/alarm")"
}

run_uninstall() {
  local auto_yes=false
  if [ "${1:-}" = "-y" ] || [ "${1:-}" = "--yes" ]; then
    auto_yes=true
  fi

  echo ""
  echo "╔═══════════════════════════════════════════════════════════╗"
  echo "║                  AI-ALARM UNINSTALLER                     ║"
  echo "╚═══════════════════════════════════════════════════════════╝"
  echo ""

  if [ "$auto_yes" = false ] && [ -t 0 -o -r "/dev/tty" ]; then
    local TTY_DEV="/dev/tty"
    [ ! -r "$TTY_DEV" ] && TTY_DEV="/dev/stdin"
    printf "Are you sure you want to uninstall AI-Alarm and remove all agent hooks? [y/N]: "
    read -r confirm < "$TTY_DEV" || confirm="n"
    if [[ ! "$confirm" =~ ^[yY](es)?$ ]]; then
      echo "Uninstall canceled."
      return 0
    fi
  fi

  echo ""
  echo "→ Removing agent hooks..."

  # 1. Claude Code
  node -e '
    const fs = require("fs");
    const path = require("path");
    const p = path.join(process.env.HOME, ".claude", "settings.json");
    if (!fs.existsSync(p)) process.exit(0);
    try {
      let s = JSON.parse(fs.readFileSync(p, "utf8"));
      if (s.hooks && s.hooks.Stop) {
        s.hooks.Stop = s.hooks.Stop.filter(item => {
          if (!item.hooks) return true;
          item.hooks = item.hooks.filter(h => !(h.command && h.command.includes("alarm")));
          return item.hooks.length > 0;
        });
        if (s.hooks.Stop.length === 0) delete s.hooks.Stop;
        if (Object.keys(s.hooks).length === 0) delete s.hooks;
        fs.writeFileSync(p, JSON.stringify(s, null, 2) + "\n");
        console.log("  ✓ Removed Claude Code Stop hook (~/.claude/settings.json)");
      }
    } catch(e){}
  ' 2>/dev/null || true

  # 2. OpenAI Codex
  node -e '
    const fs = require("fs");
    const path = require("path");
    const p = path.join(process.env.HOME, ".codex", "config.toml");
    if (!fs.existsSync(p)) process.exit(0);
    try {
      let content = fs.readFileSync(p, "utf8");
      if (content.includes("alarm")) {
        const regex = /\[\[hooks\.Stop\]\][\s\S]*?command\s*=\s*".*?alarm.*?"[\s\S]*?(?=\n\[|\n$|$)/g;
        content = content.replace(regex, "");
        const stateRegex = /\[hooks\.state\."[^"]*:stop:[^"]*"\]\ntrusted_hash\s*=\s*"[^"]*"\n?/g;
        content = content.replace(stateRegex, "");
        content = content.replace(/\n{3,}/g, "\n\n");
        fs.writeFileSync(p, content);
        console.log("  ✓ Removed OpenAI Codex Stop hook (~/.codex/config.toml)");
      }
    } catch(e){}
  ' 2>/dev/null || true

  # 3. Google Antigravity & Gemini Ecosystem
  node -e '
    const fs = require("fs");
    const path = require("path");
    const home = process.env.HOME || process.env.USERPROFILE;
    const allHooks = [
      path.join(home, ".gemini", "config", "hooks.json"),
      path.join(home, ".gemini", "antigravity", "hooks.json"),
      path.join(home, ".gemini", "antigravity-cli", "hooks.json"),
      path.join(home, ".gemini", "antigravity-ide", "hooks.json"),
      path.join(home, ".antigravity", "hooks.json"),
      path.join(home, ".antigravity-ide", "hooks.json")
    ];
    let removedAny = false;
    for (const p of allHooks) {
      if (fs.existsSync(p)) {
        try {
          if (fs.lstatSync(p).isSymbolicLink()) {
            fs.unlinkSync(p);
            removedAny = true;
          } else {
            let h = JSON.parse(fs.readFileSync(p, "utf8"));
            if (h["task-finished-alarm"]) {
              delete h["task-finished-alarm"];
              fs.writeFileSync(p, JSON.stringify(h, null, 2) + "\n");
              removedAny = true;
            }
          }
        } catch(e){}
      }
    }
    if (removedAny) console.log("  ✓ Removed Antigravity & Gemini hooks across all interfaces");
  ' 2>/dev/null || true

  # 4. OpenCode
  local opencode_file="$HOME/.config/opencode/plugins/task-finished-alarm.ts"
  if [ -f "$opencode_file" ]; then
    rm -f "$opencode_file"
    echo "  ✓ Removed OpenCode plugin hook ($opencode_file)"
  fi

  # 5. Workspace
  if [ -f ".agents/hooks.json" ]; then
    node -e '
      const fs = require("fs");
      const p = ".agents/hooks.json";
      try {
        let h = JSON.parse(fs.readFileSync(p, "utf8"));
        if (h["task-finished-alarm"]) {
          delete h["task-finished-alarm"];
          fs.writeFileSync(p, JSON.stringify(h, null, 2) + "\n");
          console.log("  ✓ Removed workspace hook (.agents/hooks.json)");
        }
      } catch(e){}
    ' 2>/dev/null || true
  fi

  echo ""
  echo "→ Removing global binaries..."
  for b in "/opt/homebrew/bin" "/usr/local/bin" "$HOME/.local/bin"; do
    if [ -f "$b/alarm" ] || [ -L "$b/alarm" ]; then
      rm -f "$b/alarm"
      echo "  ✓ Removed $b/alarm"
    fi
    if [ -f "$b/notify" ] || [ -L "$b/notify" ]; then
      rm -f "$b/notify"
      echo "  ✓ Removed $b/notify"
    fi
  done

  # 6. Prompt to remove data directory (~/.ai-alarm)
  local remove_data=false
  if [ "$auto_yes" = true ]; then
    remove_data=true
  elif [ -t 0 -o -r "/dev/tty" ]; then
    local TTY_DEV="/dev/tty"
    [ ! -r "$TTY_DEV" ] && TTY_DEV="/dev/stdin"
    printf "\nDo you also want to delete the sound library & config in ~/.ai-alarm? [y/N]: "
    read -r del_data < "$TTY_DEV" || del_data="n"
    if [[ "$del_data" =~ ^[yY](es)?$ ]]; then
      remove_data=true
    fi
  fi

  if [ "$remove_data" = true ]; then
    rm -rf "$INSTALL_DIR"
    echo "  ✓ Removed $INSTALL_DIR directory."
  else
    echo "  ℹ Kept sound library and configurations at $INSTALL_DIR"
  fi

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " 🎉 AI-Alarm has been successfully uninstalled!"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo ""
}

case "${1:-}" in
  --help|-help|-h|--ask|-ask|help)
    show_help
    ;;
  --status|status|info|--info)
    show_status_dashboard
    exit 0
    ;;
  --uninstall|uninstall)
    run_uninstall "${2:-}"
    exit 0
    ;;
esac

# -------------------------------------------------------------
# Global Sound Library Sync
# -------------------------------------------------------------
mkdir -p "$INSTALL_DIR/sound"
GITHUB_RAW="https://raw.githubusercontent.com/axosecurity/ai-alerm/master"

if [ -d "$SCRIPT_DIR/sound" ]; then
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
else
  # Running remotely via curl ... | bash
  echo "→ Downloading latest ai-alerm files from GitHub..."
  curl -fsSL "$GITHUB_RAW/alarm" -o "$INSTALL_DIR/alarm" 2>/dev/null || true
  curl -fsSL "$GITHUB_RAW/notify" -o "$INSTALL_DIR/notify" 2>/dev/null || true
  curl -fsSL "$GITHUB_RAW/install.sh" -o "$INSTALL_DIR/install.sh" 2>/dev/null || true
  curl -fsSL "$GITHUB_RAW/sound/sounds.json" -o "$INSTALL_DIR/sound/sounds.json" 2>/dev/null || true

  for track in "allahuakabar-laillahillah-zikir.mp3" "istighfar.mp3" "shoddurud-sharif.mp3" "istighfar-shoddurud-zikir.mp3"; do
    if [ ! -f "$INSTALL_DIR/sound/$track" ]; then
      echo "  → Downloading $track..."
      curl -fsSL "$GITHUB_RAW/sound/$track" -o "$INSTALL_DIR/sound/$track" 2>/dev/null || true
    fi
  done
fi
chmod +x "$INSTALL_DIR/alarm" "$INSTALL_DIR/notify" "$INSTALL_DIR/install.sh" 2>/dev/null || true

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
      if (!localCatalog[filename]) {
        newCount++;
      }
      localCatalog[filename] = meta;
    }

    fs.writeFileSync(localJsonPath, JSON.stringify(localCatalog, null, 2) + "\n");
    console.log(`✓ Sound catalog updated! ${Object.keys(localCatalog).length} community tracks available (${newCount} new).`);
    console.log(`💡 Sounds stream on demand when selected. To cache all sounds offline, run: alarm restore`);
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

# Download sound track on-demand from GitHub (0-cost CDN)
download_sound_track() {
  local filename="$1"
  mkdir -p "$INSTALL_DIR/sound"
  if [ ! -f "$INSTALL_DIR/sound/$filename" ]; then
    printf "\033[2K \033[1;36m ↓ Downloading %s from GitHub (0 cost)...\033[0m\n" "$filename"
    curl -fsSL "$GITHUB_RAW/sound/$filename" -o "$INSTALL_DIR/sound/$filename" 2>/dev/null || return 1
    printf "\033[1A"
  fi
  return 0
}

# Remove / Delete sound track from local storage
if [ "${1:-}" = "--remove" ] || [ "${1:-}" = "remove" ] || [ "${1:-}" = "rm" ] || [ "${1:-}" = "--delete" ] || [ "${1:-}" = "delete" ]; then
  TARGET_RM="$2"
  FOUND=false
  shopt -s nullglob nocaseglob
  for f in "$INSTALL_DIR/sound"/*; do
    base="$(basename "$f")"
    if [ "$base" = "$TARGET_RM" ] || [ "${base%.*}" = "$TARGET_RM" ]; then
      is_assigned=false
      for link in "$INSTALL_DIR"/alarm_sound*.mp3; do
        if [ -L "$link" ] && [ "$(basename "$(readlink "$link" 2>/dev/null)")" = "$base" ]; then
          is_assigned=true
          break
        fi
      done
      if [ "$is_assigned" = true ]; then
        echo "🛡️  Cannot remove '$base': currently assigned to an active agent alert."
        echo "💡 Reassign the agent to another sound first before deleting this track."
        FOUND=true
        continue
      fi
      rm -f "$f"
      echo "✓ Removed sound from local storage: $f"
      FOUND=true
    fi
  done
  if [ "$FOUND" = false ]; then
    echo "⚠ Sound '$TARGET_RM' not found in $INSTALL_DIR/sound"
  fi
  exit 0
fi

# Prune unused sounds (keep active assigned agent tracks, delete the rest)
prune_sounds() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " 🧹 Pruning Unused Sounds (Freeing Disk Space)..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  node -e '
    const fs = require("fs");
    const path = require("path");
    const installDir = process.argv[1];
    const soundDir = path.join(installDir, "sound");

    if (!fs.existsSync(soundDir)) {
      console.log("Sound directory is empty.");
      process.exit(0);
    }

    const assigned = new Set();
    for (const f of fs.readdirSync(installDir)) {
      if (f.startsWith("alarm_sound")) {
        try {
          const target = fs.readlinkSync(path.join(installDir, f));
          assigned.add(path.basename(target));
        } catch(e){}
      }
    }

    const files = fs.readdirSync(soundDir).filter(f => /\.(mp3|wav|m4a|aac|ogg|flac|aiff)$/i.test(f));
    let deletedCount = 0;
    let reclaimedBytes = 0;

    for (const file of files) {
      if (!assigned.has(file)) {
        const fullPath = path.join(soundDir, file);
        try {
          const stats = fs.statSync(fullPath);
          reclaimedBytes += stats.size;
          fs.unlinkSync(fullPath);
          deletedCount++;
          console.log(`  ✓ Removed unused track: ${file}`);
        } catch(e){}
      }
    }

    const reclaimedMb = (reclaimedBytes / (1024 * 1024)).toFixed(2);
    console.log(`\n🎉 Pruning complete! Removed ${deletedCount} unused sound(s), reclaimed ${reclaimedMb} MB.`);
    console.log(`🛡️  Kept ${assigned.size} active sound(s) assigned to your AI agents.`);
    console.log(`💡 You can re-download any community sound on demand anytime via \"alarm --select\".`);
  ' "$INSTALL_DIR"
}

if [ "${1:-}" = "--prune" ] || [ "${1:-}" = "prune" ] || [ "${1:-}" = "clean" ] || [ "${1:-}" = "--clean" ]; then
  prune_sounds
  exit 0
fi

# Show storage & cache breakdown
show_storage_info() {
  node -e '
    const fs = require("fs");
    const path = require("path");
    const installDir = process.argv[1];
    const soundDir = path.join(installDir, "sound");

    let catalog = {};
    const catPath = path.join(soundDir, "sounds.json");
    if (fs.existsSync(catPath)) {
      try { catalog = JSON.parse(fs.readFileSync(catPath, "utf8")); } catch(e){}
    }

    const assigned = new Set();
    if (fs.existsSync(installDir)) {
      for (const f of fs.readdirSync(installDir)) {
        if (f.startsWith("alarm_sound")) {
          try {
            const target = fs.readlinkSync(path.join(installDir, f));
            assigned.add(path.basename(target));
          } catch(e){}
        }
      }
    }

    let localCount = 0;
    let totalBytes = 0;
    if (fs.existsSync(soundDir)) {
      const files = fs.readdirSync(soundDir).filter(f => /\.(mp3|wav|m4a|aac|ogg|flac|aiff)$/i.test(f));
      localCount = files.length;
      for (const f of files) {
        try { totalBytes += fs.statSync(path.join(soundDir, f)).size; } catch(e){}
      }
    }

    const totalCatalog = Object.keys(catalog).length;
    const mb = (totalBytes / (1024 * 1024)).toFixed(2);

    console.log(`
╔═══════════════════════════════════════════════════════════════════╗
║                 AI-ALARM STORAGE & CACHE BREAKDOWN                ║
╚═══════════════════════════════════════════════════════════════════╝

  Local Sounds Stored:    ${localCount} tracks (${mb} MB on disk)
  Active Agent Sounds:    ${assigned.size} tracks (protected from pruning)
  Total Catalog Sounds:   ${totalCatalog} community tracks available on GitHub

  💡 Free up disk space:   alarm prune
  💡 Download all sounds:  alarm restore
  💡 Pick sound on-demand: alarm --select
`);
  ' "$INSTALL_DIR"
}

if [ "${1:-}" = "--storage" ] || [ "${1:-}" = "storage" ] || [ "${1:-}" = "cache" ] || [ "${1:-}" = "--cache" ]; then
  show_storage_info
  exit 0
fi

# Restore / Download all community sounds
restore_all_sounds() {
  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " ⬇️  Downloading Full Community Sound Pack..."
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  node -e '
    const fs = require("fs");
    const path = require("path");
    const { execSync } = require("child_process");
    const soundDir = path.join(process.argv[1], "sound");
    const githubRaw = process.argv[2];

    const catPath = path.join(soundDir, "sounds.json");
    let catalog = {};
    if (fs.existsSync(catPath)) {
      try { catalog = JSON.parse(fs.readFileSync(catPath, "utf8")); } catch(e){}
    }

    const tracks = Object.keys(catalog);
    let downloaded = 0;
    for (const t of tracks) {
      const dest = path.join(soundDir, t);
      if (!fs.existsSync(dest)) {
        console.log(`  → Downloading ${t}...`);
        try {
          execSync(`curl -fsSL "${githubRaw}/sound/${t}" -o "${dest}"`);
          downloaded++;
        } catch(e){}
      }
    }
    console.log(`\n🎉 Restore complete! Downloaded ${downloaded} track(s). All community sounds are cached locally.`);
  ' "$INSTALL_DIR" "$GITHUB_RAW"
}

if [ "${1:-}" = "--restore" ] || [ "${1:-}" = "restore" ] || [ "${1:-}" = "download-all" ] || [ "${1:-}" = "--download-all" ]; then
  restore_all_sounds
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

  local VOL=80
  if [ -f "$INSTALL_DIR/config.json" ]; then
    VOL=$(node -e 'try{const c=JSON.parse(require("fs").readFileSync(process.argv[1],"utf8"));console.log(String(c.volume!==undefined?c.volume:80));}catch(e){console.log("80");}' "$INSTALL_DIR/config.json" 2>/dev/null || echo 80)
  fi
  local RATIO
  RATIO=$(awk -v v="$VOL" 'BEGIN { printf "%.2f", v / 100 }')

  if command -v afplay >/dev/null 2>&1; then
    (afplay -v "$RATIO" "$audio_file") &
    PREVIEW_PID=$!
  elif command -v paplay >/dev/null 2>&1; then
    local PAPLAY_VOL=$(( VOL * 65536 / 100 ))
    (paplay --volume="$PAPLAY_VOL" "$audio_file") &
    PREVIEW_PID=$!
  elif command -v mpv >/dev/null 2>&1; then
    (mpv --no-video --volume="$VOL" "$audio_file" >/dev/null 2>&1) &
    PREVIEW_PID=$!
  elif command -v ffplay >/dev/null 2>&1; then
    (ffplay -nodisp -autoexit -volume "$VOL" "$audio_file" >/dev/null 2>&1) &
    PREVIEW_PID=$!
  elif command -v aplay >/dev/null 2>&1; then
    (aplay "$audio_file") &
    PREVIEW_PID=$!
  fi
}

# -------------------------------------------------------------
# Interactive Notification System & Webhook Settings Manager
# -------------------------------------------------------------
configure_notifications_interactive() {
  local TTY_DEV="/dev/tty"
  [ ! -r "$TTY_DEV" ] && TTY_DEV="/dev/stdin"

  local ALARM_CMD="${TARGET_ALARM_BIN:-$INSTALL_DIR/alarm}"
  [ ! -x "$ALARM_CMD" ] && ALARM_CMD="alarm"

  while true; do
    local notify_state
    notify_state="$(node -e '
      const fs = require("fs");
      const path = require("path");
      const cfgPath = path.join(process.argv[1], "config.json");
      let cfg = { desktop_notifications: true, notification_sound: false, notification_title: "AI-Alarm", webhook_url: "" };
      if (fs.existsSync(cfgPath)) {
        try { cfg = Object.assign(cfg, JSON.parse(fs.readFileSync(cfgPath, "utf8"))); } catch(e){}
      }
      console.log(JSON.stringify(cfg));
    ' "$INSTALL_DIR" 2>/dev/null || echo '{"desktop_notifications":true,"notification_sound":false,"notification_title":"AI-Alarm","webhook_url":""}')"

    local d_on s_on title webhook
    d_on="$(node -e 'console.log(JSON.parse(process.argv[1]).desktop_notifications !== false)' "$notify_state" 2>/dev/null || echo "true")"
    s_on="$(node -e 'console.log(Boolean(JSON.parse(process.argv[1]).notification_sound))' "$notify_state" 2>/dev/null || echo "false")"
    title="$(node -e 'console.log(JSON.parse(process.argv[1]).notification_title || "AI-Alarm")' "$notify_state" 2>/dev/null || echo "AI-Alarm")"
    webhook="$(node -e 'console.log(JSON.parse(process.argv[1]).webhook_url || "")' "$notify_state" 2>/dev/null || echo "")"

    local d_label="\033[31mDisabled 🔕\033[0m"
    [ "$d_on" = "true" ] && d_label="\033[1;32mEnabled 🔔\033[0m"

    local s_label="\033[2mSilent 🔇\033[0m"
    [ "$s_on" = "true" ] && s_label="\033[1;32mEnabled 🔊\033[0m"

    local w_label="\033[2mNone (Slack / Discord)\033[0m"
    [ -n "$webhook" ] && w_label="\033[1;36m$webhook\033[0m"

    local n_opts=(
      "🔔 Desktop Notification Banners: $d_label [Toggle]"
      "🔊 Banner Audio Chime:           $s_label [Toggle]"
      "🏷️  Custom Banner Title:          \"$title\" [Change]"
      "🌐 Webhook URL:                  $w_label [Edit/Clear]"
      "🚀 Send Test Notification Toast & Webhook"
      "↩️  Back to Sound Selection"
    )

    local cur=0
    local first=true
    tput civis 2>/dev/null || printf "\033[?25l"
    stty -echo -icanon 2>/dev/null || true

    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " 🔔 Notification System & Webhook Manager"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo " Controls: [↑ / ↓] Navigate   [Enter] Select / Toggle   [q] Back"
    echo ""

    while true; do
      if [ "$first" = false ]; then
        printf "\033[%dA" "${#n_opts[@]}"
      fi
      first=false

      for i in "${!n_opts[@]}"; do
        if [ "$i" -eq "$cur" ]; then
          printf "\033[2K \033[1;32m ❯ [●] %b\033[0m\n" "${n_opts[$i]}"
        else
          printf "\033[2K   [ ] %b\n" "${n_opts[$i]}"
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
        $'\033[A'|"k"|"K") [ "$cur" -gt 0 ] && cur=$((cur - 1)) || cur=$((${#n_opts[@]} - 1)) ;;
        $'\033[B'|"j"|"J") [ "$cur" -lt $((${#n_opts[@]} - 1)) ] && cur=$((cur + 1)) || cur=0 ;;
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
      0) # Toggle Banners
        if [ "$d_on" = "true" ]; then
          "$ALARM_CMD" notify off 2>/dev/null || true
        else
          "$ALARM_CMD" notify on 2>/dev/null || true
        fi
        ;;
      1) # Toggle Chime
        if [ "$s_on" = "true" ]; then
          "$ALARM_CMD" notify sound off 2>/dev/null || true
        else
          "$ALARM_CMD" notify sound on 2>/dev/null || true
        fi
        ;;
      2) # Change Title
        echo ""
        printf "Enter custom notification title (e.g. 'Task Complete'): "
        read -r new_title < "$TTY_DEV"
        if [ -n "$new_title" ]; then
          "$ALARM_CMD" notify title "$new_title" 2>/dev/null || true
        fi
        ;;
      3) # Edit Webhook
        echo ""
        echo "Enter incoming webhook URL (Slack / Discord), or 'clear' to disable:"
        read -r new_hook < "$TTY_DEV"
        if [ -n "$new_hook" ]; then
          "$ALARM_CMD" notify webhook "$new_hook" 2>/dev/null || true
        fi
        ;;
      4) # Test
        echo ""
        "$ALARM_CMD" notify test 2>/dev/null || true
        echo "Press Enter to continue..."
        read -r _ < "$TTY_DEV"
        ;;
      5) # Back
        return 0
        ;;
    esac
  done
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

      const onDisk = new Set(fs.existsSync(soundDir) ? fs.readdirSync(soundDir).filter(f => /\.(mp3|wav|m4a|aac|ogg|flac|aiff)$/i.test(f)) : []);
      const allKeys = Array.from(new Set([...onDisk, ...Object.keys(catalog)]));
      const categories = new Set(["all"]);

      for (const f of allKeys) {
        if (catalog[f] && catalog[f].category) categories.add(catalog[f].category.toLowerCase());
      }

      const list = [];
      for (const f of allKeys) {
        const isLocal = onDisk.has(f);
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
        if (isLocal) {
          display += ` \x1b[32m[✓ Local]\x1b[0m`;
        } else {
          display += ` \x1b[36m[☁ Cloud]\x1b[0m`;
        }
        if (desc) display += ` — [${desc}]`;

        list.push({ file: f, title, display, category: cat, isLocal });
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
    local act_notify_idx=${#DISPLAY_LIST[@]}
    DISPLAY_LIST+=("🔔 [Manage Notification System & Webhook Alerts...]")
    local act_prune_idx=${#DISPLAY_LIST[@]}
    DISPLAY_LIST+=("🧹 [Prune Unused Sounds (Free Disk Space)]")
    local act_restore_idx=${#DISPLAY_LIST[@]}
    DISPLAY_LIST+=("⬇️  [Download All Community Sounds for Offline Use]")
    local act_update_idx=${#DISPLAY_LIST[@]}
    DISPLAY_LIST+=("🔄 [Update Community Catalog from GitHub]")
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
    echo " Controls: [↑ / ↓] Navigate   [Space] ▶ Play   [Enter] Select   [d] 🗑 Delete file   [q] Cancel"
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
        " ") # Space (toggle preview, downloading on demand if cloud)
          if [ "$current_idx" -lt "$ITEM_COUNT" ]; then
            local target_play="${FILE_LIST[$current_idx]}"
            if [ ! -f "$INSTALL_DIR/sound/$target_play" ]; then
              download_sound_track "$target_play"
            fi
            play_preview "$INSTALL_DIR/sound/$target_play"
          fi
          ;;
        "d"|"D") # Delete local sound file from disk to save space
          if [ "$current_idx" -lt "$ITEM_COUNT" ]; then
            local target_del="${FILE_LIST[$current_idx]}"
            local is_del_assigned=false
            for link in "$INSTALL_DIR"/alarm_sound*.mp3; do
              if [ -L "$link" ] && [ "$(basename "$(readlink "$link" 2>/dev/null)")" = "$target_del" ]; then
                is_del_assigned=true
                break
              fi
            done
            if [ "$is_del_assigned" = true ]; then
              continue
            fi
            if [ -f "$INSTALL_DIR/sound/$target_del" ]; then
              stop_preview
              rm -f "$INSTALL_DIR/sound/$target_del"
              [ "$CURRENT_PLAYING_FILE" = "$INSTALL_DIR/sound/$target_del" ] && CURRENT_PLAYING_FILE=""
              break
            fi
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
          # Handle Action: Manage Notifications & Webhooks
          elif [ "$current_idx" -eq "$act_notify_idx" ]; then
            configure_notifications_interactive
            break
          # Handle Action: Prune Unused Sounds
          elif [ "$current_idx" -eq "$act_prune_idx" ]; then
            prune_sounds
            echo "Press Enter to return to menu..."
            read -r _ < "$TTY_DEV"
            break
          # Handle Action: Download All Sounds
          elif [ "$current_idx" -eq "$act_restore_idx" ]; then
            restore_all_sounds
            echo "Press Enter to return to menu..."
            read -r _ < "$TTY_DEV"
            break
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
            if [ ! -f "$INSTALL_DIR/sound/$chosen_file" ]; then
              download_sound_track "$chosen_file"
            fi
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

INTERACTIVE_MODE=false
if [ "${1:-}" = "-i" ] || [ "${1:-}" = "--interactive" ] || [ "${1:-}" = "--select" ]; then
  INTERACTIVE_MODE=true
fi

if [ "$INTERACTIVE_MODE" = true ]; then
  select_audio_flow "global"
else
  if [ ! -L "$INSTALL_DIR/alarm_sound.mp3" ]; then
    shopt -s nullglob nocaseglob
    FIRST_MP3=( "$INSTALL_DIR"/sound/*.{mp3,wav,m4a,aac,ogg,flac,aiff} )
    if [ -f "${FIRST_MP3[0]}" ]; then
      ln -sf "sound/$(basename "${FIRST_MP3[0]}")" "$INSTALL_DIR/alarm_sound.mp3"
      echo "✓ Activated default sound: $(basename "${FIRST_MP3[0]}")"
    fi
  else
    echo "✓ Keeping current default sound."
  fi
fi

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

# -------------------------------------------------------------
# Agent Selection & Consent Menu
# -------------------------------------------------------------
select_agents_to_configure() {
  local TTY_DEV="/dev/tty"
  [ ! -r "$TTY_DEV" ] && TTY_DEV="/dev/stdin"

  local has_claude=false
  local has_codex=false
  local has_antigravity=false
  local has_opencode=false
  local has_workspace=false

  ([ -d "$HOME/.claude" ] || command -v claude >/dev/null 2>&1) && has_claude=true
  ([ -d "$HOME/.codex" ] || command -v codex >/dev/null 2>&1) && has_codex=true
  ([ -d "$HOME/.gemini" ] || command -v agy >/dev/null 2>&1) && has_antigravity=true
  ([ -d "$HOME/.config/opencode" ] || command -v opencode >/dev/null 2>&1) && has_opencode=true
  [ -d ".agents" ] && has_workspace=true

  local agent_labels=(
    "🚀 All Detected Agents (Recommended)"
    "🟣 Claude Code (~/.claude/settings.json)"
    "🟢 OpenAI Codex (~/.codex/config.toml)"
    "🔵 Google Antigravity (CLI, 2.0, IDE)"
    "🟡 OpenCode (~/.config/opencode/plugins/)"
    "📁 Current Project Workspace (.agents/hooks.json)"
  )

  local agent_status=(
    ""
    "$([ "$has_claude" = true ] && echo "(detected)" || echo "(not installed)")"
    "$([ "$has_codex" = true ] && echo "(detected)" || echo "(not installed)")"
    "$([ "$has_antigravity" = true ] && echo "(detected)" || echo "(not installed)")"
    "$([ "$has_opencode" = true ] && echo "(detected)" || echo "(not installed)")"
    "$([ "$has_workspace" = true ] && echo "(found .agents)" || echo "(optional)")"
  )

  local checked=(true "$has_claude" "$has_codex" "$has_antigravity" "$has_opencode" false)
  local cur=0
  local total=${#agent_labels[@]}
  local first=true

  echo ""
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " 🤖 Select AI Coding Agents to Configure Hooks For:"
  echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  echo " Controls: [↑ / ↓] Navigate   [Space] Toggle checkbox   [Enter] Confirm"
  echo ""

  tput civis 2>/dev/null || printf "\033[?25l"
  stty -echo -icanon 2>/dev/null || true

  while true; do
    if [ "$first" = false ]; then
      printf "\033[%dA" "$total"
    fi
    first=false

    for i in "${!agent_labels[@]}"; do
      local mark=" "
      [ "${checked[$i]}" = true ] && mark="✔"
      local color="\033[0m"
      [ "${checked[$i]}" = true ] && color="\033[1;32m"
      local status_info="${agent_status[$i]}"
      [ -n "$status_info" ] && status_info=" \033[2m$status_info\033[0m"

      if [ "$i" -eq "$cur" ]; then
        printf "\033[2K  \033[1;32m❯\033[0m [%b%s\033[0m] %s%b\n" "$color" "$mark" "${agent_labels[$i]}" "$status_info"
      else
        printf "\033[2K    [%b%s\033[0m] %s%b\n" "$color" "$mark" "${agent_labels[$i]}" "$status_info"
      fi
    done

    local key=""
    local rest=""
    IFS= read -rsn1 key < "$TTY_DEV" || true
    if [[ "$key" == $'\033' ]]; then
      read -rsn2 -t 1 rest < "$TTY_DEV" || true
      key+="$rest"
    fi

    case "$key" in
      $'\033[A'|"k"|"K") [ "$cur" -gt 0 ] && cur=$((cur - 1)) || cur=$((total - 1)) ;;
      $'\033[B'|"j"|"J") [ "$cur" -lt $((total - 1)) ] && cur=$((cur + 1)) || cur=0 ;;
      " ")
        if [ "$cur" -eq 0 ]; then
          local new_state=true
          [ "${checked[0]}" = true ] && new_state=false
          checked[0]=$new_state
          checked[1]=$([ "$has_claude" = true ] && echo "$new_state" || echo false)
          checked[2]=$([ "$has_codex" = true ] && echo "$new_state" || echo false)
          checked[3]=$([ "$has_antigravity" = true ] && echo "$new_state" || echo false)
          checked[4]=$([ "$has_opencode" = true ] && echo "$new_state" || echo false)
        else
          if [ "${checked[$cur]}" = true ]; then
            checked[$cur]=false
            checked[0]=false
          else
            checked[$cur]=true
          fi
        fi
        ;;
      "") break ;;
    esac
  done

  tput cnorm 2>/dev/null || printf "\033[?25h"
  stty echo icanon 2>/dev/null || true

  INSTALL_CLAUDE="${checked[1]}"
  INSTALL_CODEX="${checked[2]}"
  INSTALL_ANTIGRAVITY="${checked[3]}"
  INSTALL_OPENCODE="${checked[4]}"
  INSTALL_WORKSPACE="${checked[5]}"
}

INSTALL_CLAUDE=true
INSTALL_CODEX=true
INSTALL_ANTIGRAVITY=true
INSTALL_OPENCODE=true
INSTALL_WORKSPACE=false

if [ "$INTERACTIVE_MODE" = true ] && [ -t 0 -o -r "/dev/tty" ]; then
  select_agents_to_configure
fi

echo ""
echo "→ Configuring selected AI coding agent hooks..."

# --- A. Claude Code ---
if [ "$INSTALL_CLAUDE" = true ]; then
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
  else
    echo "  ℹ Claude Code not detected on system."
  fi
else
  echo "  ℹ Claude Code skipped (unselected)."
fi

# --- B. OpenAI Codex ---
if [ "$INSTALL_CODEX" = true ]; then
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
  else
    echo "  ℹ OpenAI Codex not detected on system."
  fi
else
  echo "  ℹ OpenAI Codex skipped (unselected)."
fi

# --- C. Google Antigravity & Gemini Ecosystem (CLI, Antigravity 2.0, IDE) ---
if [ "$INSTALL_ANTIGRAVITY" = true ]; then
  if [ -d "$HOME/.gemini" ] || [ -d "$HOME/.antigravity" ] || [ -d "$HOME/.antigravity-ide" ] || command -v agy >/dev/null 2>&1; then
    mkdir -p "$HOME/.gemini/config"
    node -e '
      const fs = require("fs");
      const path = require("path");
      const home = process.env.HOME || process.env.USERPROFILE;
      const hooksPath = path.join(home, ".gemini", "config", "hooks.json");

      function writeHook(targetPath) {
        try {
          fs.mkdirSync(path.dirname(targetPath), { recursive: true });
          let h = {};
          if (fs.existsSync(targetPath)) {
            try { h = JSON.parse(fs.readFileSync(targetPath, "utf8")); } catch(e){}
          }
          h["task-finished-alarm"] = {
            Stop: [
              {
                type: "command",
                command: process.argv[1] + " antigravity",
                timeout: 15
              }
            ]
          };
          fs.writeFileSync(targetPath, JSON.stringify(h, null, 2) + "\n");
          return true;
        } catch(e) { return false; }
      }

      writeHook(hooksPath);
      console.log("  ✓ Antigravity global hook configured: ~/.gemini/config/hooks.json");

      // Configure .gemini subdirs
      const flavors = ["antigravity", "antigravity-cli", "antigravity-ide"];
      for (const f of flavors) {
        const fDir = path.join(home, ".gemini", f);
        if (fs.existsSync(fDir)) {
          const fHook = path.join(fDir, "hooks.json");
          try {
            if (!fs.existsSync(fHook)) {
              fs.symlinkSync(hooksPath, fHook);
            } else {
              writeHook(fHook);
            }
          } catch(e) { writeHook(fHook); }
        }
      }

      // Configure standalone ~/.antigravity and ~/.antigravity-ide
      const standalones = [
        path.join(home, ".antigravity"),
        path.join(home, ".antigravity-ide")
      ];
      for (const sDir of standalones) {
        if (fs.existsSync(sDir)) {
          const sHook = path.join(sDir, "hooks.json");
          try {
            if (!fs.existsSync(sHook)) {
              fs.symlinkSync(hooksPath, sHook);
            } else {
              writeHook(sHook);
            }
          } catch(e) { writeHook(sHook); }
          console.log("  ✓ Antigravity standalone hook configured: " + sHook.replace(home, "~"));
        }
      }
    ' "$TARGET_ALARM_BIN" 2>/dev/null || echo "  ⚠ Antigravity hook configuration skipped."
  else
    echo "  ℹ Google Antigravity not detected on system."
  fi
else
  echo "  ℹ Google Antigravity skipped (unselected)."
fi

# --- D. OpenCode ---
if [ "$INSTALL_OPENCODE" = true ]; then
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
  else
    echo "  ℹ OpenCode not detected on system."
  fi
else
  echo "  ℹ OpenCode skipped (unselected)."
fi

# --- E. Project Workspace (.agents/hooks.json) ---
if [ "$INSTALL_WORKSPACE" = true ]; then
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

# Initialize config.json if not present
if [ ! -f "$INSTALL_DIR/config.json" ]; then
  cat > "$INSTALL_DIR/config.json" << 'EOF'
{
  "volume": 80,
  "muted": false,
  "desktop_notifications": true
}
EOF
fi

echo ""
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║        🎉 AI-ALARM INSTALLED & READY TO USE!              ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo "  ✓ Audio alerts enabled (volume: 80%)"
echo "  ✓ Desktop notification toasts enabled"
echo "  ✓ Global command ready: $TARGET_ALARM_BIN"
echo ""
echo "💡 QUICK COMMANDS:"
echo "  * Test alert sound:     alarm"
echo "  * Change sound track:   alarm --select"
echo "  * Adjust volume:        alarm volume 60"
echo "  * Status dashboard:     alarm status"
echo ""

# Play quick confirmation alert in background
( "$TARGET_ALARM_BIN" >/dev/null 2>&1 & )
