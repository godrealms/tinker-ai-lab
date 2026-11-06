#!/usr/bin/env bash
# Tinker AI — Thin-and-Light AI Laptop Fixed Benchmark: Snapdragon X2 Elite Extreme / Intel Panther Lake (Guide #39)
set -euo pipefail

MODEL="./models/Qwen3-30B-A3B-Q4_K_M.gguf"
BIN="./build/bin"
SUSTAIN="600"
OUT="bench-laptop-$(hostname)-$(date +%Y%m%d-%H%M).md"

echo "=== [1/4] Verifying Model Hash & Native Binary Architecture ==="
sha256sum "$MODEL" | tee -a "$OUT"
echo "- host arch: $(uname -m)" | tee -a "$OUT"
file "$BIN/llama-bench"* 2>/dev/null | head -n 1 | tee -a "$OUT" || true

echo "=== [2/4] Enumerating Vulkan / SYCL iGPU Devices (Arc B390 Xe3 or Adreno X2-90) ==="
"$BIN/llama-bench" --list-devices 2>&1 | tee -a "$OUT" || true

echo "=== [3/4] Running llama-bench pp2048 / tg128 x3 (Flash Attention + Q8_0 KV) ==="
"$BIN/llama-bench" -m "$MODEL" -ngl 99 -fa 1 -ctk q8_0 -ctv q8_0 -p 2048 -n 128 -r 3 -o md | tee -a "$OUT"

echo "=== [4/4] Sustained Decode ($SUSTAIN s) — Thin-and-Light Thermal Throttle Check ==="
timeout "$SUSTAIN" "$BIN/llama-cli" -m "$MODEL" -ngl 99 -fa -ctk q8_0 -ctv q8_0 -n -1 --ignore-eos \
  -p "Write a detailed architecture analysis comparing 192-bit vs 128-bit LPDDR5X unified memory for local MoE inference." \
  2>&1 | grep -E "eval time|tokens per second" | tail -n 3 | tee -a "$OUT" || true

echo "Saved benchmark report to $OUT"
