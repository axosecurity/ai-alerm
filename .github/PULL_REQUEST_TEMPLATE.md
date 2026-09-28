## Pull Request: Add New Sound to ai-alerm 🎵

Thank you for contributing to **ai-alerm**! Please verify that your sound file passes this review checklist before submitting.

---

### 📋 Contributor Review Checklist

- [ ] **Audio File Placed:** The file is located directly in `sound/` (e.g., `sound/my-sound.mp3`).
- [ ] **Supported Format:** The file is `.mp3` or `.wav` (MP3 strongly preferred for universal OS compatibility).
- [ ] **Duration Limit:** The audio length is between **5 and 25 seconds**.
- [ ] **File Size Limit:** The file size is **under 1 MB** (keeps git lightweight).
- [ ] **Loudness Normalized:** Audio has clean sound and normalized loudness (~ -16 LUFS, no clipping or harsh distortion).
- [ ] **Metadata Entry:** Added corresponding entry to `sound/sounds.json` with `title`, `description`, `duration`, `category`, and `contributor`.
- [ ] **Valid JSON:** Validated that `sound/sounds.json` has valid syntax (`node -e 'require("./sound/sounds.json")'`).
- [ ] **Licensing:** Audio is royalty-free, CC0, public domain, or your own original creation.

---

### 📝 Sound Details

* **Sound Title:**
* **Category:** (`zikir` | `durood` | `istighfar` | `adhan` | `quran` | `chime`)
* **Duration:** (e.g., `12.5s`)
* **Description:**
* **Contributor Handle:** `@<your-github-username>`

---

### 🧪 Verification
- [ ] Tested locally using `./install.sh --select-only` and verified live preview playback works (`[Space]`).
