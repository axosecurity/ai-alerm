# ==============================================================================
# AI-ALARM: Windows Native Installer & Agent Hook Manager
# Supports: Windows 10/11, PowerShell 5.1 / PowerShell Core, CMD, Git Bash
# ==============================================================================

[CmdletBinding()]
param (
    [switch]$Yes,
    [switch]$Status,
    [switch]$Uninstall,
    [switch]$Help
)

$ErrorActionPreference = "Stop"

$InstallDir = Join-Path $env:USERPROFILE ".ai-alarm"
$SoundDir   = Join-Path $InstallDir "sound"
$BinDir     = Join-Path $InstallDir "bin"
$ConfigFile = Join-Path $InstallDir "config.json"
$RepoRawUrl = "https://raw.githubusercontent.com/axosecurity/ai-alerm/master"

function Show-HelpManual {
    Write-Host @"
╔═══════════════════════════════════════════════════════════════════╗
║             AI-ALARM WINDOWS INSTALLER & MANAGER                  ║
╚═══════════════════════════════════════════════════════════════════╝

USAGE:
    powershell -File install.ps1 [OPTIONS]
    irm https://raw.githubusercontent.com/axosecurity/ai-alerm/master/install.ps1 | iex

OPTIONS:
    -Yes            Non-interactive installation (accept all defaults)
    -Status         Display configuration status and agent hook health
    -Uninstall      Cleanly remove all hooks, binaries, and configurations
    -Help           Show this documentation manual
"@
    exit 0
}

if ($Help) { Show-HelpManual }

# ------------------------------------------------------------------------------
# Status Dashboard
# ------------------------------------------------------------------------------
function Show-StatusDashboard {
    $vol = 80
    $muted = $false
    $desktopNotif = $true

    if (Test-Path $ConfigFile) {
        try {
            $cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
            if ($null -ne $cfg.volume) { $vol = [int]$cfg.volume }
            if ($null -ne $cfg.muted) { $muted = [bool]$cfg.muted }
            if ($null -ne $cfg.desktop_notifications) { $desktopNotif = [bool]$cfg.desktop_notifications }
        } catch {}
    }

    $barFilled = [Math]::Min(10, [Math]::Max(0, [Math]::Round(($vol + 5) / 10)))
    $bar = ("█" * $barFilled) + ("░" * (10 - $barFilled))

    $soundCount = 0
    if (Test-Path $SoundDir) {
        $soundCount = (Get-ChildItem -Path $SoundDir -File -Include *.mp3,*.wav,*.m4a,*.aac,*.ogg,*.flac,*.aiff | Measure-Object).Count
    }

    # Agent Hook Checks
    $claudePath = Join-Path $env:USERPROFILE ".claude\settings.json"
    $claudeStatus = "○ Not installed"
    if (Test-Path $claudePath) {
        try {
            $c = Get-Content $claudePath -Raw | ConvertFrom-Json
            $hasHook = $false
            if ($c.hooks -and $c.hooks.Stop) {
                foreach ($item in $c.hooks.Stop) {
                    if ($item.hooks) {
                        foreach ($h in $item.hooks) {
                            if ($h.command -match "alarm") { $hasHook = $true }
                        }
                    }
                }
            }
            $claudeStatus = if ($hasHook) { "✓ Configured (~/.claude/settings.json)" } else { "○ Not configured" }
        } catch { $claudeStatus = "○ Error parsing" }
    }

    $codexPath = Join-Path $env:USERPROFILE ".codex\config.toml"
    $codexStatus = "○ Not installed"
    if (Test-Path $codexPath) {
        $raw = Get-Content $codexPath -Raw
        $codexStatus = if ($raw -match "hooks\.Stop" -and $raw -match "alarm") { "✓ Configured (~/.codex/config.toml)" } else { "○ Not configured" }
    }

    $agyPath = Join-Path $env:USERPROFILE ".gemini\config\hooks.json"
    $agyStatus = "○ Not installed"
    if (Test-Path $agyPath) {
        try {
            $h = Get-Content $agyPath -Raw | ConvertFrom-Json
            $agyStatus = if ($h."task-finished-alarm") { "✓ Configured (~/.gemini/config/hooks.json)" } else { "○ Not configured" }
        } catch { $agyStatus = "○ Error parsing" }
    }

    $opencodePath = Join-Path $env:USERPROFILE ".config\opencode\plugins\task-finished-alarm.ts"
    $opencodeStatus = if (Test-Path $opencodePath) { "✓ Configured (~/.config/opencode/plugins/)" } else { "○ Not installed" }

    Write-Host @"

╔═══════════════════════════════════════════════════════════════════╗
║                 AI-ALARM STATUS & CONFIGURATION                   ║
╚═══════════════════════════════════════════════════════════════════╝

  AUDIO SETTINGS
  ───────────────
  🔊 Volume:              $vol%  [$bar]
  🔇 Mute State:          $(if ($muted) { "Muted 🔇 (Silent mode)" } else { "Active 🔊 (Audio enabled)" })
  🔔 Desktop Banners:     $(if ($desktopNotif) { "Enabled 🔔 (Windows Toast)" } else { "Disabled 🔕" })

  AGENT HOOK INTEGRATIONS
  ───────────────────────
  🟣 Claude Code:         $claudeStatus
  🟢 OpenAI Codex:        $codexStatus
  🔵 Google Antigravity:  $agyStatus
  🟡 OpenCode:            $opencodeStatus

  SYSTEM & PATHS
  ──────────────
  📁 Sound Library:       $SoundDir ($soundCount tracks)
  ⚙️  Config File:         $ConfigFile
  🚀 Binary Directory:    $BinDir
"@
    exit 0
}

if ($Status) { Show-StatusDashboard }

# ------------------------------------------------------------------------------
# Uninstallation
# ------------------------------------------------------------------------------
function Run-Uninstallation {
    Write-Host ""
    Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
    Write-Host "║              AI-ALARM WINDOWS UNINSTALLER                 ║" -ForegroundColor Yellow
    Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
    Write-Host ""

    if (-not $Yes) {
        $confirm = Read-Host "Are you sure you want to uninstall AI-Alarm and remove all hooks? [y/N]"
        if ($confirm -notmatch '^[yY](es)?$') {
            Write-Host "Uninstall canceled."
            exit 0
        }
    }

    Write-Host "→ Removing agent hooks..." -ForegroundColor Cyan

    # 1. Claude Code
    $claudePath = Join-Path $env:USERPROFILE ".claude\settings.json"
    if (Test-Path $claudePath) {
        try {
            $c = Get-Content $claudePath -Raw | ConvertFrom-Json
            if ($c.hooks -and $c.hooks.Stop) {
                $newStop = @()
                foreach ($item in $c.hooks.Stop) {
                    if ($item.hooks) {
                        $item.hooks = @($item.hooks | Where-Object { $_.command -notmatch "alarm" })
                        if ($item.hooks.Count -gt 0) { $newStop += $item }
                    }
                }
                $c.hooks.Stop = $newStop
                if ($c.hooks.Stop.Count -eq 0) {
                    $c.PSObject.Properties.Remove('Stop')
                }
                $c | ConvertTo-Json -Depth 10 | Set-Content $claudePath
                Write-Host "  ✓ Removed Claude Code hook ($claudePath)" -ForegroundColor Green
            }
        } catch {}
    }

    # 2. OpenAI Codex
    $codexPath = Join-Path $env:USERPROFILE ".codex\config.toml"
    if (Test-Path $codexPath) {
        try {
            $raw = Get-Content $codexPath -Raw
            $cleaned = $raw -replace '(?s)\[\[hooks\.Stop\]\].*?command\s*=\s*".*?alarm.*?".*?(?=\n\[|\Z)', ''
            $cleaned = $cleaned -replace '(?m)^\s*\[hooks\.state\."[^"]*:stop:[^"]*"\]\s*\r?\n\s*trusted_hash\s*=\s*"[^"]*"\s*\r?\n?', ''
            Set-Content -Path $codexPath -Value $cleaned.Trim()
            Write-Host "  ✓ Removed OpenAI Codex hook ($codexPath)" -ForegroundColor Green
        } catch {}
    }

    # 3. Google Antigravity
    $agyPath = Join-Path $env:USERPROFILE ".gemini\config\hooks.json"
    if (Test-Path $agyPath) {
        try {
            $h = Get-Content $agyPath -Raw | ConvertFrom-Json
            if ($h."task-finished-alarm") {
                $h.PSObject.Properties.Remove("task-finished-alarm")
                $h | ConvertTo-Json -Depth 10 | Set-Content $agyPath
                Write-Host "  ✓ Removed Google Antigravity hook ($agyPath)" -ForegroundColor Green
            }
        } catch {}
    }

    # 4. OpenCode
    $opencodePath = Join-Path $env:USERPROFILE ".config\opencode\plugins\task-finished-alarm.ts"
    if (Test-Path $opencodePath) {
        Remove-Item -Path $opencodePath -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Removed OpenCode hook ($opencodePath)" -ForegroundColor Green
    }

    # 5. Remove Binaries
    if (Test-Path $BinDir) {
        Remove-Item -Path $BinDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "  ✓ Removed binary folder ($BinDir)" -ForegroundColor Green
    }

    # 6. Remove PATH
    try {
        $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
        if ($userPath) {
            $newPath = ($userPath -split ';' | Where-Object { $_ -ne $BinDir }) -join ';'
            [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
            Write-Host "  ✓ Cleaned Windows User PATH" -ForegroundColor Green
        }
    } catch {}

    Write-Host ""
    Write-Host "🎉 AI-Alarm uninstalled successfully from Windows!" -ForegroundColor Green
    exit 0
}

if ($Uninstall) { Run-Uninstallation }

# ------------------------------------------------------------------------------
# Installation Workflow
# ------------------------------------------------------------------------------
Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║        AI-ALARM WINDOWS UNIVERSAL HOOKS SETUP             ║" -ForegroundColor Cyan
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

New-Item -ItemType Directory -Path $SoundDir -Force | Out-Null
New-Item -ItemType Directory -Path $BinDir -Force | Out-Null

# Download / Copy sound catalog
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { (Get-Location).Path }
$localSoundDir = Join-Path $scriptDir "sound"

if (Test-Path $localSoundDir) {
    Write-Host "→ Copying bundled sounds to $SoundDir..." -ForegroundColor Cyan
    Get-ChildItem -Path $localSoundDir -File | ForEach-Object {
        $dest = Join-Path $SoundDir $_.Name
        if (-not (Test-Path $dest)) {
            Copy-Item -Path $_.FullName -Destination $dest
        }
    }
} else {
    Write-Host "→ Fetching sound catalog metadata from GitHub..." -ForegroundColor Cyan
    try {
        $jsonDest = Join-Path $SoundDir "sounds.json"
        Invoke-WebRequest -Uri "$RepoRawUrl/sound/sounds.json" -OutFile $jsonDest -UseBasicParsing
        $defaultTrack = "allahuakabar-laillahillah-zikir.mp3"
        $trackDest = Join-Path $SoundDir $defaultTrack
        if (-not (Test-Path $trackDest)) {
            Write-Host "  → Downloading starter track ($defaultTrack)..." -ForegroundColor Gray
            Invoke-WebRequest -Uri "$RepoRawUrl/sound/$defaultTrack" -OutFile $trackDest -UseBasicParsing
        }
    } catch {
        Write-Warning "Could not fetch sound catalog from GitHub. Please check internet connection."
    }
}

# Ensure config.json
if (-not (Test-Path $ConfigFile)) {
    @{
        volume = 80
        muted = $false
        desktop_notifications = $true
    } | ConvertTo-Json | Set-Content $ConfigFile
}

# ------------------------------------------------------------------------------
# Create alarm.ps1 and alarm.cmd executable wrappers
# ------------------------------------------------------------------------------
$AlarmPs1Path = Join-Path $BinDir "alarm.ps1"
$AlarmCmdPath = Join-Path $BinDir "alarm.cmd"

$alarmPs1Content = @'
param(
    [string]$Command = "",
    [string]$Arg1 = "",
    [string]$Arg2 = ""
)

$InstallDir = Join-Path $env:USERPROFILE ".ai-alarm"
$SoundDir   = Join-Path $InstallDir "sound"
$ConfigFile = Join-Path $InstallDir "config.json"

function Get-AlarmConfig {
    $cfg = @{ volume = 80; muted = $false; desktop_notifications = $true }
    if (Test-Path $ConfigFile) {
        try {
            $json = Get-Content $ConfigFile -Raw | ConvertFrom-Json
            if ($null -ne $json.volume) { $cfg.volume = [int]$json.volume }
            if ($null -ne $json.muted) { $cfg.muted = [bool]$json.muted }
            if ($null -ne $json.desktop_notifications) { $cfg.desktop_notifications = [bool]$json.desktop_notifications }
        } catch {}
    }
    return $cfg
}

function Save-AlarmConfig($cfg) {
    $cfg | ConvertTo-Json | Set-Content $ConfigFile
}

function Send-Toast($agent) {
    $cfg = Get-AlarmConfig
    if (-not $cfg.desktop_notifications) { return }
    $title = if ($agent) { "Task completed by $agent!" } else { "Task completed!" }
    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
        $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
        $xml = [xml]$template.GetXml()
        $xml.GetElementsByTagName("text")[0].AppendChild($xml.CreateTextNode("AI-Alarm")) > $null
        $xml.GetElementsByTagName("text")[1].AppendChild($xml.CreateTextNode($title)) > $null
        $toastXml = New-Object Windows.Data.Xml.Dom.XmlDocument
        $toastXml.LoadXml($xml.OuterXml)
        $toast = [Windows.UI.Notifications.ToastNotification]::new($toastXml)
        [Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier("AI-Alarm").Show($toast)
    } catch {}
}

# Volume command
if ($Command -in @("volume", "vol", "--volume")) {
    $cfg = Get-AlarmConfig
    if ($Arg1 -ne "") {
        $val = [int]$Arg1
        $cfg.volume = [Math]::Max(0, [Math]::Min(100, $val))
        Save-AlarmConfig $cfg
        Write-Host "✓ Volume set to $($cfg.volume)%" -ForegroundColor Green
    } else {
        Write-Host "Current volume: $($cfg.volume)%"
    }
    exit 0
}

# Mute / Unmute
if ($Command -in @("mute", "--mute")) {
    $cfg = Get-AlarmConfig
    $cfg.muted = $true
    Save-AlarmConfig $cfg
    Write-Host "🔇 AI-Alarm muted (silent mode)." -ForegroundColor Yellow
    exit 0
}

if ($Command -in @("unmute", "--unmute")) {
    $cfg = Get-AlarmConfig
    $cfg.muted = $false
    Save-AlarmConfig $cfg
    Write-Host "🔊 AI-Alarm unmuted (volume: $($cfg.volume)%)." -ForegroundColor Green
    exit 0
}

# Notify command
if ($Command -in @("notify", "notification", "--notify")) {
    $cfg = Get-AlarmConfig
    if ($Arg1 -in @("off", "disable", "false", "0")) {
        $cfg.desktop_notifications = $false
        Save-AlarmConfig $cfg
        Write-Host "🔕 Desktop notification toasts disabled." -ForegroundColor Yellow
    } else {
        $cfg.desktop_notifications = $true
        Save-AlarmConfig $cfg
        Write-Host "🔔 Desktop notification toasts enabled." -ForegroundColor Green
    }
    exit 0
}

# Help command
if ($Command -in @("help", "-help", "--help", "-h", "-ask", "--ask")) {
    Write-Host @"
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
    alarm update              Download latest community catalog from GitHub (sync)
    alarm set <sound> [agent] Directly activate a sound track without menu
    alarm open                Open the sound library directory in File Manager
    alarm remove <name>       Remove a sound file from local disk (rm, delete)
    alarm --help | -help      Show this documentation manual (-h, --ask, -ask)
"@
    exit 0
}

# Storage & Cache breakdown
if ($Command -in @("storage", "cache", "--storage", "--cache")) {
    $files = Get-ChildItem -Path $SoundDir -File -Include *.mp3,*.wav,*.m4a,*.aac,*.ogg,*.flac,*.aiff -ErrorAction SilentlyContinue
    $count = if ($files) { $files.Count } else { 0 }
    $bytes = 0
    if ($files) { $files | ForEach-Object { $bytes += $_.Length } }
    $mb = [Math]::Round($bytes / 1MB, 2)
    
    $catPath = Join-Path $SoundDir "sounds.json"
    $catCount = $count
    if (Test-Path $catPath) {
        try {
            $cat = Get-Content $catPath -Raw | ConvertFrom-Json
            $catCount = [Math]::Max($count, ($cat.PSObject.Properties | Measure-Object).Count)
        } catch {}
    }

    Write-Host @"
╔═══════════════════════════════════════════════════════════════════╗
║                 AI-ALARM STORAGE & CACHE BREAKDOWN                ║
╚═══════════════════════════════════════════════════════════════════╝

  Local Sounds Stored:    $count tracks ($mb MB on disk)
  Total Catalog Sounds:   $catCount community tracks available on GitHub

  💡 Free up disk space:   alarm prune
  💡 Download all sounds:  alarm restore
  💡 Pick sound directly:  alarm set <track>
"@
    exit 0
}

# Prune unused sounds (keep active assigned agent tracks, delete the rest)
if ($Command -in @("prune", "clean", "--prune", "--clean")) {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host " 🧹 Pruning Unused Sounds (Freeing Disk Space)..." -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    
    $activeFiles = @()
    Get-ChildItem -Path $InstallDir -File -Filter "alarm_sound*.mp3" -ErrorAction SilentlyContinue | ForEach-Object {
        $activeFiles += $_.Name
    }
    
    $files = Get-ChildItem -Path $SoundDir -File -Include *.mp3,*.wav,*.m4a,*.aac,*.ogg,*.flac,*.aiff -ErrorAction SilentlyContinue
    $deleted = 0
    $freedBytes = 0
    foreach ($f in $files) {
        if ($f.Name -in $activeFiles) {
            Write-Host "  🛡️  Protected (Active): $($f.Name)" -ForegroundColor Green
            continue
        }
        $freedBytes += $f.Length
        Remove-Item -Path $f.FullName -Force -ErrorAction SilentlyContinue
        Write-Host "  🗑️  Removed: $($f.Name)" -ForegroundColor Yellow
        $deleted++
    }
    $freedMb = [Math]::Round($freedBytes / 1MB, 2)
    Write-Host ""
    Write-Host "✓ Pruned $deleted unused sound file(s). Freed $freedMb MB!" -ForegroundColor Green
    Write-Host "💡 Active agent alerts are safe. You can re-download any sound anytime via GitHub."
    exit 0
}

# Restore / Download all sounds
if ($Command -in @("restore", "download-all", "--restore", "--download-all")) {
    Write-Host ""
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    Write-Host " ⬇️  Downloading Full Community Sound Pack..." -ForegroundColor Cyan
    Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
    $catPath = Join-Path $SoundDir "sounds.json"
    if (-not (Test-Path $catPath)) {
        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/axosecurity/ai-alerm/master/sound/sounds.json" -OutFile $catPath -UseBasicParsing
    }
    try {
        $cat = Get-Content $catPath -Raw | ConvertFrom-Json
        $downloaded = 0
        foreach ($prop in $cat.PSObject.Properties) {
            $t = $prop.Name
            $dest = Join-Path $SoundDir $t
            if (-not (Test-Path $dest)) {
                Write-Host "  → Downloading $t..." -ForegroundColor Gray
                Invoke-WebRequest -Uri "https://raw.githubusercontent.com/axosecurity/ai-alerm/master/sound/$t" -OutFile $dest -UseBasicParsing
                $downloaded++
            }
        }
        Write-Host ""
        Write-Host "🎉 Restore complete! Downloaded $downloaded track(s). All community sounds cached locally." -ForegroundColor Green
    } catch {
        Write-Warning "Failed to download sounds from GitHub."
    }
    exit 0
}

# Remove single sound
if ($Command -in @("remove", "rm", "delete", "--remove", "--delete")) {
    if (-not $Arg1) {
        Write-Host "Usage: alarm remove <sound_name>"
        exit 1
    }
    $found = $false
    Get-ChildItem -Path $SoundDir -File | ForEach-Object {
        if ($_.Name -eq $Arg1 -or $_.BaseName -eq $Arg1) {
            Remove-Item -Path $_.FullName -Force -ErrorAction SilentlyContinue
            Write-Host "✓ Removed sound from local storage: $($_.Name)" -ForegroundColor Green
            $found = $true
        }
    }
    if (-not $found) {
        Write-Host "⚠ Sound '$Arg1' not found in $SoundDir" -ForegroundColor Yellow
    }
    exit 0
}

# Set sound directly (with on-demand streaming/download from GitHub if cloud-only)
if ($Command -in @("set", "--set")) {
    if (-not $Arg1) {
        Write-Host "Usage: alarm set <sound_filename> [agent]"
        exit 1
    }
    $targetSound = $Arg1
    $targetAgent = if ($Arg2) { $Arg2 } else { "global" }
    
    $destFile = if ($targetAgent -eq "global") { "alarm_sound.mp3" } else { "alarm_sound_$targetAgent.mp3" }
    $destPath = Join-Path $InstallDir $destFile
    
    $localFile = $null
    Get-ChildItem -Path $SoundDir -File | ForEach-Object {
        if ($_.Name -eq $targetSound -or $_.BaseName -eq $targetSound) {
            $localFile = $_.FullName
        }
    }
    
    if (-not $localFile) {
        $catPath = Join-Path $SoundDir "sounds.json"
        if (Test-Path $catPath) {
            try {
                $cat = Get-Content $catPath -Raw | ConvertFrom-Json
                foreach ($prop in $cat.PSObject.Properties) {
                    if ($prop.Name -eq $targetSound -or [System.IO.Path]::GetFileNameWithoutExtension($prop.Name) -eq $targetSound) {
                        $trackName = $prop.Name
                        $dest = Join-Path $SoundDir $trackName
                        Write-Host "→ Downloading $trackName from GitHub (0 cost)..." -ForegroundColor Cyan
                        Invoke-WebRequest -Uri "https://raw.githubusercontent.com/axosecurity/ai-alerm/master/sound/$trackName" -OutFile $dest -UseBasicParsing
                        $localFile = $dest
                        break
                    }
                }
            } catch {}
        }
    }
    
    if ($localFile) {
        Copy-Item -Path $localFile -Destination $destPath -Force
        Write-Host "✓ Set $targetAgent sound → $([System.IO.Path]::GetFileName($localFile))" -ForegroundColor Green
    } else {
        Write-Host "Error: Sound '$targetSound' not found locally or in GitHub catalog." -ForegroundColor Red
        exit 1
    }
    exit 0
}

# Open command
if ($Command -in @("open", "dir", "--open")) {
    Invoke-Item $SoundDir
    exit 0
}

# Play sound
$cfg = Get-AlarmConfig
Send-Toast $Command

if ($cfg.muted) { exit 0 }

# Find audio file
$audioFile = $null
$files = Get-ChildItem -Path $SoundDir -File -Include *.mp3,*.wav,*.m4a,*.aac,*.ogg,*.flac,*.aiff -ErrorAction SilentlyContinue
if ($files -and $files.Count -gt 0) {
    $audioFile = $files[0].FullName
}

if ($audioFile) {
    try {
        Add-Type -AssemblyName PresentationCore
        $player = New-Object System.Windows.Media.MediaPlayer
        $player.Open([System.Uri](Resolve-Path $audioFile).Path)
        $player.Volume = [Math]::Max(0.0, [Math]::Min(1.0, [double]$cfg.volume / 100.0))
        $player.Play()
        Start-Sleep -Seconds 12
    } catch {
        try { (New-Object Media.SoundPlayer $audioFile).PlaySync() } catch {}
    }
}
'@

Set-Content -Path $AlarmPs1Path -Value $alarmPs1Content
$alarmCmdContent = "@echo off`r`npowershell -NoProfile -ExecutionPolicy Bypass -File `"%USERPROFILE%\.ai-alarm\bin\alarm.ps1`" %*"
Set-Content -Path $AlarmCmdPath -Value $alarmCmdContent

# Add to User PATH if not present
$userPath = [Environment]::GetEnvironmentVariable("Path", "User")
if ($userPath -split ';' -notcontains $BinDir) {
    $newPath = if ($userPath) { "$userPath;$BinDir" } else { $BinDir }
    [Environment]::SetEnvironmentVariable("Path", $newPath, "User")
    $env:Path = "$env:Path;$BinDir"
    Write-Host "✓ Added $BinDir to User PATH" -ForegroundColor Green
}

# ------------------------------------------------------------------------------
# Register Agent Hooks
# ------------------------------------------------------------------------------
Write-Host "→ Configuring AI agent completion hooks..." -ForegroundColor Cyan

# 1. Claude Code
$claudeDir = Join-Path $env:USERPROFILE ".claude"
if (Test-Path $claudeDir) {
    $claudeSettings = Join-Path $claudeDir "settings.json"
    $settings = @{}
    if (Test-Path $claudeSettings) {
        try { $settings = Get-Content $claudeSettings -Raw | ConvertFrom-Json } catch {}
    }
    if (-not $settings.hooks) { $settings | Add-Member -Name "hooks" -Value @{} -MemberType NoteProperty }
    if (-not $settings.hooks.Stop) { $settings.hooks | Add-Member -Name "Stop" -Value @() -MemberType NoteProperty }
    
    $hookExists = $false
    foreach ($item in $settings.hooks.Stop) {
        if ($item.hooks) {
            foreach ($h in $item.hooks) {
                if ($h.command -match "alarm") { $hookExists = $true }
            }
        }
    }
    if (-not $hookExists) {
        $settings.hooks.Stop += @{
            hooks = @(
                @{
                    type = "command"
                    command = "alarm claude"
                    timeout = 15
                }
            )
        }
        $settings | ConvertTo-Json -Depth 10 | Set-Content $claudeSettings
        Write-Host "  ✓ Claude Code hook configured ($claudeSettings)" -ForegroundColor Green
    }
}

# 2. OpenAI Codex
$codexDir = Join-Path $env:USERPROFILE ".codex"
if (Test-Path $codexDir) {
    $codexConfig = Join-Path $codexDir "config.toml"
    $tomlContent = if (Test-Path $codexConfig) { Get-Content $codexConfig -Raw } else { "" }
    if ($tomlContent -notmatch "hooks\.Stop" -or $tomlContent -notmatch "alarm") {
        $append = @"

[[hooks.Stop]]
matcher = "always"

  [[hooks.Stop.hooks]]
  type = "command"
  command = "alarm codex"
  timeout = 15
  trust_level = "trusted"
"@
        Add-Content -Path $codexConfig -Value $append
        Write-Host "  ✓ OpenAI Codex hook configured ($codexConfig)" -ForegroundColor Green
    }
}

# 3. Google Antigravity
$geminiConfigDir = Join-Path $env:USERPROFILE ".gemini\config"
if (Test-Path $geminiConfigDir) {
    $agyHooks = Join-Path $geminiConfigDir "hooks.json"
    $hooks = @{}
    if (Test-Path $agyHooks) {
        try { $hooks = Get-Content $agyHooks -Raw | ConvertFrom-Json } catch {}
    }
    $hooks."task-finished-alarm" = @{
        Stop = @(
            @{
                type = "command"
                command = "alarm antigravity"
                timeout = 15
            }
        )
    }
    $hooks | ConvertTo-Json -Depth 10 | Set-Content $agyHooks
    Write-Host "  ✓ Antigravity hook configured ($agyHooks)" -ForegroundColor Green
}

Write-Host ""
Write-Host "╔═══════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "║        🎉 AI-ALARM INSTALLED & READY TO USE!              ║" -ForegroundColor Green
Write-Host "╚═══════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host "  ✓ Audio alerts enabled (volume: 80%)" -ForegroundColor Green
Write-Host "  ✓ Windows notification toasts enabled" -ForegroundColor Green
Write-Host "  ✓ Global command ready: alarm" -ForegroundColor Green
Write-Host ""
Write-Host "💡 QUICK COMMANDS:" -ForegroundColor Yellow
Write-Host "  * Test alert sound:     alarm" -ForegroundColor Gray
Write-Host "  * Adjust volume:        alarm volume 60" -ForegroundColor Gray
Write-Host "  * Status dashboard:     alarm status" -ForegroundColor Gray
Write-Host ""

# Play quick confirmation alert in background
try {
    Start-Process -FilePath "powershell.exe" -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$AlarmPs1Path`"" -WindowStyle Hidden
} catch {}
