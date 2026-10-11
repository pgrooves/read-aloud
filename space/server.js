// Kokoro text-to-speech server for the Read Aloud page.
// POST /tts {text, voice, speed} -> audio/wav (16-bit mono, 24 kHz). GET /health -> {ok}.
import http from "node:http";
import { KokoroTTS } from "kokoro-js";

const PORT = +process.env.PORT || 7860;
const MAX_CHARS = 1000;
// Only these pages may call the server from a browser
const ALLOWED_ORIGINS = (process.env.ALLOWED_ORIGINS || "https://pgrooves.github.io").split(",");

const tts = await KokoroTTS.from_pretrained("onnx-community/Kokoro-82M-v1.0-ONNX", {
  dtype: process.env.DTYPE || "fp32",
  device: "cpu",
});
const VOICES = new Set(Object.keys(tts.voices));

// One generation at a time; requests wait their turn
let queue = Promise.resolve();
const serialize = (fn) => {
  const job = queue.then(fn);
  queue = job.catch(() => {});
  return job;
};

function wav(samples, rate) {
  const buf = Buffer.alloc(44 + samples.length * 2);
  buf.write("RIFF", 0); buf.writeUInt32LE(36 + samples.length * 2, 4); buf.write("WAVE", 8);
  buf.write("fmt ", 12); buf.writeUInt32LE(16, 16); buf.writeUInt16LE(1, 20); buf.writeUInt16LE(1, 22);
  buf.writeUInt32LE(rate, 24); buf.writeUInt32LE(rate * 2, 28); buf.writeUInt16LE(2, 32); buf.writeUInt16LE(16, 34);
  buf.write("data", 36); buf.writeUInt32LE(samples.length * 2, 40);
  for (let i = 0; i < samples.length; i++) {
    const s = Math.max(-1, Math.min(1, samples[i]));
    buf.writeInt16LE(s < 0 ? s * 0x8000 : s * 0x7fff, 44 + i * 2);
  }
  return buf;
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let body = "";
    req.on("data", (c) => { body += c; if (body.length > 20000) reject(new Error("request too large")); });
    req.on("end", () => { try { resolve(JSON.parse(body)); } catch { reject(new Error("invalid JSON")); } });
    req.on("error", reject);
  });
}

http.createServer(async (req, res) => {
  const origin = req.headers.origin;
  if (origin && ALLOWED_ORIGINS.includes(origin)) {
    res.setHeader("Access-Control-Allow-Origin", origin);
    res.setHeader("Vary", "Origin");
    res.setHeader("Access-Control-Allow-Headers", "Content-Type");
    res.setHeader("Access-Control-Allow-Methods", "GET, POST, OPTIONS");
  }
  const send = (code, obj) => { res.writeHead(code, { "Content-Type": "application/json" }); res.end(JSON.stringify(obj)); };
  const path = req.url.split("?")[0];

  if (req.method === "OPTIONS") { res.writeHead(204); return res.end(); }
  if (req.method === "GET" && (path === "/health" || path === "/")) return send(200, { ok: true });
  if (req.method !== "POST" || path !== "/tts") return send(404, { error: "not found" });

  try {
    const { text, voice = "af_heart", speed = 1 } = await readJson(req);
    if (typeof text !== "string" || !text.trim()) return send(400, { error: "text is required" });
    if (text.length > MAX_CHARS) return send(400, { error: `text is over ${MAX_CHARS} characters` });
    if (!VOICES.has(voice)) return send(400, { error: "unknown voice" });
    const s = Math.min(2, Math.max(0.5, +speed || 1));
    const t = Date.now();
    const audio = await serialize(() => tts.generate(text, { voice, speed: s }));
    const out = wav(audio.audio, audio.sampling_rate);
    console.log(`${text.length} chars -> ${(audio.audio.length / audio.sampling_rate).toFixed(1)}s audio in ${Date.now() - t}ms`);
    res.writeHead(200, { "Content-Type": "audio/wav", "Content-Length": out.length });
    res.end(out);
  } catch (e) {
    console.error(e);
    send(500, { error: String(e.message || e) });
  }
}).listen(PORT, () => console.log(`Kokoro server listening on ${PORT}`));
