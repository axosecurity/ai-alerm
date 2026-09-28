# Contributing Sounds to ai-alerm 🎵

We welcome community contributions! Whether you have a beautiful recitation of a zikir, a peaceful Durood, a serene adhan, or a pleasant productivity chime, your contribution helps thousands of developers stay mindful and productive while coding.

---

## 🎧 Audio Guidelines

To ensure the best experience for all users:

| Metric | Recommendation |
|---|---|
| **Format** | `.mp3` or `.wav` (MP3 preferred for small file size) |
| **Duration** | **5 to 25 seconds** (ideal length for a task-finished alert) |
| **File Size** | Under **1 MB** (keeps git repo lightweight) |
| **Quality** | Clean audio, no harsh static, normalized loudness (~ -16 LUFS) |
| **License** | Must be royalty-free, CC0, public domain, or your own recording |

---

## 🚀 3 Steps to Add Your Sound

### Step 1: Fork and Clone the Repository
```bash
git clone https://github.com/<your-username>/ai-alerm.git
cd ai-alerm
```

### Step 2: Add Your Audio File to `sound/`
Copy your `.mp3` into the `sound/` folder:
```bash
cp /path/to/my-zikir.mp3 sound/my-zikir.mp3
```

### Step 3: Add Metadata to `sound/sounds.json`
Open [`sound/sounds.json`](sound/sounds.json) and add an entry for your track:

```json
  "my-zikir.mp3": {
    "title": "Subhanallah wa Bihamdihi",
    "description": "Glory be to Allah and praise is due to Him",
    "duration": "12.0s",
    "category": "zikir",
    "contributor": "your-github-username",
    "tags": ["zikir", "tasbeeh", "peaceful"]
  }
```

#### Available Categories:
* `zikir` (General remembrance & tasbeeh)
* `durood` (Salawat & blessings upon the Prophet)
* `istighfar` (Repentance & seeking forgiveness)
* `adhan` (Call to prayer)
* `chime` (Soft bells, tones, and neutral alerts)
* `quran` (Short ayah or verse recitation)

---

## 🧪 Test Your Sound Locally

Test that your sound appears and plays smoothly in the interactive menu:

```bash
./install.sh --select-only
```
- Use `[Space]` to test the live preview.
- Ensure your title and description render cleanly.

---

## 📬 Submit Your Pull Request

1. Commit your changes:
   ```bash
   git add sound/my-zikir.mp3 sound/sounds.json
   git commit -m "feat(audio): add Subhanallah wa Bihamdihi by @your-username"
   git push origin my-new-sound
   ```
2. Open a Pull Request on GitHub.
3. Once reviewed and merged, all users worldwide will be able to download your sound simply by running `alarm update`! 🎉
