# Implementation Plan: Context-Rich Slack Webhook Notifications for AI-Alarm

**Date:** 2026-11-24  
**Author:** Antigravity  
**Repository:** `axosecurity/ai-alerm`  
**Branch:** `feature/rich-slack-notifications`  
**Target:** Enhance Stop hook notifications with zero-token contextual parameters (timestamp, working directory, git branch, repository name, caller agent).

---

## 1. Executive Summary & Objectives

### Current Problem
Currently, when an agent stops (such as Google Antigravity or Claude Code), the Stop hook calls:
- `/opt/homebrew/bin/alarm antigravity` or `/opt/homebrew/bin/alarm claude`
- The script dispatches a single-line string to the configured Slack incoming webhook:
  ```json
  {"text":"🔔 [AI-Alarm] Task completed by Google Antigravity!"}
  ```
Because all agent sessions send this identical bare message, the user cannot determine:
- Which specific project or workspace just finished.
- Which working directory was active.
- Which git branch was touched.
- The exact local timestamp when the event triggered.
- Which session or agent instance produced the alert when running multiple concurrent tasks.

### Objectives
1. **Zero-Token Context Gathering**: Gather rich operational context directly from the host system (`date`, `$PWD`, `git`, stdin hook payload) without invoking any LLMs, incurring zero token costs and zero latency.
2. **Context-Rich Slack Block Kit & Fallback Message**: Format the notification using Slack Block Kit sections/fields (clean card view with Agent, Time, Project, Branch, Working Directory) along with an informative fallback `text` for mobile notifications.
3. **Multi-Agent & Platform Support**: Update both the standalone Bash executable (`alarm`) and the Node.js implementation (`bin/alarm.js`) so that Antigravity, Claude Code, OpenAI Codex, and OpenCode benefit equally.
4. **Deploy & Validate**: Ensure the active install at `~/.ai-alarm` is updated and test the hook safely.

---

## 2. Technical Architecture & Design

### 2.1 Context Parameters Collected (Zero AI Tokens)
| Parameter | Source | Example Value |
|---|---|---|
| **Agent / LLM** | Argument (`$1`) / stdin / env | `Google Antigravity`, `Claude Code`, `OpenAI Codex` |
| **Local Timestamp** | System `date "+%Y-%m-%d %H:%M:%S %Z"` | `2026-11-24 10:35:12 +06` |
| **Working Directory** | `$PWD` or stdin payload `cwd` | `/Users/solaman/project/conversora` |
| **Project / Workspace** | Directory basename or git root | `conversora` |
| **Git Branch** | `git rev-parse --abbrev-ref HEAD` | `feature/payment-gateway` (or `(none)`) |
| **Host / Machine** | `hostname -s` or `whoami` | `MacBook-Pro` |
| **Stop Reason** | Piped stdin JSON (`terminationReason`) | `Task Completed` / `Normal Termination` |

### 2.2 Slack Payload Format
The payload sent to `webhook_url` will support both Slack Block Kit (for rich display on Slack desktop/web) and a formatted fallback `text` (for push notifications and Discord/generic webhook compatibility):

```json
{
  "text": "🔔 *[AI-Alarm]* Task completed by *Google Antigravity*\n📁 *Project:* `conversora` (`master`)\n🕒 *Time:* 2026-11-24 10:35:12\n📍 *Dir:* `/Users/solaman/project/conversora`",
  "blocks": [
    {
      "type": "header",
      "text": {
        "type": "plain_text",
        "text": "🔔 Task Finished: Google Antigravity",
        "emoji": true
      }
    },
    {
      "type": "section",
      "fields": [
        {
          "type": "mrkdwn",
          "text": "*Agent:*\n🤖 Google Antigravity"
        },
        {
          "type": "mrkdwn",
          "text": "*Timestamp:*\n🕒 2026-11-24 10:35:12"
        },
        {
          "type": "mrkdwn",
          "text": "*Project / Repo:*\n📦 `conversora`"
        },
        {
          "type": "mrkdwn",
          "text": "*Git Branch:*\n🌿 `master`"
        }
      ]
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

---

## 3. Implementation Phases

### Phase 1: Context Harvester in Bash (`alarm`)
- Inspect stdin non-blockingly (e.g. `read -t 0.05` or checking if stdin is a pipe) to extract Antigravity's JSON hook payload if provided (`cwd`, `workspacePaths`, etc.).
- Fallback to `$PWD` if stdin is empty or not JSON.
- Resolve Git branch safely (`git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "(no git)"`).
- Format local timestamp (`date "+%Y-%m-%d %H:%M:%S %Z"`).
- Extract project folder name (`basename "$WORK_DIR"`).

### Phase 2: Webhook Dispatcher in Bash (`alarm`)
- Rewrite `send_desktop_notification()` in `/Users/solaman/project/ai-alerm/alarm`:
  - Construct both compact markdown fallback text and Slack Block Kit JSON.
  - Send asynchronous POST request via `curl` to `webhook_url`.
  - Maintain desktop notification banner via `osascript` (macOS) / `notify-send` (Linux) with project title.

### Phase 3: Node.js Implementation Update (`bin/alarm.js`)
- Update `sendDesktopNotification()` in `bin/alarm.js` to match the enriched Slack format.
- Ensure `alarm notify test` dispatches the new rich layout so the user can verify the change immediately.

### Phase 4: Installer & System Sync
- Update `install.sh` if needed to ensure file permissions and links.
- Copy/sync the updated scripts from `ai-alerm` to active user installation directory:
  - `/Users/solaman/.ai-alarm/alarm`
  - `/Users/solaman/.ai-alarm/bin/alarm.js`

---

## 4. Verification & Testing Strategy

1. **Test Command Verification**:
   - Run `alarm notify test` in a sample git repo.
   - Verify Slack channel receives the formatted Block Kit card with correct project name, branch, and time.
2. **Hook Simulation**:
   - Pipe JSON payload into `/opt/homebrew/bin/alarm antigravity`:
     ```bash
     echo '{"cwd":"/Users/solaman/project/conversora","terminationReason":"goal_achieved"}' | /opt/homebrew/bin/alarm antigravity
     ```
   - Verify immediate exit code 0, non-blocking audio play, and Slack message delivery.
3. **Edge Case Tests**:
   - Non-git folder execution (ensures no git error in message).
   - Empty stdin (runs as standard CLI without hanging).
   - Invalid or missing webhook URL (fails gracefully without interrupting agent).

---

## 5. Edge Cases & Risk Mitigation

- **Piped Stdin Hangs**: Reading stdin in shell scripts can block if stdin is open but empty.
  *Mitigation*: Use non-blocking read checks (`read -t 0.1` or `[ ! -t 0 ]` with timeout) so the hook never delays the agent.
- **Webhook API Changes**: If a non-Slack webhook (Discord / generic) is used, Block Kit might be ignored or rejected.
  *Mitigation*: Ensure top-level `text` field contains all vital details so any webhook service displays the complete information even without Block Kit support.
- **Git Command Failures**: If run outside a git repository or inside submodules.
  *Mitigation*: Guard all git queries with `2>/dev/null` and sensible defaults (`N/A` or folder name).
