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
    $notifSound = $false
    $notifTitle = "AI-Alarm"
    $webhookUrl = ""

    if (Test-Path $ConfigFile) {
        try {
            $cfg = Get-Content $ConfigFile -Raw | ConvertFrom-Json
            if ($null -ne $cfg.volume) { $vol = [int]$cfg.volume }
            if ($null -ne $cfg.muted) { $muted = [bool]$cfg.muted }
            if ($null -ne $cfg.desktop_notifications) { $desktopNotif = [bool]$cfg.desktop_notifications }
            if ($null -ne $cfg.notification_sound) { $notifSound = [bool]$cfg.notification_sound }
            if ($null -ne $cfg.notification_title) { $notifTitle = [string]$cfg.notification_title }
            if ($null -ne $cfg.webhook_url) { $webhookUrl = [string]$cfg.webhook_url }
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

    function Check-HookFile($pathList) {
        foreach ($p in $pathList) {
            if (Test-Path $p) {
                try {
                    $h = Get-Content $p -Raw | ConvertFrom-Json
                    if ($h."task-finished-alarm") { return "✓ Configured ($($p.Replace($env:USERPROFILE, '~')))" }
                } catch {}
            }
        }
        return "○ Not configured"
    }

    $agyCliStatus  = Check-HookFile @((Join-Path $env:USERPROFILE ".gemini\antigravity-cli\hooks.json"), (Join-Path $env:USERPROFILE ".antigravity\hooks.json"))
    $agyIdeStatus  = Check-HookFile @((Join-Path $env:USERPROFILE ".gemini\antigravity-ide\hooks.json"), (Join-Path $env:USERPROFILE ".antigravity-ide\hooks.json"))
    $geminiCoreStatus = Check-HookFile @((Join-Path $env:USERPROFILE ".gemini\config\hooks.json"), (Join-Path $env:USERPROFILE ".gemini\antigravity\hooks.json"))

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

  NOTIFICATION SETTINGS
  ──────────────────────
  🔔 Desktop Banners:     $(if ($desktopNotif) { "Enabled 🔔 (Windows Toast)" } else { "Disabled 🔕" })
  🔊 Banner Chime:        $(if ($notifSound) { "Enabled 🔊" } else { "Silent 🔇" })
  🏷️  Banner Title:        "$notifTitle"
  🌐 Webhook URL:         $(if ($webhookUrl) { $webhookUrl } else { "None (Slack / Discord)" })

  AGENT HOOK INTEGRATIONS
  ───────────────────────
  🟣 Claude Code:         $claudeStatus
  🟢 OpenAI Codex:        $codexStatus
  🔵 Antigravity CLI:     $agyCliStatus
  🔵 Antigravity IDE:     $agyIdeStatus
  🔵 Gemini Ecosystem:    $geminiCoreStatus
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

    # 3. Google Antigravity & Gemini Ecosystem
    $agyHookList = @(
        (Join-Path $env:USERPROFILE ".gemini\config\hooks.json"),
        (Join-Path $env:USERPROFILE ".gemini\antigravity\hooks.json"),
        (Join-Path $env:USERPROFILE ".gemini\antigravity-cli\hooks.json"),
        (Join-Path $env:USERPROFILE ".gemini\antigravity-ide\hooks.json"),
        (Join-Path $env:USERPROFILE ".antigravity\hooks.json"),
        (Join-Path $env:USERPROFILE ".antigravity-ide\hooks.json")
    )
    $removedAgy = $false
    foreach ($p in $agyHookList) {
        if (Test-Path $p) {
            try {
                $h = Get-Content $p -Raw | ConvertFrom-Json
                if ($h."task-finished-alarm") {
                    $h.PSObject.Properties.Remove("task-finished-alarm")
                    $h | ConvertTo-Json -Depth 10 | Set-Content $p
                    $removedAgy = $true
                }
            } catch {}
        }
    }
    if ($removedAgy) {
        Write-Host "  ✓ Removed Antigravity & Gemini hooks across all interfaces" -ForegroundColor Green
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
    $cfg = @{ volume = 80; muted = $false; desktop_notifications = $true; notification_sound = $false; notification_title = "AI-Alarm"; webhook_url = "" }
    if (Test-Path $ConfigFile) {
        try {
            $json = Get-Content $ConfigFile -Raw | ConvertFrom-Json
            if ($null -ne $json.volume) { $cfg.volume = [int]$json.volume }
            if ($null -ne $json.muted) { $cfg.muted = [bool]$json.muted }
            if ($null -ne $json.desktop_notifications) { $cfg.desktop_notifications = [bool]$json.desktop_notifications }
            if ($null -ne $json.notification_sound) { $cfg.notification_sound = [bool]$json.notification_sound }
            if ($null -ne $json.notification_title) { $cfg.notification_title = [string]$json.notification_title }
            if ($null -ne $json.webhook_url) { $cfg.webhook_url = [string]$json.webhook_url }
        } catch {}
    }
    return $cfg
}

function Save-AlarmConfig($cfg) {
    $cfg | ConvertTo-Json | Set-Content $ConfigFile
}

function Send-Toast($agent, $msgText) {
    $cfg = Get-AlarmConfig
    $title = if ($cfg.notification_title) { $cfg.notification_title } else { "AI-Alarm" }
    $body = if ($msgText) { $msgText } elseif ($agent) { "Task completed by $agent!" } else { "Task completed!" }

    if ($cfg.webhook_url) {
        try {
            $payload = @{
                text = "🔔 $title: $body"
                agent = $agent
                timestamp = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            } | ConvertTo-Json
            Start-Job -ScriptBlock {
                param($url, $p)
                Invoke-RestMethod -Uri $url -Method Post -Body $p -ContentType "application/json" -TimeoutSec 5
            } -ArgumentList $cfg.webhook_url, $payload | Out-Null
        } catch {}
    }

    if ($cfg.desktop_notifications -eq $false) { return }

    try {
        [Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > $null
        $template = [Windows.UI.Notifications.ToastNotificationManager]::GetTemplateContent([Windows.UI.Notifications.ToastTemplateType]::ToastText02)
        $xml = [xml]$template.GetXml()
        $xml.GetElementsByTagName("text")[0].AppendChild($xml.CreateTextNode($title)) > $null
        $xml.GetElementsByTagName("text")[1].AppendChild($xml.CreateTextNode($body)) > $null

        if (-not $cfg.notification_sound) {
            $audioElem = $xml.CreateElement("audio")
            $audioElem.SetAttribute("silent", "true")
            $xml.DocumentElement.AppendChild($audioElem) > $null
        }

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
    $sub = ($Arg1 + "").ToLower()
    if ($sub -in @("on", "true", "1", "enable")) {
        $cfg.desktop_notifications = $true
        Save-AlarmConfig $cfg
        Write-Host "🔔 Desktop notification banners enabled." -ForegroundColor Green
    } elseif ($sub -in @("off", "false", "0", "disable")) {
        $cfg.desktop_notifications = $false
        Save-AlarmConfig $cfg
        Write-Host "🔕 Desktop notification banners disabled." -ForegroundColor Yellow
    } elseif ($sub -eq "sound") {
        $soundOpt = ($Arg2 + "").ToLower()
        if ($soundOpt -in @("on", "true", "1", "enable")) {
            $cfg.notification_sound = $true
            Save-AlarmConfig $cfg
            Write-Host "🔊 Notification toast system sound enabled." -ForegroundColor Green
        } elseif ($soundOpt -in @("off", "false", "0", "disable")) {
            $cfg.notification_sound = $false
            Save-AlarmConfig $cfg
            Write-Host "🔇 Notification toast system sound disabled (silent toast)." -ForegroundColor Yellow
        } else {
            Write-Host "Notification toast sound: $(if ($cfg.notification_sound) { 'Enabled 🔊' } else { 'Silent 🔇' })"
            Write-Host "Toggle with: alarm notify sound [on|off]"
        }
    } elseif ($sub -eq "title") {
        if ($Arg2) {
            $cfg.notification_title = $Arg2
            Save-AlarmConfig $cfg
            Write-Host "✓ Notification title set to: `"$($cfg.notification_title)`"" -ForegroundColor Green
        } else {
            Write-Host "Usage: alarm notify title <custom_title>"
        }
    } elseif ($sub -eq "webhook") {
        if (-not $Arg2) {
            if ($cfg.webhook_url) {
                Write-Host "Current webhook URL: $($cfg.webhook_url)"
                Write-Host "To clear: alarm notify webhook clear"
            } else {
                Write-Host "No webhook configured."
                Write-Host "Usage: alarm notify webhook <url>"
            }
        } elseif ($Arg2 -in @("clear", "off", "disable")) {
            $cfg.webhook_url = ""
            Save-AlarmConfig $cfg
            Write-Host "✓ Webhook alerts disabled and cleared." -ForegroundColor Green
        } else {
            $cfg.webhook_url = $Arg2
            Save-AlarmConfig $cfg
            Write-Host "✓ Webhook URL configured: $($cfg.webhook_url)" -ForegroundColor Green
            Write-Host "💡 Test with: alarm notify test"
        }
    } elseif ($sub -eq "test") {
        Write-Host "🚀 Sending test notification..." -ForegroundColor Cyan
        Send-Toast "test" "This is a test notification from AI-Alarm!"
        Write-Host "✓ Test notification dispatched (desktop toast & webhook if configured)." -ForegroundColor Green
    } else {
        Write-Host @"
╔═══════════════════════════════════════════════════════════════════╗
║               AI-ALARM NOTIFICATION SYSTEM MANAGER                ║
╚═══════════════════════════════════════════════════════════════════╝

  Desktop Banners:    $(if ($cfg.desktop_notifications -ne $false) { 'Enabled 🔔' } else { 'Disabled 🔕' })
  Banner Chime:       $(if ($cfg.notification_sound) { 'Enabled 🔊' } else { 'Silent 🔇' })
  Banner Title:       $(if ($cfg.notification_title) { $cfg.notification_title } else { 'AI-Alarm' })
  Webhook Alert:      $(if ($cfg.webhook_url) { "Configured 🌐 ($($cfg.webhook_url))" } else { 'None ⚪' })

  AVAILABLE COMMANDS:
    alarm notify on               Enable desktop notification banners
    alarm notify off              Disable desktop notification banners
    alarm notify sound on|off     Toggle system chime in notification toasts
    alarm notify title <text>     Customize notification banner title
    alarm notify webhook <url>    Set Slack/Discord incoming webhook URL
    alarm notify webhook clear    Disable webhook alerts
    alarm notify test             Send test notification toast & webhook
"@
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

# Status command
if ($Command -in @("status", "-s", "--status")) {
    $cfg = Get-AlarmConfig
    $vol = $cfg.volume
    $barFilled = [Math]::Min(10, [Math]::Max(0, [Math]::Round(($vol + 5) / 10)))
    $bar = ("█" * $barFilled) + ("░" * (10 - $barFilled))
    $soundCount = (Get-ChildItem -Path $SoundDir -File -Include *.mp3,*.wav,*.m4a,*.aac,*.ogg,*.flac,*.aiff -ErrorAction SilentlyContinue | Measure-Object).Count

    function Check-HookFile($pathList) {
        foreach ($p in $pathList) {
            if (Test-Path $p) {
                try {
                    $h = Get-Content $p -Raw | ConvertFrom-Json
                    if ($h."task-finished-alarm") { return "✓ Configured ($($p.Replace($env:USERPROFILE, '~')))" }
                } catch {}
            }
        }
        return "○ Not configured"
    }

    $claudePath = Join-Path $env:USERPROFILE ".claude\settings.json"
    $claudeStatus = "○ Not installed"
    if (Test-Path $claudePath) {
        try {
            $c = Get-Content $claudePath -Raw | ConvertFrom-Json
            $has = $false
            if ($c.hooks -and $c.hooks.Stop) {
                foreach ($item in $c.hooks.Stop) {
                    if ($item.hooks) {
                        foreach ($h in $item.hooks) { if ($h.command -match "alarm") { $has = $true } }
                    }
                }
            }
            $claudeStatus = if ($has) { "✓ Configured (~/.claude/settings.json)" } else { "○ Not configured" }
        } catch { $claudeStatus = "○ Error parsing" }
    }

    $codexPath = Join-Path $env:USERPROFILE ".codex\config.toml"
    $codexStatus = "○ Not installed"
    if (Test-Path $codexPath) {
        $raw = Get-Content $codexPath -Raw
        $codexStatus = if ($raw -match "hooks\.Stop" -and $raw -match "alarm") { "✓ Configured (~/.codex/config.toml)" } else { "○ Not configured" }
    }

    $agyCliStatus  = Check-HookFile @((Join-Path $env:USERPROFILE ".gemini\antigravity-cli\hooks.json"), (Join-Path $env:USERPROFILE ".antigravity\hooks.json"))
    $agyIdeStatus  = Check-HookFile @((Join-Path $env:USERPROFILE ".gemini\antigravity-ide\hooks.json"), (Join-Path $env:USERPROFILE ".antigravity-ide\hooks.json"))
    $geminiCoreStatus = Check-HookFile @((Join-Path $env:USERPROFILE ".gemini\config\hooks.json"), (Join-Path $env:USERPROFILE ".gemini\antigravity\hooks.json"))

    $opencodePath = Join-Path $env:USERPROFILE ".config\opencode\plugins\task-finished-alarm.ts"
    $opencodeStatus = if (Test-Path $opencodePath) { "✓ Configured (~/.config/opencode/plugins/)" } else { "○ Not installed" }

    Write-Host @"

╔═══════════════════════════════════════════════════════════════════╗
║                 AI-ALARM STATUS & CONFIGURATION                   ║
╚═══════════════════════════════════════════════════════════════════╝

  AUDIO SETTINGS
  ───────────────
  🔊 Volume:              $vol%  [$bar]
  🔇 Mute State:          $(if ($cfg.muted) { "Muted 🔇 (Silent mode)" } else { "Active 🔊 (Audio enabled)" })

  NOTIFICATION SETTINGS
  ──────────────────────
  🔔 Desktop Banners:     $(if ($cfg.desktop_notifications -ne $false) { "Enabled 🔔 (Windows Toast)" } else { "Disabled 🔕" })
  🔊 Banner Chime:        $(if ($cfg.notification_sound) { "Enabled 🔊" } else { "Silent 🔇" })
  🏷️  Banner Title:        "$($cfg.notification_title)"
  🌐 Webhook URL:         $(if ($cfg.webhook_url) { $cfg.webhook_url } else { "None (Slack / Discord)" })

  AGENT HOOK INTEGRATIONS
  ───────────────────────
  🟣 Claude Code:         $claudeStatus
  🟢 OpenAI Codex:        $codexStatus
  🔵 Antigravity CLI:     $agyCliStatus
  🔵 Antigravity IDE:     $agyIdeStatus
  🔵 Gemini Ecosystem:    $geminiCoreStatus
  🟡 OpenCode:            $opencodeStatus

  SYSTEM & PATHS
  ──────────────
  📁 Sound Library:       $SoundDir ($soundCount tracks)
  ⚙️  Config File:         $ConfigFile
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
    $activeFiles = @()
    Get-ChildItem -Path $InstallDir -File -Filter "alarm_sound*.mp3" -ErrorAction SilentlyContinue | ForEach-Object {
        $activeFiles += $_.Name
    }

    $found = $false
    Get-ChildItem -Path $SoundDir -File | ForEach-Object {
        if ($_.Name -eq $Arg1 -or $_.BaseName -eq $Arg1) {
            if ($_.Name -in $activeFiles) {
                Write-Host "🛡️  Cannot remove '$($_.Name)': currently assigned to an active agent alert." -ForegroundColor Yellow
                Write-Host "💡 Reassign the agent to another sound first before deleting this track."
                $found = $true
                return
            }
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

# Find audio file (agent-specific -> global default -> first file in sound dir)
$audioFile = $null
if ($Command) {
    $agentSound = Join-Path $InstallDir "alarm_sound_$Command.mp3"
    if (Test-Path $agentSound) { $audioFile = $agentSound }
}
if (-not $audioFile) {
    $defSound = Join-Path $InstallDir "alarm_sound.mp3"
    if (Test-Path $defSound) { $audioFile = $defSound }
}
if (-not $audioFile) {
    $files = Get-ChildItem -Path $SoundDir -File -Include *.mp3,*.wav,*.m4a,*.aac,*.ogg,*.flac,*.aiff -ErrorAction SilentlyContinue
    if ($files -and $files.Count -gt 0) { $audioFile = $files[0].FullName }
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

# 3. Google Antigravity & Gemini Ecosystem (CLI, IDE, Gemini Core)
$hasAgy = (Test-Path (Join-Path $env:USERPROFILE ".gemini")) -or `
          (Test-Path (Join-Path $env:USERPROFILE ".antigravity")) -or `
          (Test-Path (Join-Path $env:USERPROFILE ".antigravity-ide")) -or `
          (Get-Command agy -ErrorAction SilentlyContinue)

if ($hasAgy) {
    $geminiConfigDir = Join-Path $env:USERPROFILE ".gemini\config"
    if (-not (Test-Path $geminiConfigDir)) { New-Item -ItemType Directory -Path $geminiConfigDir -Force | Out-Null }
    
    function Set-AgyHookFile($targetPath) {
        try {
            $dir = Split-Path -Parent $targetPath
            if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
            $hooks = @{}
            if (Test-Path $targetPath) {
                try { $hooks = Get-Content $targetPath -Raw | ConvertFrom-Json } catch {}
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
            $hooks | ConvertTo-Json -Depth 10 | Set-Content $targetPath
            return $true
        } catch { return $false }
    }

    Set-AgyHookFile (Join-Path $geminiConfigDir "hooks.json") | Out-Null
    Write-Host "  ✓ Antigravity global hook configured (~/.gemini/config/hooks.json)" -ForegroundColor Green

    $flavors = @("antigravity", "antigravity-cli", "antigravity-ide")
    foreach ($f in $flavors) {
        $fDir = Join-Path $env:USERPROFILE ".gemini\$f"
        if (Test-Path $fDir) {
            Set-AgyHookFile (Join-Path $fDir "hooks.json") | Out-Null
        }
    }

    $standalones = @((Join-Path $env:USERPROFILE ".antigravity"), (Join-Path $env:USERPROFILE ".antigravity-ide"))
    foreach ($s in $standalones) {
        if (Test-Path $s) {
            $sHook = Join-Path $s "hooks.json"
            Set-AgyHookFile $sHook | Out-Null
            Write-Host "  ✓ Antigravity standalone hook configured ($($sHook.Replace($env:USERPROFILE, '~')))" -ForegroundColor Green
        }
    }
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
