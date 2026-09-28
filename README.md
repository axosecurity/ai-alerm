# ai-alerm 🔔

> **Universal cross-platform task-completion audio alarms & notification hooks for AI coding agents.**  
> Plays your chosen zikir, chime, or alert sound automatically whenever an AI coding task finishes or goes idle.

[![Platforms](https://img.shields.io/badge/platforms-macOS%20%7C%20Linux%20%7C%20Debian%20%7C%20Arch%20%7C%20Windows%20%7C%20WSL-blue.svg)](README.md)
[![License](https://img.shields.io/badge/license-MIT-green.svg)](LICENSE)
[![Zero Dependencies](https://img.shields.io/badge/dependencies-zero-brightgreen.svg)](README.md)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](CONTRIBUTING.md)

---

## ⚡ 1-Click Installation (Frictionless & Instant)

> **Zero prompts, zero questions:** Simply paste the command for your operating system. It automatically downloads community sounds, configures all installed AI agents (Claude Code, OpenAI Codex, Google Antigravity, OpenCode), and plays a confirmation chime in under **2 seconds**.

### 1. Universal (All Platforms via npx / Node.js)
Works identically across **macOS, Linux, Debian, Arch, Windows, and WSL** with zero global setup:
```bash
npx github:axosecurity/ai-alerm
```

### 2. macOS & Linux (1-Line Terminal Curl)
Installs global binaries to `/opt/homebrew/bin` or `/usr/local/bin` and configures all detected agents:
```bash
curl -fsSL https://raw.githubusercontent.com/axosecurity/ai-alerm/master/install.sh | bash
```

### 3. Windows Native (PowerShell / Command Prompt)
For native Windows (PowerShell 5.1 / PowerShell Core):
```powershell
irm https://raw.githubusercontent.com/axosecurity/ai-alerm/master/install.ps1 | iex
```

### 4. Arch Linux & Manjaro (AUR)
```bash
yay -S ai-alerm-git
# or
paru -S ai-alerm-git
```

### 5. Git Clone (Manual)
```bash
git clone https://github.com/axosecurity/ai-alerm.git
cd ai-alerm && ./install.sh
```

---

## 🌐 Universal Platform Support Matrix

`ai-alerm` uses the native sound and notification subsystem built into each operating system, requiring **zero third-party daemons or heavy runtimes**:

| Operating System / Distro | Native Audio Engine | Native Desktop Banner / Toast | Global Storage Directory |
|---|---|---|---|
| 🍎 **macOS** (Apple Silicon / Intel) | `afplay -v <0.0-1.0>` | `osascript` (Notification Center) | `~/.ai-alarm/` |
| 🐧 **Debian / Ubuntu / Mint** | `paplay` (PulseAudio) / `pw-cat` / `aplay` | `notify-send` (`libnotify`) | `~/.ai-alarm/` |
| 🏹 **Arch Linux / Manjaro** | `paplay` / `pw-cat` (PipeWire) / `mpv` | `notify-send` | `~/.ai-alarm/` |
| 🎩 **Fedora / RHEL / CentOS** | `paplay` / `pw-cat` / `aplay` | `notify-send` | `~/.ai-alarm/` |
| 🏔️ **Alpine Linux** | `aplay` (ALSA) / `mpv` | `notify-send` | `~/.ai-alarm/` |
| 🪟 **Windows Native** (10/11) | PowerShell `MediaPlayer` / `SoundPlayer` | Windows WinRT Notification Toast | `%USERPROFILE%\.ai-alarm\` |
| 🐧 **WSL / WSL2** (Linux on Windows) | PulseAudio WSLg / Windows Audio Bridge | `notify-send` / Windows Toast Bridge | `~/.ai-alarm/` |

---

## 🤖 Multi-Agent Native Hooks

The installer auto-detects installed coding agents and registers non-blocking completion hooks:

| Agent | Config File | Trigger Event | Hook Command |
|---|---|---|---|
| **Claude Code** | `~/.claude/settings.json` | `hooks.Stop` | `alarm claude` |
| **OpenAI Codex** | `~/.codex/config.toml` | `[[hooks.Stop]]` | `alarm codex` |
| **Antigravity CLI** | `~/.gemini/antigravity-cli/hooks.json` & `~/.antigravity/hooks.json` | `task-finished-alarm.Stop` | `alarm antigravity` |
| **Antigravity IDE** | `~/.gemini/antigravity-ide/hooks.json` & `~/.antigravity-ide/hooks.json` | `task-finished-alarm.Stop` | `alarm antigravity` |
| **Gemini Ecosystem** | `~/.gemini/config/hooks.json` & `~/.gemini/antigravity/hooks.json` | `task-finished-alarm.Stop` | `alarm antigravity` |
| **OpenCode** | `~/.config/opencode/plugins/task-finished-alarm.ts` | `session.idle` | `alarm opencode` |
| **Workspace** | `.agents/hooks.json` | `task-finished-alarm.Stop` | `alarm` |

> [!TIP]
> **Complete Antigravity Ecosystem Support:** AI-Alarm configures hooks across all 3 user home interfaces: `~/.gemini/`, `~/.antigravity/`, and `~/.antigravity-ide/`. Whether you run Antigravity via CLI (`agy`), IDE extension, or Gemini core, task completion alerts trigger reliably.

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

## 🎧 Interactive Audio Selector (`alarm --select`)

Switch or preview alert sounds interactively with arrow keys:

```bash
alarm --select
```

### Controls & Features:
* **`[↑]` / `[↓]` (or `k` / `j`)**: Navigate sound library
* **`[Space]`**: Toggle live audio preview (`▶ Playing...` — downloads on demand if cloud-only)
* **`[d]`**: 🗑️ Delete local sound file from disk to reclaim space (instantly switches to `[☁ Cloud]`)
* **`[/]`**: Instant search / filter by keyword
* **`[c]`**: Cycle category filter (`[All]`, `[zikir]`, `[durood]`, `[istighfar]`, `[adhan]`, `[chime]`)
* **`[Enter]`**: Select and activate sound (downloads on demand if cloud-only)
* **`[q]`**: Cancel

```text
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 🔔 Select Alert Sound Track for: Global Default
 Filter: [zikir] (press 'c' to cycle) | Search: "forgiveness" (press '/' to filter)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
 Controls: [↑ / ↓] Navigate   [Space] ▶ Play   [Enter] Select   [d] 🗑 Delete file   [q] Cancel

 ❯ [●] Combined Istighfar + Durood (18.7s) [✓ Local] — [Astaghfirullah + Durood on Prophet]  ▶ Playing...
   [ ] Astaghfirullah Short (11.0s) [✓ Local] — [Astaghfirullah Rabbi min kulli zambin]
   [ ] Takbeer & Tahleel Zikir (16.4s) [✓ Local] — [Allahu Akbar and La ilaha illallah]
   [ ] Madinah Adhan Fajr (42.1s) [☁ Cloud] — [Beautiful morning call to prayer]
 ─────────────────────────────────────────────────────────────────────────
   [➕] Import / Add Custom Sound (File or URL)...
   [🧹] Prune Unused Sounds (Free Disk Space)
   [⬇️ ] Download All Community Sounds for Offline Use
   [🔄] Update Community Catalog from GitHub
   [📂] Open Sound Library in Finder / File Manager
```

### Direct Agent Shortcuts:
```bash
alarm --select claude         # Configure Claude Code's sound
alarm --select codex          # Configure OpenAI Codex's sound
alarm --select antigravity    # Configure Google Antigravity's sound
alarm --select opencode       # Configure OpenCode's sound
alarm --select global         # Configure Global Default fallback sound
```

---

## ☁️ Zero-Cost On-Demand Cloud Streaming & Storage Management

Even as the community audio library grows to hundreds of megabytes or gigabytes, `ai-alerm` keeps your local disk lean and clean using an **on-demand GitHub CDN architecture (100% free, zero paid services)**:

* **Thin Metadata Catalog:** Only lightweight metadata (`sounds.json`) and active alerts are stored locally.
* **On-Demand Streaming:** When you preview or select any `[☁ Cloud]` track, `ai-alerm` streams/downloads it directly from GitHub in under a second.
* **Single-Track Deletion:** Press `[d]` anytime in the selector or run `alarm remove <name>` to delete a local file and free disk space.
* **Smart Pruning (`alarm prune`):** Deletes all unused sound files in one click while **strictly protecting your active assigned agent alerts**.
* **Offline Full Pack (`alarm restore`):** Going on an offline flight? Download all community sounds locally with a single command.

```bash
# Check disk usage and local vs cloud count
alarm storage

# Free disk space (keeps active agent tracks safe)
alarm prune

# Download all sounds for offline use
alarm restore

# Remove a specific track
alarm remove custom-sound.mp3
```

---

## 🔔 Notification System & Webhook Manager

Fine-tune your audio levels, mute during meetings, configure desktop toasts, customize notification titles, or forward alerts to Slack and Discord webhooks:

```bash
# Volume Control (0 - 100%)
alarm volume 60        # Set alert volume to 60%
alarm volume           # View active volume and progress meter

# Instant Mute / Silent Mode
alarm mute             # Silence audio (desktop notification toasts still fire)
alarm unmute           # Restore audio alert playback

# Desktop Notification Banners & Webhooks
alarm notify           # Open notification status dashboard
alarm notify on        # Enable native desktop notification banners
alarm notify off       # Disable desktop toasts
alarm notify sound on  # Enable system chime inside toast banner
alarm notify sound off # Keep toast banner silent (only audio track plays)
alarm notify title "🚀 Build Finished"  # Set custom notification title
alarm notify webhook https://discord.com/api/webhooks/...  # Forward alerts to webhook
alarm notify webhook clear              # Disable webhook integration
alarm notify test      # Dispatch test notification toast & webhook immediately
```

> [!NOTE]
> You can also manage all notification settings interactively by running `alarm --select` and choosing **`🔔 [Manage Notification System & Webhook Alerts...]`**.

---

## 📊 Status & Configuration Dashboard

Inspect all audio volumes, notification settings, assigned tracks, and hook statuses across all installed agents:

```bash
alarm status
# or
alarm info
```

```text
╔═══════════════════════════════════════════════════════════════════╗
║                 AI-ALARM STATUS & CONFIGURATION                   ║
╚═══════════════════════════════════════════════════════════════════╝

  AUDIO SETTINGS
  ───────────────
  🔊 Volume:              80%  [████████░░]
  🔇 Mute State:          Active 🔊 (Audio enabled)

  NOTIFICATION SETTINGS
  ──────────────────────
  🔔 Desktop Banners:     Enabled 🔔
  🔊 Banner Chime:        Silent 🔇
  🏷️  Banner Title:        "AI-Alarm"
  🌐 Webhook URL:         None (Slack / Discord)

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
  🔵 Antigravity CLI:     ✓ Configured (~/.gemini/antigravity-cli/hooks.json)
  🔵 Antigravity IDE:     ✓ Configured (~/.gemini/antigravity-ide/hooks.json)
  🔵 Gemini Ecosystem:    ✓ Configured (~/.gemini/config/hooks.json)
  🟡 OpenCode:            ✓ Configured (~/.config/opencode/plugins/)
  📂 Project Workspace:   ○ None

  SYSTEM & PATHS
  ──────────────
  📁 Sound Library:       ~/.ai-alarm/sound (4 tracks)
  ⚙️  Config File:         ~/.ai-alarm/config.json
  🚀 Alarm Command:       /opt/homebrew/bin/alarm
```

---

## 📁 Global Sound Library (`~/.ai-alarm/sound/`)

`ai-alerm` stores all audio tracks in a persistent user directory (`~/.ai-alarm/sound/` or `%USERPROFILE%\.ai-alarm\sound\` on Windows):

```text
~/.ai-alarm/sound/
├── allahuakabar-laillahillah-zikir.mp3
├── istighfar.mp3
├── istighfar-shoddurud-zikir.mp3
├── shoddurud-sharif.mp3
└── sounds.json
```

### Adding Custom Sounds (3 Easy Ways):

1. **Direct CLI Import (Local file or URL):**
   ```bash
   alarm add ~/Downloads/my-sound.mp3
   # or directly download from the web:
   alarm add https://example.com/peaceful-alert.mp3
   ```

2. **Open in Finder / File Manager:**
   ```bash
   alarm open
   ```
   Opens `~/.ai-alarm/sound/` in macOS Finder or Linux File Manager to drag & drop tracks directly!

3. **In the Interactive Menu:**
   Run `alarm --select` and pick `➕ [Import / Add Custom Sound...]` to paste or drag-and-drop a file path.

Supported formats: **`.mp3`, `.wav`, `.m4a`, `.aac`, `.ogg`, `.flac`, `.aiff`**

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

Want to contribute your favorite zikir, adhan, recitation, or chime?  
We welcome community contributions! Please read our [**Contributing Guide (CONTRIBUTING.md)**](CONTRIBUTING.md) to add your sound in 3 simple steps.

---

## 🗑️ Clean Uninstallation

Completely remove all agent hooks, binaries, symlinks, and configurations without leftover clutter:

```bash
alarm uninstall
# or
./install.sh --uninstall
```

---

## 🛠 Complete Commands Reference

| Command | Description |
|---|---|
| `alarm` | Plays current alarm sound (auto-detects caller agent). |
| `alarm <agent>` | Plays custom sound for a specific agent (`claude`, `codex`, `antigravity`, `opencode`). |
| `alarm status` / `info` | Displays configuration dashboard and agent hook health. |
| `alarm storage` / `cache` | Displays disk usage breakdown and local vs cloud track counts. |
| `alarm prune` / `clean` | Deletes all unused sound files to save space, keeping active agent alerts safe. |
| `alarm restore` / `download-all` | Downloads the complete community sound pack from GitHub for offline use. |
| `alarm volume [0-100]` | Adjusts or inspects playback volume with a visual bar. |
| `alarm mute` | Silences audio alerts while retaining desktop toasts. |
| `alarm unmute` | Restores audio alert playback. |
| `alarm notify [on\|off]` | Enables or disables native desktop notification banners. |
| `alarm notify sound [on\|off]` | Toggles system chime sound inside desktop toast notifications. |
| `alarm notify title <text>` | Customizes notification banner title (e.g. "Task Done"). |
| `alarm notify webhook <url\|clear>` | Sets or clears incoming webhook URL (Slack / Discord). |
| `alarm notify test` | Sends an immediate test desktop toast and webhook alert. |
| `alarm --select` / `-s` | Launches the interactive TUI audio selector (stream, download, delete, configure notifications). |
| `alarm search <query>` | Searches sounds by title, description, or tag. |
| `alarm update` / `sync` | Downloads latest community catalog from GitHub. |
| `alarm set <sound> [agent]` | Directly sets sound for an agent (downloads on demand if cloud-only). |
| `alarm add <path\|url>` | Imports custom sound or downloads from URL. |
| `alarm open` | Opens sound library directory in Finder / File Manager. |
| `alarm remove <name>` | Removes a sound file from local disk (`rm`, `delete`). |
| `alarm uninstall` | Cleanly removes all agent hooks, binaries, and configurations. |
| `alarm --help` / `-ask` | Opens the comprehensive CLI manual. |
| `notify` | Sends task-completion notifications to your configured Slack webhook. |

---

## 📄 License

MIT License © 2026 [axosecurity](https://github.com/axosecurity)
