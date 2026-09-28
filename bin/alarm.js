#!/usr/bin/env node

/**
 * ai-alerm: Universal Cross-Platform Task Completion Audio & Notification Engine
 * Supports: macOS, Linux (Debian, Arch, Fedora, Alpine), Windows (10/11), and WSL
 */

const fs = require('fs');
const path = require('path');
const { spawn, exec, execSync } = require('child_process');
const os = require('os');
const https = require('https');
const http = require('http');

const isWin = process.platform === 'win32';
const homeDir = isWin ? (process.env.USERPROFILE || os.homedir()) : (process.env.HOME || os.homedir());
const INSTALL_DIR = path.join(homeDir, '.ai-alarm');
const SOUND_DIR = process.env.AI_ALARM_SOUND_DIR && fs.existsSync(process.env.AI_ALARM_SOUND_DIR)
  ? process.env.AI_ALARM_SOUND_DIR
  : path.join(INSTALL_DIR, 'sound');
const CONFIG_FILE = path.join(INSTALL_DIR, 'config.json');

// Ensure directories exist
try {
  fs.mkdirSync(SOUND_DIR, { recursive: true });
} catch (e) {}

// Configuration Management
function loadConfig() {
  const defaults = { volume: 80, muted: false, desktop_notifications: true };
  if (fs.existsSync(CONFIG_FILE)) {
    try {
      return Object.assign(defaults, JSON.parse(fs.readFileSync(CONFIG_FILE, 'utf8')));
    } catch (e) {}
  }
  return defaults;
}

function saveConfig(cfg) {
  try {
    fs.mkdirSync(INSTALL_DIR, { recursive: true });
    fs.writeFileSync(CONFIG_FILE, JSON.stringify(cfg, null, 2) + '\n');
  } catch (e) {}
}

function getVolumeBar(vol) {
  const filled = Math.min(10, Math.max(0, Math.round((vol + 5) / 10)));
  return '█'.repeat(filled) + '░'.repeat(10 - filled);
}

// Sound Metadata Catalog
function loadCatalog() {
  const catPath = path.join(SOUND_DIR, 'sounds.json');
  if (fs.existsSync(catPath)) {
    try {
      return JSON.parse(fs.readFileSync(catPath, 'utf8'));
    } catch (e) {}
  }
  return {};
}

// Help Manual
function showHelp() {
  console.log(`
╔═══════════════════════════════════════════════════════════════════╗
║                      AI-ALARM MANUAL & HELP                       ║
║  Universal Cross-Platform Task Completion Audio & Notifications   ║
╚═══════════════════════════════════════════════════════════════════╝

USAGE:
    alarm [COMMAND | AGENT | OPTIONS]

COMMANDS & OPTIONS:
    alarm                     Play current alarm sound (auto-detects agent)
    alarm <agent>             Play custom sound for agent (claude, codex, antigravity, opencode)
    alarm status              Show configuration dashboard & agent hook health
    alarm storage             Show disk usage and local vs cloud sound breakdown (cache)
    alarm prune               Delete all unused sounds to free disk space (clean)
    alarm restore             Download all community sounds for offline use (download-all)
    alarm volume [0-100]      View or adjust alert playback volume (0-100%)
    alarm mute                Silence audio alerts (desktop notifications still fire)
    alarm unmute              Restore audio alerts
    alarm notify [on|off]     Toggle native desktop notification banners
    alarm --select [agent]    Interactive sound selector (-s)
    alarm search <query>      Search sounds by title, description, or tag
    alarm update              Download latest community catalog from GitHub (sync)
    alarm set <sound> [agent] Directly activate a sound track without menu
    alarm --list              List all audio files in the global sound library (-l)
    alarm add <path|url>      Import a custom sound file or download from URL
    alarm open                Open the sound library directory in File Manager
    alarm remove <name>       Remove a sound file from local disk (rm, delete)
    alarm uninstall           Cleanly remove all hooks, binaries, and data
    alarm --help | -help      Show this documentation manual (-h, --ask, -ask)

SUPPORTED PLATFORMS:
    macOS (afplay), Linux (paplay/pw-cat/aplay/mpv), Windows 10/11 (PowerShell/WinRT), WSL

EXAMPLES:
    alarm                     # Triggers alarm (used by hooks)
    alarm volume 70           # Set volume to 70%
    alarm mute                # Enter silent mode
    alarm claude              # Play Claude's custom sound
    alarm --select            # Launch interactive picker
    alarm status              # Check health & configuration
`);
  process.exit(0);
}

// Desktop Notification Dispatcher
function sendDesktopNotification(agent) {
  const cfg = loadConfig();
  if (cfg.desktop_notifications === false) return;

  const agentTitles = {
    claude: 'Claude Code',
    codex: 'OpenAI Codex',
    antigravity: 'Google Antigravity',
    opencode: 'OpenCode'
  };
  const title = agentTitles[agent] || 'AI Agent';
  const msg = `Task completed by ${title}!`;

  if (process.platform === 'darwin') {
    spawn('osascript', ['-e', `display notification "${msg}" with title "AI-Alarm" subtitle "Task Finished" sound name ""`], {
      detached: true,
      stdio: 'ignore'
    }).unref();
  } else if (process.platform === 'win32') {
    const psScript = `
      try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
        $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
        $xml = [xml]$template.GetXml()
        $xml.GetElementsByTagName("text")[0].AppendChild($xml.CreateTextNode("AI-Alarm")) > $null
        $xml.GetElementsByTagName("text")[1].AppendChild($xml.CreateTextNode("${msg}")) > $null
        $toastXml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $toastXml.LoadXml($xml.OuterXml)
        $toast = [Windows.UI.Notifications.ToastNotification]::new($toastXml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("AI-Alarm").Show($toast)
      } catch {}
    `;
    spawn('powershell', ['-NoProfile', '-NonInteractive', '-Command', psScript], {
      detached: true,
      stdio: 'ignore'
    }).unref();
  } else {
    // Linux / BSD
    spawn('notify-send', ['AI-Alarm', msg, '--icon=dialog-information'], {
      detached: true,
      stdio: 'ignore'
    }).unref();
  }
}

// Locate Sound File
function resolveAudioFile(agent) {
  const extensions = ['.mp3', '.wav', '.m4a', '.aac', '.ogg', '.flac', '.aiff'];
  
  // 1. Agent custom sound in ~/.ai-alarm
  if (agent) {
    for (const ext of extensions) {
      const candidate = path.join(INSTALL_DIR, `alarm_sound_${agent}${ext}`);
      if (fs.existsSync(candidate)) return candidate;
    }
  }

  // 2. Global default sound in ~/.ai-alarm
  for (const ext of extensions) {
    const candidate = path.join(INSTALL_DIR, `alarm_sound${ext}`);
    if (fs.existsSync(candidate)) return candidate;
  }

  // 3. First sound in sound library
  if (fs.existsSync(SOUND_DIR)) {
    const files = fs.readdirSync(SOUND_DIR).filter(f => /\.(mp3|wav|m4a|aac|ogg|flac|aiff)$/i.test(f));
    if (files.length > 0) {
      return path.join(SOUND_DIR, files[0]);
    }
  }

  return null;
}

// Audio Playback Engine
function playAudio(soundPath, callback, detached = false) {
  const cfg = loadConfig();
  if (cfg.muted) {
    if (callback) callback();
    return;
  }

  const vol = Math.max(0, Math.min(100, Number(cfg.volume) || 80));
  const ratio = (vol / 100).toFixed(2);

  if (process.platform === 'darwin') {
    const p = spawn('afplay', ['-v', ratio, soundPath], { detached, stdio: 'ignore' });
    if (detached) {
      p.unref();
      if (callback) callback();
    } else {
      p.on('exit', () => callback && callback());
    }
  } else if (process.platform === 'win32') {
    // Windows PowerShell Media Player
    const psScript = `
      try {
        Add-Type -AssemblyName PresentationCore
        $p = New-Object System.Windows.Media.MediaPlayer
        $p.Open([System.Uri]'${soundPath.replace(/'/g, "''")}')
        $p.Volume = ${ratio}
        $p.Play()
        Start-Sleep -Seconds 15
      } catch {
        try { (New-Object Media.SoundPlayer '${soundPath.replace(/'/g, "''")}').PlaySync() } catch {}
      }
    `;
    const p = spawn('powershell', ['-NoProfile', '-NonInteractive', '-Command', psScript], { detached, stdio: 'ignore' });
    if (detached) {
      p.unref();
      if (callback) callback();
    } else {
      p.on('exit', () => callback && callback());
    }
  } else {
    // Linux / BSD
    // Check available players: paplay, pw-cat, mpv, ffplay, aplay
    const paplayVol = Math.round(vol * 655.36);
    const tryPlayers = [
      { cmd: 'paplay', args: [`--volume=${paplayVol}`, soundPath] },
      { cmd: 'pw-cat', args: ['-p', soundPath] },
      { cmd: 'mpv', args: ['--no-video', `--volume=${vol}`, soundPath] },
      { cmd: 'ffplay', args: ['-nodisp', '-autoexit', '-volume', `${vol}`, soundPath] },
      { cmd: 'aplay', args: [soundPath] }
    ];

    let spawned = false;
    for (const player of tryPlayers) {
      try {
        execSync(`command -v ${player.cmd} 2>/dev/null`);
        const p = spawn(player.cmd, player.args, { detached, stdio: 'ignore' });
        if (detached) {
          p.unref();
          if (callback) callback();
        } else {
          p.on('exit', () => callback && callback());
        }
        spawned = true;
        break;
      } catch (e) {}
    }

    if (!spawned) {
      process.stdout.write('\x07');
      if (callback) callback();
    }
  }
}

// Caller Agent Auto-Detection
function detectAgent() {
  if (process.env.CLAUDE_CONFIG_DIR || process.env.CLAUDE_SESSION_ID) return 'claude';
  if (process.env.CODEX_SESSION_ID || process.env.CODEX_PROJECT_ROOT) return 'codex';
  if (process.env.ANTIGRAVITY_APP_ROOT || process.env.AGY_CLI) return 'antigravity';

  try {
    const ppid = process.ppid;
    if (ppid) {
      const comm = execSync(`ps -o comm= -p ${ppid} 2>/dev/null`, { encoding: 'utf8' }).trim();
      if (/claude/i.test(comm)) return 'claude';
      if (/codex/i.test(comm)) return 'codex';
      if (/(antigravity|agy)/i.test(comm)) return 'antigravity';
      if (/opencode/i.test(comm)) return 'opencode';
    }
  } catch (e) {}

  return '';
}

// Status Dashboard
function showStatus() {
  const cfg = loadConfig();
  const catalog = loadCatalog();
  const vol = Math.max(0, Math.min(100, Number(cfg.volume) || 80));
  const bar = getVolumeBar(vol);

  function getSoundInfo(filename) {
    const linkPath = path.join(INSTALL_DIR, filename);
    if (fs.existsSync(linkPath)) {
      try {
        let realFile = linkPath;
        try { realFile = fs.readlinkSync(linkPath); } catch (e) {}
        const base = path.basename(realFile);
        const meta = catalog[base] || {};
        let info = `\x1b[1;32m${base}\x1b[0m`;
        if (meta.title && meta.title !== base) info += ` ("${meta.title}")`;
        if (meta.duration) info += ` (${meta.duration})`;
        if (meta.category) info += ` [\x1b[36m${meta.category}\x1b[0m]`;
        return info;
      } catch (e) {}
    }
    return null;
  }

  const defaultSound = getSoundInfo('alarm_sound.mp3') || '\x1b[33m(none configured)\x1b[0m';
  const claudeSound = getSoundInfo('alarm_sound_claude.mp3') || '\x1b[2m(uses Global Default)\x1b[0m';
  const codexSound = getSoundInfo('alarm_sound_codex.mp3') || '\x1b[2m(uses Global Default)\x1b[0m';
  const agySound = getSoundInfo('alarm_sound_antigravity.mp3') || '\x1b[2m(uses Global Default)\x1b[0m';
  const opencodeSound = getSoundInfo('alarm_sound_opencode.mp3') || '\x1b[2m(uses Global Default)\x1b[0m';

  const soundCount = fs.existsSync(SOUND_DIR)
    ? fs.readdirSync(SOUND_DIR).filter(f => /\.(mp3|wav|m4a|aac|ogg|flac|aiff)$/i.test(f)).length
    : 0;

  // Check agent hook files
  const claudePath = path.join(homeDir, '.claude', 'settings.json');
  let claudeStatus = '\x1b[31m○ Not installed\x1b[0m';
  if (fs.existsSync(claudePath)) {
    try {
      const c = JSON.parse(fs.readFileSync(claudePath, 'utf8'));
      const has = (c.hooks?.Stop || []).some(i => (i.hooks || []).some(h => (h.command || '').includes('alarm')));
      claudeStatus = has ? '\x1b[1;32m✓ Configured\x1b[0m (~/.claude/settings.json)' : '\x1b[33m○ Not configured\x1b[0m';
    } catch (e) { claudeStatus = '\x1b[33m○ Error parsing\x1b[0m'; }
  }

  const codexPath = path.join(homeDir, '.codex', 'config.toml');
  let codexStatus = '\x1b[31m○ Not installed\x1b[0m';
  if (fs.existsSync(codexPath)) {
    const raw = fs.readFileSync(codexPath, 'utf8');
    codexStatus = (raw.includes('[[hooks.Stop]]') && raw.includes('alarm'))
      ? '\x1b[1;32m✓ Configured\x1b[0m (~/.codex/config.toml)'
      : '\x1b[33m○ Not configured\x1b[0m';
  }

  const agyPath = path.join(homeDir, '.gemini', 'config', 'hooks.json');
  let agyStatus = '\x1b[31m○ Not installed\x1b[0m';
  if (fs.existsSync(agyPath)) {
    try {
      const h = JSON.parse(fs.readFileSync(agyPath, 'utf8'));
      agyStatus = h['task-finished-alarm']
        ? '\x1b[1;32m✓ Configured\x1b[0m (~/.gemini/config/hooks.json)'
        : '\x1b[33m○ Not configured\x1b[0m';
    } catch (e) { agyStatus = '\x1b[33m○ Error parsing\x1b[0m'; }
  }

  const opencodePath = path.join(homeDir, '.config', 'opencode', 'plugins', 'task-finished-alarm.ts');
  const opencodeStatus = fs.existsSync(opencodePath)
    ? '\x1b[1;32m✓ Configured\x1b[0m (~/.config/opencode/plugins/)'
    : '\x1b[31m○ Not installed\x1b[0m';

  const wsPath = path.join(process.cwd(), '.agents', 'hooks.json');
  let wsStatus = '\x1b[2m○ None\x1b[0m';
  if (fs.existsSync(wsPath)) {
    try {
      const w = JSON.parse(fs.readFileSync(wsPath, 'utf8'));
      if (w['task-finished-alarm']) wsStatus = '\x1b[1;32m✓ Configured\x1b[0m (.agents/hooks.json)';
    } catch (e) {}
  }

  console.log(`
╔═══════════════════════════════════════════════════════════════════╗
║                 AI-ALARM STATUS & CONFIGURATION                   ║
╚═══════════════════════════════════════════════════════════════════╝

  \x1b[1mAUDIO SETTINGS\x1b[0m
  ───────────────
  🔊 Volume:              \x1b[1;33m${vol}%\x1b[0m  [\x1b[32m${bar}\x1b[0m]
  🔇 Mute State:          ${cfg.muted ? '\x1b[1;31mMuted 🔇 (Silent mode)\x1b[0m' : '\x1b[1;32mActive 🔊 (Audio enabled)\x1b[0m'}
  🔔 Desktop Banners:     ${cfg.desktop_notifications !== false ? '\x1b[1;32mEnabled 🔔 (Native notification toasts)\x1b[0m' : '\x1b[33mDisabled 🔕\x1b[0m'}

  \x1b[1mASSIGNED SOUNDS\x1b[0m
  ───────────────
  🌐 Global Default:      ${defaultSound}
  🟣 Claude Code:         ${claudeSound}
  🟢 OpenAI Codex:        ${codexSound}
  🔵 Antigravity:         ${agySound}
  🟡 OpenCode:            ${opencodeSound}

  \x1b[1mAGENT HOOK INTEGRATIONS\x1b[0m
  ───────────────────────
  🟣 Claude Code:         ${claudeStatus}
  🟢 OpenAI Codex:        ${codexStatus}
  🔵 Google Antigravity:  ${agyStatus}
  🟡 OpenCode:            ${opencodeStatus}
  📂 Project Workspace:   ${wsStatus}

  \x1b[1mSYSTEM & PATHS\x1b[0m
  ──────────────
  📁 Sound Library:       ${SOUND_DIR} (${soundCount} tracks)
  ⚙️  Config File:         ${CONFIG_FILE}
  💻 Platform OS:         ${process.platform} (${os.arch()})
`);
  process.exit(0);
}

// Download a single sound file on-demand from GitHub (0-cost CDN)
function downloadSingleTrack(trackName, onDone) {
  const dest = path.join(SOUND_DIR, trackName);
  console.log(`→ Downloading ${trackName} from GitHub (0 cost)...`);
  const fileStream = fs.createWriteStream(dest);
  const trackUrl = `https://raw.githubusercontent.com/axosecurity/ai-alerm/master/sound/${encodeURIComponent(trackName)}`;
  https.get(trackUrl, (r) => {
    if (r.statusCode === 200) {
      r.pipe(fileStream);
      fileStream.on('finish', () => {
        fileStream.close();
        onDone(null, dest);
      });
    } else {
      fileStream.close();
      try { fs.unlinkSync(dest); } catch (e) {}
      onDone(new Error(`HTTP ${r.statusCode}`));
    }
  }).on('error', (err) => {
    fileStream.close();
    try { fs.unlinkSync(dest); } catch (e) {}
    onDone(err);
  });
}

// Storage & Cache Breakdown
function showStorage() {
  const cat = loadCatalog();
  const catKeys = Object.keys(cat);
  const extensions = /\.(mp3|wav|m4a|aac|ogg|flac|aiff)$/i;
  const onDisk = fs.existsSync(SOUND_DIR) ? fs.readdirSync(SOUND_DIR).filter(f => extensions.test(f)) : [];
  
  let bytes = 0;
  for (const f of onDisk) {
    try { bytes += fs.statSync(path.join(SOUND_DIR, f)).size; } catch(e){}
  }
  const mb = (bytes / (1024 * 1024)).toFixed(2);

  const assigned = new Set();
  const installFiles = fs.existsSync(INSTALL_DIR) ? fs.readdirSync(INSTALL_DIR) : [];
  for (const f of installFiles) {
    if (f.startsWith('alarm_sound')) {
      const full = path.join(INSTALL_DIR, f);
      try {
        const target = fs.readlinkSync(full);
        assigned.add(path.basename(target));
      } catch(e) {
        assigned.add(f);
      }
    }
  }

  const totalCatalog = Math.max(catKeys.length, onDisk.length);

  console.log(`
╔═══════════════════════════════════════════════════════════════════╗
║                 AI-ALARM STORAGE & CACHE BREAKDOWN                ║
╚═══════════════════════════════════════════════════════════════════╝

  Local Sounds Stored:    ${onDisk.length} tracks (${mb} MB on disk)
  Active Agent Sounds:    ${assigned.size} tracks (protected from pruning)
  Total Catalog Sounds:   ${totalCatalog} community tracks available on GitHub

  💡 Free up disk space:   alarm prune
  💡 Download all sounds:  alarm restore
  💡 Pick sound on-demand: alarm --select
`);
  process.exit(0);
}

// Prune unused sounds (keep active assigned agent tracks, delete the rest)
function pruneSounds() {
  console.log(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  console.log(` 🧹 Pruning Unused Sounds (Freeing Disk Space)...`);
  console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);

  const assigned = new Set();
  const installFiles = fs.existsSync(INSTALL_DIR) ? fs.readdirSync(INSTALL_DIR) : [];
  for (const f of installFiles) {
    if (f.startsWith('alarm_sound')) {
      const full = path.join(INSTALL_DIR, f);
      try {
        const target = fs.readlinkSync(full);
        assigned.add(path.basename(target));
      } catch(e) {
        assigned.add(f);
      }
    }
  }

  const extensions = /\.(mp3|wav|m4a|aac|ogg|flac|aiff)$/i;
  const files = fs.existsSync(SOUND_DIR) ? fs.readdirSync(SOUND_DIR).filter(f => extensions.test(f)) : [];
  let deletedCount = 0;
  let freedBytes = 0;

  for (const f of files) {
    if (assigned.has(f)) {
      console.log(`  🛡️  Protected (Active): ${f}`);
      continue;
    }
    const full = path.join(SOUND_DIR, f);
    try {
      const sz = fs.statSync(full).size;
      fs.unlinkSync(full);
      deletedCount++;
      freedBytes += sz;
      console.log(`  🗑️  Removed: ${f}`);
    } catch(e){}
  }

  const freedMB = (freedBytes / (1024 * 1024)).toFixed(2);
  console.log(`\n✓ Pruned ${deletedCount} unused sound file(s). Freed ${freedMB} MB!`);
  console.log(`💡 Active agent alerts are safe. You can re-download any sound anytime via GitHub.`);
  process.exit(0);
}

// Restore / Download all community sounds
function restoreSounds() {
  console.log(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  console.log(` ⬇️  Downloading Full Community Sound Pack...`);
  console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  const cat = loadCatalog();
  const tracks = Object.keys(cat);
  if (tracks.length === 0) {
    console.log('No tracks listed in catalog sounds.json. Run "alarm update" first.');
    process.exit(0);
  }

  let toDownload = [];
  for (const t of tracks) {
    const dest = path.join(SOUND_DIR, t);
    if (!fs.existsSync(dest)) {
      toDownload.push(t);
    }
  }

  if (toDownload.length === 0) {
    console.log('✓ All community sounds are already downloaded and cached locally.');
    process.exit(0);
  }

  let completed = 0;
  function downloadNext(index) {
    if (index >= toDownload.length) {
      console.log(`\n🎉 Restore complete! Downloaded ${completed} track(s). All community sounds are cached locally.`);
      process.exit(0);
      return;
    }
    const track = toDownload[index];
    process.stdout.write(`  → Downloading ${track}... `);
    const dest = path.join(SOUND_DIR, track);
    const fileStream = fs.createWriteStream(dest);
    const url = `https://raw.githubusercontent.com/axosecurity/ai-alerm/master/sound/${encodeURIComponent(track)}`;
    https.get(url, (res) => {
      if (res.statusCode === 200) {
        res.pipe(fileStream);
        fileStream.on('finish', () => {
          fileStream.close();
          completed++;
          process.stdout.write('✓\n');
          downloadNext(index + 1);
        });
      } else {
        fileStream.close();
        try { fs.unlinkSync(dest); } catch(e){}
        process.stdout.write('✗ (failed)\n');
        downloadNext(index + 1);
      }
    }).on('error', () => {
      fileStream.close();
      try { fs.unlinkSync(dest); } catch(e){}
      process.stdout.write('✗ (network error)\n');
      downloadNext(index + 1);
    });
  }

  downloadNext(0);
}

// Remove sound from local library
function removeSound(target) {
  if (!target) {
    console.log('Usage: alarm remove <sound_name>');
    process.exit(1);
  }
  const assigned = new Set();
  const installFiles = fs.existsSync(INSTALL_DIR) ? fs.readdirSync(INSTALL_DIR) : [];
  for (const f of installFiles) {
    if (f.startsWith('alarm_sound')) {
      const full = path.join(INSTALL_DIR, f);
      try {
        const trg = fs.readlinkSync(full);
        assigned.add(path.basename(trg).toLowerCase());
      } catch (e) {
        assigned.add(f.toLowerCase());
      }
    }
  }

  let found = false;
  const files = fs.existsSync(SOUND_DIR) ? fs.readdirSync(SOUND_DIR) : [];
  for (const f of files) {
    if (f.toLowerCase() === target.toLowerCase() || path.parse(f).name.toLowerCase() === target.toLowerCase()) {
      if (assigned.has(f.toLowerCase())) {
        console.log(`🛡️  Cannot remove '${f}': currently assigned to an active agent alert.`);
        console.log(`💡 Reassign the agent to another sound first before deleting this track.`);
        found = true;
        continue;
      }
      try {
        fs.unlinkSync(path.join(SOUND_DIR, f));
        console.log(`✓ Removed sound from local storage: ${f}`);
        found = true;
      } catch(e) {
        console.error(`Error removing ${f}: ${e.message}`);
      }
    }
  }
  if (!found) {
    console.log(`⚠ Sound '${target}' not found in ${SOUND_DIR}`);
  }
  process.exit(0);
}

// CLI Command Router
const args = process.argv.slice(2);
const cmd = args[0] ? args[0].toLowerCase() : '';

// 1. Help
if (['-h', '--help', 'help', '-help', '-ask', '--ask'].includes(cmd)) {
  showHelp();
}

// 2. Status
if (['status', 'info', '--status', '-status'].includes(cmd)) {
  showStatus();
}

// 2b. Storage & Cache
if (['storage', 'cache', '--storage', '--cache'].includes(cmd)) {
  showStorage();
}

// 2c. Prune / Clean Unused Sounds
if (['prune', 'clean', '--prune', '--clean'].includes(cmd)) {
  pruneSounds();
}

// 2d. Restore / Download All Sounds
if (['restore', 'download-all', '--restore', '--download-all'].includes(cmd)) {
  restoreSounds();
  return;
}

// 2e. Remove / Delete Single Sound
if (['remove', 'rm', 'delete', '--remove', '--delete'].includes(cmd)) {
  removeSound(args[1]);
}

// 3. Volume
if (['volume', 'vol', '--volume'].includes(cmd)) {
  const cfg = loadConfig();
  if (args[1] !== undefined) {
    const val = parseInt(args[1], 10);
    if (isNaN(val) || val < 0 || val > 100) {
      console.error('Error: Volume must be an integer between 0 and 100.');
      process.exit(1);
    }
    cfg.volume = val;
    saveConfig(cfg);
    console.log(`✓ Volume set to ${val}% [${getVolumeBar(val)}]`);
  } else {
    console.log(`Current volume: ${cfg.volume}% [${getVolumeBar(cfg.volume)}]`);
    console.log(`Change volume: alarm volume <0-100>`);
  }
  process.exit(0);
}

// 4. Mute / Unmute
if (['mute', '--mute'].includes(cmd)) {
  const cfg = loadConfig();
  cfg.muted = true;
  saveConfig(cfg);
  console.log('🔇 AI-Alarm muted (silent mode). Desktop notification banners will still trigger.');
  process.exit(0);
}

if (['unmute', '--unmute'].includes(cmd)) {
  const cfg = loadConfig();
  cfg.muted = false;
  saveConfig(cfg);
  console.log(`🔊 AI-Alarm unmuted (volume: ${cfg.volume}%).`);
  process.exit(0);
}

// 5. Desktop Notifications
if (['notify', 'notification', '--notify'].includes(cmd)) {
  const cfg = loadConfig();
  const sub = (args[1] || '').toLowerCase();
  if (['on', 'true', '1', 'enable'].includes(sub)) {
    cfg.desktop_notifications = true;
    saveConfig(cfg);
    console.log('🔔 Desktop notification banners enabled.');
  } else if (['off', 'false', '0', 'disable'].includes(sub)) {
    cfg.desktop_notifications = false;
    saveConfig(cfg);
    console.log('🔕 Desktop notification banners disabled.');
  } else {
    console.log(`Desktop notification banners: ${cfg.desktop_notifications ? 'Enabled 🔔' : 'Disabled 🔕'}`);
    console.log(`Toggle with: alarm notify ${cfg.desktop_notifications ? 'off' : 'on'}`);
  }
  process.exit(0);
}

// 6. Search Sounds
if (['search', 'find', '--search'].includes(cmd)) {
  const q = (args[1] || '').toLowerCase();
  if (!q) {
    console.log('Usage: alarm search <keyword>');
    process.exit(1);
  }
  console.log(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  console.log(` 🔍 Sound Library Search: "${q}"`);
  console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  const catalog = loadCatalog();
  const files = fs.readdirSync(SOUND_DIR).filter(f => /\.(mp3|wav|m4a|aac|ogg|flac|aiff)$/i.test(f));
  let count = 0;
  for (const f of files) {
    const meta = catalog[f] || {};
    const text = `${f} ${meta.title || ''} ${meta.description || ''} ${meta.category || ''} ${(meta.tags || []).join(' ')}`.toLowerCase();
    if (text.includes(q)) {
      count++;
      console.log(`\n  ♪ \x1b[1;32m${meta.title || f}\x1b[0m (${meta.duration || '?'}) [\x1b[36m${meta.category || 'custom'}\x1b[0m]`);
      if (meta.description) console.log(`    Description: ${meta.description}`);
      if (meta.contributor) console.log(`    Contributor: @${meta.contributor}`);
      console.log(`    File: ${f}`);
      console.log(`    Activate: alarm set "${f}"`);
    }
  }
  if (count === 0) console.log('  (No matching sounds found)');
  else console.log(`\nFound ${count} match(es).`);
  process.exit(0);
}

// 7. Update community sounds from GitHub
if (['update', 'sync', '--update', '--sync'].includes(cmd)) {
  console.log(`\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  console.log(` 🔄 Updating Sound Library from GitHub...`);
  console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  const rawUrl = 'https://raw.githubusercontent.com/axosecurity/ai-alerm/master/sound/sounds.json';
  https.get(rawUrl, (res) => {
    if (res.statusCode !== 200) {
      console.error(`Failed to reach GitHub (HTTP ${res.statusCode})`);
      process.exit(1);
    }
    let data = '';
    res.on('data', chunk => data += chunk);
    res.on('end', () => {
      try {
        const remoteCatalog = JSON.parse(data);
        const catPath = path.join(SOUND_DIR, 'sounds.json');
        let localCatalog = loadCatalog();
        let newCount = 0;
        for (const [filename, meta] of Object.entries(remoteCatalog)) {
          if (!localCatalog[filename]) newCount++;
          localCatalog[filename] = meta;
        }
        fs.writeFileSync(catPath, JSON.stringify(localCatalog, null, 2) + '\n');
        console.log(`✓ Sound catalog updated! ${Object.keys(localCatalog).length} community tracks available (${newCount} new).`);
        console.log(`💡 Sounds stream on demand when selected. To cache all sounds offline, run: alarm restore`);
        process.exit(0);
      } catch (e) {
        console.error('Error parsing remote sounds.json:', e.message);
        process.exit(1);
      }
    });
  }).on('error', (err) => {
    console.error('Network error updating from GitHub:', err.message);
    process.exit(1);
  });
  return;
}

// 8. Set sound directly
if (['set', '--set'].includes(cmd)) {
  const targetSound = args[1];
  const targetAgent = args[2] || 'global';
  if (!targetSound) {
    console.log('Usage: alarm set <sound_filename> [agent]');
    process.exit(1);
  }
  const files = fs.existsSync(SOUND_DIR) ? fs.readdirSync(SOUND_DIR) : [];
  const match = files.find(f => f.toLowerCase() === targetSound.toLowerCase() || path.parse(f).name.toLowerCase() === targetSound.toLowerCase());
  
  function applySound(chosenFile) {
    const destName = targetAgent === 'global' ? 'alarm_sound.mp3' : `alarm_sound_${targetAgent}.mp3`;
    const destPath = path.join(INSTALL_DIR, destName);
    try { if (fs.existsSync(destPath)) fs.unlinkSync(destPath); } catch (e) {}
    
    if (isWin) {
      fs.copyFileSync(path.join(SOUND_DIR, chosenFile), destPath);
    } else {
      fs.symlinkSync(path.join('sound', chosenFile), destPath);
    }
    console.log(`✓ Set ${targetAgent === 'global' ? 'Global Default' : targetAgent} sound → ${chosenFile}`);
    process.exit(0);
  }

  if (!match) {
    const catalog = loadCatalog();
    const catKeys = Object.keys(catalog);
    const cloudMatch = catKeys.find(k => k.toLowerCase() === targetSound.toLowerCase() || path.parse(k).name.toLowerCase() === targetSound.toLowerCase());
    if (cloudMatch) {
      downloadSingleTrack(cloudMatch, (err) => {
        if (err) {
          console.error(`Failed to download ${cloudMatch} from GitHub: ${err.message}`);
          process.exit(1);
        }
        applySound(cloudMatch);
      });
      return;
    }
    console.error(`Error: Sound '${targetSound}' not found in local library or catalog.`);
    process.exit(1);
  } else {
    applySound(match);
  }
}

// 9. Open sound folder
if (['open', 'dir', '--open'].includes(cmd)) {
  if (process.platform === 'darwin') {
    exec(`open "${SOUND_DIR}"`);
  } else if (process.platform === 'win32') {
    exec(`explorer "${SOUND_DIR}"`);
  } else {
    exec(`xdg-open "${SOUND_DIR}"`);
  }
  console.log(`✓ Opened sound library: ${SOUND_DIR}`);
  process.exit(0);
}

// 10. List sounds
if (['--list', '-l', 'list'].includes(cmd)) {
  console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  console.log(` 📁 Global Sound Library: ${SOUND_DIR}`);
  console.log(`━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`);
  const files = fs.readdirSync(SOUND_DIR).filter(f => /\.(mp3|wav|m4a|aac|ogg|flac|aiff)$/i.test(f));
  for (const f of files) {
    console.log(`  ♪ ${path.parse(f).name} (${f})`);
  }
  if (files.length === 0) console.log('  (No sound tracks found)');
  process.exit(0);
}

// 11. Add sound
if (['add', '--add'].includes(cmd)) {
  const src = args[1];
  if (!src) {
    console.log('Usage: alarm add <path_or_url>');
    process.exit(1);
  }
  if (/^https?:\/\//i.test(src)) {
    const filename = path.basename(src.split('?')[0]) || 'downloaded_sound.mp3';
    const dest = path.join(SOUND_DIR, filename);
    console.log(`→ Downloading audio from: ${src}`);
    const client = src.startsWith('https') ? https : http;
    const stream = fs.createWriteStream(dest);
    client.get(src, res => {
      res.pipe(stream);
      stream.on('finish', () => {
        stream.close();
        console.log(`✓ Successfully imported: ${dest}`);
        process.exit(0);
      });
    }).on('error', err => {
      console.error('Download failed:', err.message);
      process.exit(1);
    });
    return;
  } else {
    const resolved = path.resolve(src);
    if (!fs.existsSync(resolved)) {
      console.error(`Error: File not found: ${src}`);
      process.exit(1);
    }
    const dest = path.join(SOUND_DIR, path.basename(resolved));
    fs.copyFileSync(resolved, dest);
    console.log(`✓ Successfully imported: ${dest}`);
    process.exit(0);
  }
}

// 12. Interactive Selector Forwarding
if (['--select', '-s', 'select'].includes(cmd)) {
  const targetAgent = args[1] || '';
  if (isWin) {
    const psInstaller = path.join(INSTALL_DIR, 'bin', 'alarm.ps1');
    if (fs.existsSync(psInstaller)) {
      spawn('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', psInstaller, '--select', targetAgent], { stdio: 'inherit' });
    } else {
      console.log('Use "alarm set <sound>" or edit configuration in ~/.ai-alarm/');
    }
  } else {
    const shInstaller = path.join(INSTALL_DIR, 'install.sh');
    const localSh = path.join(__dirname, '..', 'install.sh');
    const script = fs.existsSync(localSh) ? localSh : shInstaller;
    spawn('bash', [script, '--select-only', targetAgent], { stdio: 'inherit' });
  }
  return;
}

// 13. Uninstall Forwarding
if (['uninstall', '--uninstall'].includes(cmd)) {
  if (isWin) {
    const psInstaller = path.join(__dirname, '..', 'install.ps1');
    spawn('powershell', ['-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', psInstaller, '-Uninstall'], { stdio: 'inherit' });
  } else {
    const localSh = path.join(__dirname, '..', 'install.sh');
    const script = fs.existsSync(localSh) ? localSh : path.join(INSTALL_DIR, 'install.sh');
    spawn('bash', [script, '--uninstall', ...args.slice(1)], { stdio: 'inherit' });
  }
  return;
}

// 14. DEFAULT: Sound Playback Execution
let agent = '';
if (['claude', 'codex', 'antigravity', 'opencode'].includes(cmd)) {
  agent = cmd;
} else {
  agent = detectAgent();
}

const audioFile = resolveAudioFile(agent);
if (!audioFile) {
  console.error('Error: No alarm sound found in ~/.ai-alarm or library.');
  console.error("Run 'alarm --help' or 'alarm add <path>' to configure.");
  process.exit(1);
}

// Trigger desktop notification
sendDesktopNotification(agent);

// Antigravity Stop hook contract expects JSON on stdout
if (agent === 'antigravity' || process.env.ANTIGRAVITY_APP_ROOT || process.env.AGY_CLI) {
  console.log('{}');
}

// Non-blocking background playback
if (agent || !process.stdin.isTTY) {
  playAudio(audioFile, null, true);
  process.exit(0);
} else {
  playAudio(audioFile, () => process.exit(0), false);
}
