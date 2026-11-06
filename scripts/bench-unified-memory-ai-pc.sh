#!/usr/bin/env bash
# Tinker AI — Unified-Memory AI PC Fixed Benchmark: RTX Spark (N1X) / Ryzen AI Max+ PRO 495 (Guide #37)
set -euo pipefail

MODEL="./models/Qwen3-30B-A3B-Q4_K_M.gguf"
BIN="./build/bin"
SUSTAIN="600"
OUT="bench-$(hostname)-$(date +%Y%m%d-%H%M).md"

echo "=== [1/4] Model integrity ==="
sha256sum "$MODEL" | tee -a "$OUT"

echo "=== [2/4] Platform snapshot ==="
{
  echo "- arch: $(uname -m)"
  if command -v nvidia-smi >/dev/null 2>&1; then
    echo "- gpu: $(nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader)"
  fi
  for f in /sys/class/drm/card*/device/mem_info_gtt_total; do
    [ -r "$f" ] && echo "- amdgpu GTT total: $(awk '{printf "%.1f GB", $1/1024/1024/1024}' "$f")"
  done
} | tee -a "$OUT"

echo "=== [3/4] llama-bench pp2048 / tg128 x3 (flash attention on) ==="
"$BIN/llama-bench" -m "$MODEL" -ngl 99 -fa 1 -p 2048 -n 128 -r 3 -o md | tee -a "$OUT"

echo "=== [4/4] Sustained decode for $SUSTAIN s (thermal check) ==="
timeout "$SUSTAIN" "$BIN/llama-cli" -m "$MODEL" -ngl 99 -fa -n -1 --ignore-eos \
  -p "Write a long technical report about memory bandwidth and local LLM inference." \
  2>&1 | grep -E "eval time|tokens per second" | tail -n 3 | tee -a "$OUT" || true

echo "Results written to $OUT — compare against Table 2 estimates in the guide."
