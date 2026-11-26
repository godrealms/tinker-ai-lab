#!/usr/bin/env bash
# Tinker AI — NVIDIA Blackwell (sm_120) Power Tuning & MMQ Inference Runner (Guide #26)
set -euo pipefail

PL_WATTS="450"
MODEL_PATH="/models/Qwen3-30B-A3B-Q4_K_M.gguf"
CTX="32768"

echo "=== [1/3] Checking NVIDIA Blackwell Compute Capability (Expect 12.0 / sm_120) ==="
nvidia-smi --query-gpu=index,name,driver_version,compute_cap,power.draw,power.limit --format=csv

echo "=== [2/3] Locking Persistent GPU Power Cap to $PL_WATTS W ==="
sudo nvidia-smi -pm 1
sudo nvidia-smi -pl "$PL_WATTS"

echo "=== [3/3] Launching llama-server (Native sm_120 MMQ + FlashAttention + Q8_0 KV) ==="
./build/bin/llama-server \
  -m "$MODEL_PATH" \
  -c "$CTX" \
  -ngl 999 \
  -fa \
  -ctk q8_0 -ctv q8_0 \
  --host 127.0.0.1 \
  --port 11434
