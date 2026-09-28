# Contributing Sounds to ai-alerm 🎵

We welcome community contributions! Whether you have a beautiful recitation of a zikir, a peaceful Durood, a serene adhan, a Quranic ayah, or a gentle productivity chime, your contribution helps developers stay mindful, calm, and productive while coding.

All merged sounds become available globally across **macOS, Linux (Debian, Arch, Alpine), Windows, and WSL** via the `alarm update` sync command.

---

## 🎧 Audio Guidelines

To ensure high quality and seamless playback across every operating system:

| Metric | Recommendation | Details |
|---|---|---|
| **Format** | **`.mp3`** (or `.wav`) | MP3 provides the smallest file size and works natively on macOS, Linux, and Windows without codecs. |
| **Duration** | **5 to 25 seconds** | Ideal length for a completion alert (long audio tracks should be trimmed). |
| **File Size** | Under **1 MB** | Keeps the repository lightweight and downloads fast. |
| **Quality** | Clean & Normalized | Audio normalized to ~ -16 LUFS without clipping, background hiss, or harsh distortion. |
| **License** | Open & Royalty-Free | Must be CC0, public domain, or your own original recording/production. |

---

## 🚀 3 Steps to Add Your Sound

### Step 1: Fork and Clone the Repository
```bash
git clone https://github.com/<your-username>/ai-alerm.git
cd ai-alerm
```

### Step 2: Add Your Audio File to `sound/`
Copy your `.mp3` file directly into the `sound/` folder:
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
* `quran` (Short ayah or verse recitation)
* `chime` (Soft bells, tones, and neutral productivity chimes)

---

## 🧪 Test Your Sound Locally

Test that your sound appears, filters, and plays smoothly in the interactive TUI selector:

```bash
# Test in interactive selector:
./install.sh --select-only

# Or test via direct command:
./install.sh set my-zikir.mp3
./alarm
```

* Press `[Space]` to verify the live audio preview.
* Ensure your title, category, and description render cleanly.

---

## 📬 Submit Your Pull Request

1. Commit your changes with a conventional commit message:
   ```bash
   git add sound/my-zikir.mp3 sound/sounds.json
   git commit -m "feat(audio): add Subhanallah wa Bihamdihi by @your-username"
   git push origin my-new-sound
   ```
2. Open a Pull Request on GitHub.
3. Once reviewed and merged, all users worldwide across all operating systems will be able to download your sound instantly by running:
   ```bash
   alarm update
   ```
   🎉 Your contribution will also be credited in the interactive selector and search results!
