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

2. **Pick Sound with Arrow Keys:**
   - **`[↑]` / `[↓]` (or `k` / `j`)**: Navigate tracks
   - **`[Space]`**: Test-play a live preview
   - **`[Enter]`**: Select and activate
   - **`[q]`**: Cancel

```text
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 🔔 Select Sound Track for: Claude Code
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Controls: [↑ / ↓] Navigate   [Space] Preview   [Enter] Select   [q] Cancel

   [ ] allahuakabar-laillahillah-zikir
 ❯ [●] istighfar-shoddurud-zikir
   [ ] istighfar
   [ ] shoddurud-sharif
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

## 🛠 Commands Reference

* **`alarm`**: Plays current alarm sound (auto-detects calling agent).
* **`alarm <agent>`**: Plays custom sound for a specific agent (`claude`, `codex`, `antigravity`, `opencode`).
* **`alarm --select`** / **`-s`**: Launches the interactive audio selector.
* **`alarm --list`** / **`-l`**: Lists all available sound files in the global sound library.
* **`alarm -help`** / **`-ask`** / **`--help`**: Opens the comprehensive CLI manual.
* **`notify`**: Sends task-completion notifications to your configured Slack webhook.

---

## 💻 Requirements

* **macOS** (`afplay`) or **Linux** (`paplay`, `mpv`, `ffplay`, or `aplay`).
* **Node.js** (for running via `npx`).
