#!/usr/bin/env bash
# Tinker AI — ASUS Ascent QN10 (Snapdragon X2 Elite) & Dragonwing IQ10 Runner (Guide #54)
set -euo pipefail

DEV="ascent_qn10_32g"
MODEL="./models/Qwen3.5-27B-Q4_K_M.gguf"
CTX="16384"
PORT="8080"

echo "=== [1/2] Probing Qualcomm FastRPC Hexagon NPU & Memory Ceiling ($DEV) ==="
ls -l /dev/fastrpc-* 2>/dev/null || echo "INFO: /dev/fastrpc-* not present; running on Oryon CPU + Adreno GPU."
free -h

echo "=== [2/2] Launching llama-server with Q8_0 KV Cache ==="
exec llama-server \
  -m "$MODEL" \
  -c "$CTX" -fa on \
  --cache-type-k q8_0 --cache-type-v q8_0 \
  --host 127.0.0.1 --port "$PORT"
