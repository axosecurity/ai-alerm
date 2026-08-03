#!/usr/bin/env bash
set -euo pipefail

SKILL_DIR="${HOME}/.codex/skills/install-axo-ai-alarm"
mkdir -p "$SKILL_DIR"

cat > "$SKILL_DIR/SKILL.md" << 'EOF'
---
name: install-axo-ai-alarm
description: Installs the Axo AI Alarm (notify script) into the current project and configures a project-local Codex Stop hook. Trigger when the user says "install axo ai alarm", "setup axo alarm", "install ai-alerm", "install the alarm", "setup the alarm", "install ai alarm", "set up alarm", "setup alarm", "add the alarm", "add the notify script", "setup notify", "install notify script", "set up notifications when done", "notify me when the task is done", "alarm when finished", or similar.
---

# Install Axo AI Alarm (project-local)

When the user asks to install the Axo AI Alarm, follow these steps **exactly** in the current project only. Do not touch global Codex config.

## Steps

1. Create the directory if it does not exist:
   ```bash
   mkdir -p .codex/scripts
   ```

2. Download the notify script from the public repo:
   ```bash
   curl -fsSL https://raw.githubusercontent.com/axosecurity/ai-alerm/refs/heads/master/notify -o .codex/scripts/notify
   chmod +x .codex/scripts/notify
   ```

3. Create or update the project-local hooks file `.codex/hooks.json` with this exact content:
   ```json
   {
     "hooks": {
       "Stop": [
         {
           "hooks": [
             {
               "type": "command",
               "command": "$(git rev-parse --show-toplevel)/.codex/scripts/notify",
               "timeout": 30
             }
           ]
         }
       ]
     }
   }
   ```

4. Ensure hooks are enabled for this project. Create or update `.codex/config.toml`:
   ```toml
   [features]
   hooks = true
   ```

5. Confirm to the user:
   - `.codex/scripts/notify` exists and is executable
   - `.codex/hooks.json` contains the Stop hook pointing to the project-local notify script
   - Hooks are enabled in `.codex/config.toml`
   - Remind the user to run `/hooks` once and trust the new hook

## Important rules

- Only modify files inside the current project (`.codex/`).
- Never write to `~/.codex/hooks.json` or any global config.
- Use the absolute path resolved via `git rev-parse --show-toplevel` so the hook works even if Codex is started from a subdirectory.
- Do not change the Slack webhook inside the notify script unless the user explicitly asks.
EOF

echo "✓ Axo AI Alarm skill installed → $SKILL_DIR/SKILL.md"
