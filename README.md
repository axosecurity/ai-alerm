# ai-alerm 🔔

Cross-agent task-completion audio alarms and notification hooks for AI coding agents.

Plays your chosen zikir or alarm sound automatically whenever an AI coding task finishes or goes idle. Supports distinct custom sounds for each coding agent or a shared global sound.

---

## ⚡ 1-Click Installation (Zero Setup)

Run directly from GitHub using `npx` (no npm publishing or package registry needed):

```bash
npx github:axosecurity/ai-alerm
```

Or clone and run locally:

```bash
git clone https://github.com/axosecurity/ai-alerm.git
cd ai-alerm && ./install.sh
```

---

## 📖 Help & Manual (`-help` or `-ask`)

You can view the full interactive manual and command reference at any time:

```bash
alarm -help
# or
alarm -ask
# or
alarm --help
```

---

## 📁 Global Sound Library (`~/.ai-alarm/sound/`)

Following the design pattern of modern Unix CLI tools (like Starship, Oh-My-Zsh, Neovim), `ai-alerm` stores all audio tracks in a persistent global user directory:

```text
~/.ai-alarm/sound/
├── allahuakabar-laillahillah-zikir.mp3
├── istighfar.mp3
├── istighfar-shoddurud-zikir.mp3
└── shoddurud-sharif.mp3
```

### Adding Custom Sounds (3 Easy Ways):

1. **Direct CLI Import (Local file or URL):**
   ```bash
   alarm add ~/Downloads/my-sound.mp3
   # or directly from the web:
   alarm add https://example.com/chime.wav
   ```

2. **Open in Finder / File Manager:**
   ```bash
   alarm open
   ```
   Opens `~/.ai-alarm/sound/` in macOS Finder so you can simply drag & drop your audio files!

3. **In the Interactive Menu:**
   Run `alarm --select` and pick `➕ [Import / Add Custom Sound...]` to drag & drop right into the terminal!

Supported formats: **`.mp3`, `.wav`, `.m4a`, `.aac`, `.ogg`, `.flac`, `.aiff`**

---

## 🎧 Interactive Audio Selector

Choose or change your alert sound at any time without typing:

```bash
alarm --select
```

### Two-Step Selection:
1. **Choose Target Agent:**
   - 🌐 Global Default (All Agents)
   - 🟣 Claude Code
   - 🟢 OpenAI Codex
   - 🔵 Google Antigravity
   - 🟡 OpenCode

2. **Pick Sound with Rich Controls & Filter:**
   - **`[↑]` / `[↓]` (or `k` / `j`)**: Navigate tracks
   - **`[Space]`**: Toggle live audio preview (shows `▶ Playing...`)
   - **`[/]`**: Type keyword to instant-search
   - **`[c]`**: Cycle category filter (`[All]`, `[zikir]`, `[durood]`, `[istighfar]`)
   - **`[Enter]`**: Select and activate
   - **`[q]`**: Cancel

```text
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 🔔 Select Alert Sound Track for: Global Default
 Filter: [zikir] (press 'c' to cycle) | Search: "forgiveness" (press '/' to filter)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Controls: [↑ / ↓] Navigate   [Space] ▶ Play/Stop Preview   [Enter] Select   [q] Cancel

 ❯ [●] Combined Istighfar + Durood (18.7s) — [Astaghfirullah + Durood on Prophet]  ▶ Playing...
   [ ] Astaghfirullah Short (11.0s) — [Astaghfirullah Rabbi min kulli zambin]
   [ ] Takbeer & Tahleel Zikir (16.4s) — [Allahu Akbar and La ilaha illallah]
 ─────────────────────────────────────────────────────────────────────────
   [➕] Import / Add Custom Sound (File or URL)...
   [🔄] Update Community Sounds from GitHub
   [📂] Open Sound Library in Finder
```

### Direct Shortcuts:
```bash
alarm --select claude         # Set sound specifically for Claude Code
alarm --select codex          # Set sound specifically for OpenAI Codex
alarm --select antigravity    # Set sound specifically for Google Antigravity
alarm --select opencode       # Set sound specifically for OpenCode
alarm --select global         # Set the global default fallback sound
```

---

## 🔍 Search & Community Sync

```bash
# Search sounds by keyword, title, tag, or description
alarm search forgiveness
alarm search prophet

# Download newly added community sounds from GitHub
alarm update

# Set sound directly without opening the menu
alarm set istighfar.mp3 codex
```

---

## 🤝 Contributing Sounds

Want to add your favorite zikir, adhan, or chime to `ai-alerm`?
We welcome community contributions! Please read our [**Contributing Guide (CONTRIBUTING.md)**](CONTRIBUTING.md) to add your sound in 3 simple steps.

---

## 🤖 Multi-Agent Native Hooks

The installer auto-detects installed coding agents and registers native completion hooks:

| Agent | Config File | Trigger Event | Hook Command |
|---|---|---|---|
| **Claude Code** | `~/.claude/settings.json` | `hooks.Stop` | `alarm claude` |
| **OpenAI Codex** | `~/.codex/config.toml` | `[[hooks.Stop]]` | `alarm codex` |
| **Google Antigravity** | `~/.gemini/config/hooks.json` | `task-finished-alarm.Stop` | `alarm antigravity` |
| **OpenCode** | `~/.config/opencode/plugins/task-finished-alarm.ts` | `session.idle` | `alarm opencode` |

### How Sound Resolution Works:
```text
Agent finishes task (e.g. Claude Code)
         │
         ▼
Does custom sound exist? (~/.ai-alarm/alarm_sound_claude.mp3)
  ├── YES ──▶ Plays Claude's custom sound
  └── NO  ──▶ Falls back to Global Default (~/.ai-alarm/alarm_sound.mp3)
```

---

---

## 🎛️ Volume, Mute & Notification Banners

Customize audio levels, quiet down when on a call, or enable native OS desktop toasts:

```bash
# Volume control (0 - 100%)
alarm volume 60        # Set volume to 60%
alarm volume           # View current volume and visual progress bar

# Instant mute / silent mode
alarm mute             # Mute audio (desktop notification toasts will still fire)
alarm unmute           # Unmute audio and restore playback

# Native desktop notification banners (macOS Notification Center / Linux notify-send)
alarm notify on        # Enable desktop notification toasts
alarm notify off       # Disable desktop toasts
alarm notify           # Check desktop notification status
```

---

## 📊 Status & Configuration Dashboard

View your active audio volume, mute state, desktop banners, assigned sounds per agent, and hook health across all AI tools:

```bash
alarm status
# or
./install.sh --status
```

```text
╔═══════════════════════════════════════════════════════════════════╗
║                 AI-ALARM STATUS & CONFIGURATION                   ║
╚═══════════════════════════════════════════════════════════════════╝

  AUDIO SETTINGS
  ───────────────
  🔊 Volume:              80%  [████████░░]
  🔇 Mute State:          Active 🔊 (Audio enabled)
  🔔 Desktop Banners:     Enabled 🔔 (Native notification toasts)

  ASSIGNED SOUNDS
  ───────────────
  🌐 Global Default:      allahuakabar-laillahillah-zikir.mp3 ("Takbeer & Tahleel Zikir") (16.4s) [zikir]
  🟣 Claude Code:         shoddurud-sharif.mp3 ("Choto Durood Sharif") (7.7s) [durood]
  🟢 OpenAI Codex:        istighfar.mp3 ("Astaghfirullah (Short Istighfar)") (11.0s) [istighfar]
  🔵 Antigravity:         (uses Global Default)
  🟡 OpenCode:            (uses Global Default)

  AGENT HOOK INTEGRATIONS
  ───────────────────────
  🟣 Claude Code:         ✓ Configured (~/.claude/settings.json)
  🟢 OpenAI Codex:        ✓ Configured (~/.codex/config.toml)
  🔵 Google Antigravity:  ✓ Configured (~/.gemini/config/hooks.json)
  🟡 OpenCode:            ✓ Configured (~/.config/opencode/plugins/)
  📂 Project Workspace:   ○ None

  SYSTEM & PATHS
  ──────────────
  📁 Sound Library:       ~/.ai-alarm/sound (4 tracks)
  ⚙️  Config File:         ~/.ai-alarm/config.json
  🚀 Alarm Command:       /opt/homebrew/bin/alarm
```

---

## 🗑️ Clean Uninstallation

Completely remove all agent hooks, symlinks, binaries, and configurations with zero leftover clutter:

```bash
alarm uninstall
# or
./install.sh --uninstall
```

---

## 🛠 Commands Reference

* **`alarm`**: Plays current alarm sound (auto-detects calling agent).
* **`alarm <agent>`**: Plays custom sound for a specific agent (`claude`, `codex`, `antigravity`, `opencode`).
* **`alarm status`** / **`info`**: Displays configuration dashboard and agent hook health.
* **`alarm volume [0-100]`**: Adjusts or inspects alert volume with a visual bar.
* **`alarm mute`**: Silences audio playback while retaining notification toasts.
* **`alarm unmute`**: Restores audio alerts.
* **`alarm notify [on|off]`**: Controls native OS desktop notification banners.
* **`alarm --select`** / **`-s`**: Launches the interactive audio selector.
* **`alarm search <query>`**: Searches sounds by title, description, or tag.
* **`alarm update`** / **`sync`**: Downloads latest community sounds from GitHub.
* **`alarm set <sound> [agent]`**: Directly sets sound for an agent without menu.
* **`alarm add <path|url>`**: Imports a custom sound or downloads from URL.
* **`alarm open`**: Opens sound library directory in Finder.
* **`alarm remove <name>`**: Removes a sound file from library.
* **`alarm uninstall`**: Cleanly removes all agent hooks, binaries, and configurations.
* **`alarm -help`** / **`-ask`** / **`--help`**: Opens the comprehensive CLI manual.
* **`notify`**: Sends task-completion notifications to your configured Slack webhook.

---

## 💻 Requirements

* **macOS** (`afplay`) or **Linux** (`paplay`, `mpv`, `ffplay`, or `aplay`).
* **Node.js** (for running via `npx`).

