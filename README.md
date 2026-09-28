# ai-alerm 🔔

Cross-agent task-completion audio alarms and notification hooks for AI coding agents.

Plays your chosen zikir or alarm sound automatically whenever an AI coding task finishes or goes idle.

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

## 🎧 Interactive Audio Selector

During setup, you do not need to type anything. An interactive terminal menu lets you choose your alert:

* **`[↑]` / `[↓]` (or `k` / `j`)**: Navigate between sounds
* **`[Space]`**: Test-play a live preview
* **`[Enter]`**: Confirm and apply selection
* **`[q]`**: Quit

```text
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 🔔 Select Alarm / Zikir Sound for Task Completion
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Controls:
   [↑ / ↓] Navigate      [Space] Preview sound
   [Enter] Confirm       [q] Quit

   [ ] allahuakabar-laillahillah-zikir
 ❯ [●] istighfar-shoddurud-zikir
   [ ] istighfar
   [ ] shoddurud-sharif
```

### Switch sound anytime:
```bash
alarm --select
```

---

## 🤖 Supported AI Coding Agents & Native Hooks

The installer auto-detects installed coding agents and registers native completion hooks:

| Agent | Hook Configuration | Trigger Event |
|---|---|---|
| **Claude Code** | `~/.claude/settings.json` | `hooks.Stop` |
| **OpenAI Codex** | `~/.codex/config.toml` | `[[hooks.Stop]]` |
| **Google Antigravity** | `~/.gemini/config/hooks.json` | `task-finished-alarm.Stop` |
| **OpenCode** | `~/.config/opencode/plugins/task-finished-alarm.ts` | `session.idle` |

Whenever any agent finishes its turn, `alarm` is executed automatically.

---

## 📁 Repository Structure

All sound tracks are kept flat directly in the `sound/` directory:

```text
ai-alerm/
├── bin/
│   └── cli.js                         # NPX CLI runner
├── sound/                             # Audio tracks directory
│   ├── allahuakabar-laillahillah-zikir.mp3
│   ├── istighfar.mp3
│   ├── istighfar-shoddurud-zikir.mp3
│   └── shoddurud-sharif.mp3
├── alarm                              # Alarm player script (cross-platform)
├── notify                             # Slack notification script
├── alarm_sound.mp3                    # Symlink pointing to active sound
├── install.sh                         # Master interactive installer & hook setup
├── package.json                       # NPX package descriptor
└── README.md
```

---

## 🛠 Commands

* **`alarm`**: Plays the active alarm track.
* **`alarm --select`**: Launches the interactive audio picker.
* **`alarm --list`**: Lists available sound tracks.
* **`notify`**: Sends task-completion notifications to your configured Slack webhook.

## 💻 Requirements

* **macOS** (`afplay`) or **Linux** (`paplay`, `mpv`, `ffplay`, or `aplay`).
* **Node.js** (for running via `npx`).
