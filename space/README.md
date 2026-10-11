# Read Aloud voice server

Kokoro text-to-speech server used by https://pgrooves.github.io/read-aloud/.

- `GET /health` returns `{"ok": true}`.
- `POST /tts` with JSON `{"text": "...", "voice": "af_heart", "speed": 1}` returns a 24 kHz WAV.

Only browser requests from the origins in `ALLOWED_ORIGINS` (default `https://pgrooves.github.io`) are allowed.

## Deploy to Google Cloud Run

In Cloud Shell (https://shell.cloud.google.com), with your project selected:

```
git clone https://github.com/pgrooves/read-aloud.git && bash read-aloud/space/deploy-cloud-run.sh
```

To update after changing the server, run `cd ~/read-aloud && git pull && bash space/deploy-cloud-run.sh`.

## Run locally

```
npm install && npm start
```
