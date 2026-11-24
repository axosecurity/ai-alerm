# Implementation Plan: Context-Rich Slack Notifications, Subagent Spam Prevention & Dedicated Team Milestone Skill

**Date:** 2026-11-24  
**Author:** Antigravity  
**Repository:** `axosecurity/ai-alerm`  
**Branch:** `feature/rich-slack-notifications`  
**Target:** 
1. Enrich Stop hook notifications with zero-token contextual parameters (timestamp, working directory, git branch, repo name, caller agent).
2. Eliminate subagent notification spam that floods Slack during parallel agent execution.
3. Build a dedicated Milestone & Attention-Required Dispatcher (`alarm milestone`) and a reusable Agent Skill (`agent-notify`).
4. Establish a global agent protocol in `GEMINI.md` / `AGENTS.md` so root agents reliably dispatch verified completion / review alerts.

---

## 1. Problem Statement & Architecture

### The Problem
1. **Information Scarcity**: When an agent finishes, the current Stop hook sends a bare generic message (`Task completed by Google Antigravity!`). It lacks timestamp, directory, project name, or git branch.
2. **Subagent Flooding & False Positives**: Antigravity and Claude Code frequently spawn short-lived, parallel subagents (e.g. researchers, debuggers, verifiers). Each subagent stopping triggers the global `Stop` hook, flooding Slack with dozens of identical messages.
3. **Loss of Signal**: The user cannot tell which message represents the **final mission completion** or an **urgent request for user guidance**, versus an intermediate micro-task completion by a worker subagent.

### The Solution: Two-Tier Architecture

```
                    ┌──────────────────────────────────────────────┐
                    │               Agent Task Begins              │
                    └──────────────────────┬───────────────────────┘
                                           │
                       ┌───────────────────┴───────────────────┐
                       │ Spawns parallel subagents (workers)   │
                       └───────────────────┬───────────────────┘
                                           │
                   Worker subagents complete intermediate work
            ┌──────────────────────────────┴──────────────────────────────┐
            ▼                                                             ▼
┌───────────────────────────────┐             ┌─────────────────────────────────────────┐
│     TIER 1: Stop Hook         │             │    TIER 2: Root Milestone Skill / CLI   │
│ (Routine lifecycle event)     │             │ (Verified Root Dispatch)                │
├───────────────────────────────┤             ├─────────────────────────────────────────┤
│ • Plays local audio alert     │             │ • Triggered ONLY by Root / Lead Agent   │
│ • Subagent suppression:       │             │ • Runs `alarm milestone` via Skill      │
│   Detects subagent context    │             │ • Sends High-Priority Slack Card:       │
│   (via stdin/env) and         │             │   - 🏁 Mission Complete / 🚨 Attention │
│   suppresses Slack webhook    │             │   - Task & Session Name                 │
│   OR sends muted compact ping │             │   - What was accomplished               │
│ • Zero AI tokens used         │             │   - What user decision/action is needed │
└───────────────────────────────┘             │   - Verified Root Badge (No False Pos)  │
                                              │ • Zero AI tokens used                   │
                                              └─────────────────────────────────────────┘
```

---

## 2. Technical Design & Components

### 2.1 Component 1: `ai-alerm` CLI Enhancements (`alarm` & `bin/alarm.js`)

#### A. Enhanced Context Harvester
Extracts host system context safely without latency or LLMs:
- **Timestamp**: Local time formatted (`YYYY-MM-DD HH:mm:ss %Z`).
- **Working Directory**: `$PWD` (or payload `cwd`).
- **Project Name**: Base directory or git root name.
- **Git Branch**: `git rev-parse --abbrev-ref HEAD 2>/dev/null`.
- **Caller Agent**: `$1` or detected process (`antigravity`, `claude`, etc.).

#### B. Subagent Flood Suppression in Stop Hook
- When Antigravity or Claude invokes the `Stop` hook, check if the session is a subagent (via stdin payload fields like `isSubagent`, `parentSessionId`, or env markers).
- Add a configuration toggle in `~/.ai-alarm/config.json`:
  - `"suppress_subagent_webhooks": true` (default: `true`)
  - `"routine_hook_webhook": false` (optional: reserve Slack webhook only for milestones, or send compact pings for root sessions).

#### C. New Command: `alarm milestone` / `alarm notify-user`
A dedicated command for root agents to report genuine completion or request user input:

```bash
alarm milestone \
  --agent "Google Antigravity" \
  --task "Fix checkout authentication race condition" \
  --status "completed" \
  --summary "Resolved token race condition in AuthContext, added regression tests, all tests passing." \
  --action "Please review PR #42 and approve deployment to staging."
```

Supported statuses:
- `completed`: 🏁 Mission Accomplished (Task fully resolved).
- `review_needed`: 🚨 User Attention Required (Design decision, feedback, or approval gate).
- `failed`: ⚠️ Blocked / Error Encountered.

### 2.2 Component 2: Slack Block Kit Formatting

#### Dedicated Milestone Card (Tier 2):
```json
{
  "text": "🏁 *[TEAM DISPATCH]* Task Completed by *Google Antigravity*\n📋 *Task:* Fix checkout race condition\n📁 *Project:* `conversora` (`feature/auth-fix`)\n🕒 *Time:* 2026-11-24 10:45:00\n👉 *Action Needed:* Please review PR #42",
  "blocks": [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "🏁 Mission Complete: Google Antigravity",
        "emoji": true
      }
    },
    {
      "type": "context",
      "elements": [
        {
          "type": "mrkdwn",
          "text": "🛡️ *Verified Root Milestone* • Not a transient sub-agent"
        }
      ]
    },
    {
      "type": "section",
      "fields": [
        { "type": "mrkdwn", "text": "*Task / Objective:*\nFix checkout authentication race condition" },
        { "type": "mrkdwn", "text": "*Status:*\n✅ Completed" },
        { "type": "mrkdwn", "text": "*Project & Branch:*\n📦 `conversora` (`feature/auth-fix`)" },
        { "type": "mrkdwn", "text": "*Timestamp:*\n🕒 2026-11-24 10:45:00 +06" }
      ]
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*What Was Accomplished:*\nResolved token race condition in AuthContext, added regression tests, all tests passing."
      }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*👉 Action Needed from You:*\nPlease review PR #42 and approve deployment to staging."
      }
    },
    {
      "type": "section",
      "text": {
        "type": "mrkdwn",
        "text": "*Working Directory:*\n📂 `/Users/solaman/project/conversora`"
      }
    }
  ]
}
```

### 2.3 Component 3: Reusable Agent Skill (`agent-notify`)
Create an agent skill at:
- `~/.gemini/config/skills/agent-notify/SKILL.md` (and symlinked/installed to `~/.agents/skills/agent-notify/`)

The skill instructs agents on when and how to call `alarm milestone`:
- Explains that worker subagents **must never** call this tool.
- Explains that the root agent **must call it** when reaching an approval checkpoint, pausing for user input, or completing the full user request.

### 2.4 Component 4: Global Protocol in `GEMINI.md` / `AGENTS.md`
Add a dedicated rule section to global instructions (`~/.gemini/GEMINI.md` and `~/.codex/AGENTS.md`):
- **Team Milestone Notification Protocol**:
  - Directs root agents to execute `alarm milestone` when finished or when user action is required.
  - Prohibits subagents from triggering user-facing webhook notifications.

---

## 3. Step-by-Step Implementation Phases

### Phase 1: Core CLI Updates in `ai-alerm`
1. Update `alarm` (Bash script) and `bin/alarm.js` (Node.js):
   - Implement `alarm milestone` command with option parsing (`--task`, `--summary`, `--action`, `--status`, `--agent`).
   - Implement subagent detection / suppression logic for the routine `Stop` hook.
   - Build rich Slack Block Kit payloads for both milestone and routine events.
2. Update `alarm notify test` to allow testing both routine alerts and milestone cards.

### Phase 2: Skill Creation (`agent-notify`)
1. Create `~/.gemini/config/skills/agent-notify/SKILL.md` with:
   - Command line invocation templates.
   - Strict root-agent-only rules.
   - Example triggers: when task is done, when evaluation gate is reached, when stuck on credentials.

### Phase 3: Global Instruction Update
1. Update `~/.gemini/GEMINI.md` to add the `<!-- agent-milestone-notification -->` protocol.
2. Ensure consistent behavior across Antigravity, Claude Code, and Codex.

### Phase 4: Local Deployment & System Sync
1. Sync updated files to `/Users/solaman/.ai-alarm/`.
2. Verify `/opt/homebrew/bin/alarm` links and executes cleanly.

---

## 4. Verification & Testing Strategy

1. **Subagent Suppression Test**:
   - Simulate a subagent stopping with `isSubagent: true` on stdin; verify local sound plays but Slack is not spammed.
2. **Root Milestone Dispatch Test**:
   - Execute `alarm milestone --task "Test Task" --summary "Ran automated tests" --action "Check Slack"`.
   - Verify Slack receives the verified root badge, task summary, project, git branch, and timestamp.
3. **Skill Verification**:
   - Verify the skill is detected by the agent skill registry and can be invoked seamlessly.
4. **Zero-Token Verification**:
   - Confirm all scripts execute natively in Bash/Node with 0 API calls to LLMs.

---

## 5. Edge Cases & Risks

- **Missing Parameters**: If `--action` or `--summary` are omitted, default to clean fallback values.
- **Offline / Invalid Webhook**: Curl commands run with short timeouts and in the background (`&`), ensuring the agent is never blocked.
- **Mobile Push Rendering**: The `text` fallback string contains all essential fields so mobile notifications without block support still display the task, project, branch, and action needed.
