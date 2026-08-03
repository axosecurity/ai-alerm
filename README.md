# ai-alerm

Two small bash scripts for task-completion alerts.

## Scripts

### `alarm`
Plays the alarm sound (`alarm_sound.mp3`) loudly when run.

```bash
./alarm
```

### `notify`
Sends a Slack notification — `Your task is done @Axo solaman` — 10 times to your configured incoming webhook.

```bash
./notify
```

## Install

Both scripts can be symlinked or copied into a directory on your `PATH` (e.g. `/opt/homebrew/bin`) to run them from anywhere:

```bash
chmod +x alarm notify
cp alarm notify /opt/homebrew/bin/
```

## Configuration

- `alarm` expects `alarm_sound.mp3` to live in the same directory as the script.
- `notify` contains a Slack incoming webhook URL. Replace it with your own in the `WEBHOOK_URL` variable if needed.

## Requirements

- `afplay` (bundled with macOS)
- `curl` (bundled with macOS)
