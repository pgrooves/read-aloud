---
title: Read Aloud TTS
emoji: 🔊
colorFrom: blue
colorTo: indigo
sdk: docker
app_port: 7860
pinned: false
short_description: Kokoro text-to-speech server for the Read Aloud page
---

Kokoro text-to-speech server used by https://pgrooves.github.io/read-aloud/.

- `GET /health` returns `{"ok": true}`.
- `POST /tts` with JSON `{"text": "...", "voice": "af_heart", "speed": 1}` returns a 24 kHz WAV.

Only browser requests from the origins in `ALLOWED_ORIGINS` (default `https://pgrooves.github.io`) are allowed.
