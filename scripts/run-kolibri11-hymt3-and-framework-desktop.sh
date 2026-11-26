#!/usr/bin/env bash
# Tinker AI — Aleph Alpha Kolibri 1.1 (75B-A3.4B), Tencent Hy-MT3-30B-A3B & Framework Desktop 128GB Launcher (Guide #68)
set -euo pipefail

MODE="kolibri11_vllm_1m"
KOLIBRI="Aleph-Alpha/Kolibri-1.1"
HYMT3="./models/Hy-MT3-30B-A3B-Q4_K_M.gguf"
CTX="262144"
PORT="8000"

echo "=== [Host Preflight] Auditing Unified Memory (Framework Desktop 128GB Mini-ITX / Mac) or GPU VRAM ==="
grep -E 'MemTotal|MemAvailable' /proc/meminfo 2>/dev/null || sysctl hw.memsize 2>/dev/null || true

if [ "$MODE" = "kolibri11_vllm_1m" ]; then
  echo "=== [Aleph Alpha Kolibri 1.1 · 75B-A3.4B Sparse-Attention MoE] Launching vLLM with kolibri1 Parser (Ctx=$CTX) ==="
  exec vllm serve "$KOLIBRI" \
    --reasoning-parser kolibri1 \
    --tool-call-parser kolibri1 \
    --enable-auto-tool-choice \
    --kv-cache-dtype fp8 \
    --max-model-len "$CTX" \
    --hf-overrides "{\"max_position_embeddings\": $CTX}" \
    --port "$PORT"
elif [ "$MODE" = "kolibri11_gguf_framework128" ]; then
  echo "=== [Kolibri 1.1 75B-A3.4B GGUF] Running on Framework Desktop 128GB (104GB UMA) / 64GB Mac mini M5 Pro ==="
  exec llama-server -m "$KOLIBRI" \
    -ngl 99 -fa on \
    --cache-type-k q8_0 --cache-type-v q8_0 \
    --temp 1.0 --top-p 0.99 --top-k 128 \
    -c "$CTX" --host 127.0.0.1 --port "$PORT"
elif [ "$MODE" = "hymt3_30b_a3b_fast_translate" ]; then
  echo "=== [Tencent Hunyuan Hy-MT3-30B-A3B · 102-Lang Fast-Thinking MoE] Zero-Thinking Tag-Safe Localization Server ==="
  exec llama-server -m "$HYMT3" \
    -ngl 99 -fa on \
    --cache-type-k q8_0 --cache-type-v q8_0 \
    --temp 0.2 --top-p 0.90 \
    -c 32768 --host 127.0.0.1 --port "$PORT"
elif [ "$MODE" = "dual_resident_framework_128gb" ]; then
  echo "=== [Framework Desktop 128GB Dual-Resident] Co-Hosting Kolibri 1.1 75B (~43.9GB) + Hy-MT3-30B-A3B (~18.3GB) ==="
  llama-server -m "$KOLIBRI" -ngl 99 -fa on --cache-type-k q8_0 --cache-type-v q8_0 -c 131072 --port "$PORT" &
  PID_K=$!
  HY_PORT=$((PORT + 1))
  llama-server -m "$HYMT3" -ngl 99 -fa on --cache-type-k q8_0 --cache-type-v q8_0 -c 32768 --port "$HY_PORT" &
  PID_H=$!
  echo "Co-hosted Kolibri 1.1 on :$PORT (PID $PID_K) and Hy-MT3-30B-A3B on :$HY_PORT (PID $PID_H)"
  wait "$PID_K" "$PID_H"
else
  echo "Unknown STACK_MODE=$MODE" >&2
  exit 1
fi
