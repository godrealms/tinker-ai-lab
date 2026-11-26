#!/usr/bin/env bash
# Tinker AI Maker Lab — Raspberry Pi 5 100% Offline Voice Assistant Loop (Guide #19)
set -euo pipefail

MIC="plughw:1,0"
WHISPER_BIN="${WHISPER_BIN:-./whisper-cli}"
WHISPER_MODEL="./models/ggml-base-q5_1.bin"
LLM_MODEL="qwen2.5:3b"
PIPER_VOICE="./voices/zh_CN-huayan-medium.onnx"

echo "=== [1/4] Recording 4s Voice Command from $MIC (16kHz Mono PCM) ==="
arecord -D "$MIC" -f S16_LE -r 16000 -c 1 -d 4 /tmp/pi5-query.wav

echo "=== [2/4] Running Local Whisper.cpp STT (4 Cortex-A76 Threads) ==="
USER_TEXT=$("$WHISPER_BIN" -m "$WHISPER_MODEL" -t 4 -np -nt -f /tmp/pi5-query.wav | tr -d '\n' | sed 's/^[[:space:]]*//')
echo "Heard: ${USER_TEXT:-<silence>}"

if [ -z "$USER_TEXT" ]; then
  echo "No speech detected; skipping LLM."
  exit 0
fi

echo "=== [3/4] Querying Local Ollama ($LLM_MODEL, num_ctx=2048) ==="
REPLY=$(curl -sS http://127.0.0.1:11434/api/generate -d "{
  \"model\": \"$LLM_MODEL\",
  \"stream\": false,
  \"options\": { \"num_ctx\": 2048, \"temperature\": 0.3, \"num_predict\": 120 },
  \"prompt\": \"Answer concisely in 1-2 spoken sentences without markdown symbols: $USER_TEXT\"
}" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("response","").strip())')

echo "Reply: $REPLY"

echo "=== [4/4] Synthesizing Speech via Local Piper TTS (Half-Duplex Playback) ==="
if command -v piper >/dev/null 2>&1; then
  printf "%s" "$REPLY" | piper --model "$PIPER_VOICE" --output-raw | aplay -r 22050 -f S16_LE -t raw -
else
  echo "[INFO] Piper binary not found in PATH; printed text response above."
fi
