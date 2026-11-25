#!/usr/bin/env bash
# Tinker AI — Mac mini M5 Pro (64GB) & 2026 Qwen3.5 / Gemma 4 / gpt-oss Long-Context Runner (Guide #46)
set -euo pipefail

MODEL="./models/Qwen3.5-35B-A3B-Q4_K_M.gguf"
CTX="131072"
WIRED="55296"
PORT="8080"

echo "=== [1/3] Auditing Host Memory Ceiling (Apple Silicon Metal vs Linux CUDA) ==="
if [ "$(uname -s)" = "Darwin" ]; then
  system_profiler SPHardwareDataType | grep -E "Chip:|Memory:" || true
  echo "Raising iogpu.wired_limit_mb to $WIRED MB (prevents premature swap on 64GB Mac mini M5 Pro)..."
  sudo sysctl -w iogpu.wired_limit_mb="$WIRED" || true
  vm_stat | grep -E "Pages free|Swapins|Swapouts"
else
  nvidia-smi --query-gpu=index,name,memory.total,memory.free --format=csv || true
fi

echo "=== [2/3] Deterministic PP2048 / TG128 Benchmark (Flash Attention + Q8_0 KV) ==="
./build/bin/llama-bench \
  -m "$MODEL" \
  -ngl 99 -fa 1 -ctk q8_0 -ctv q8_0 \
  -p 2048 -n 128 -r 3 -o md

echo "=== [3/3] Starting llama-server (Context=$CTX, --jinja & --cache-reuse preserve DeltaNet state) ==="
./build/bin/llama-server \
  -m "$MODEL" \
  -ngl 99 --jinja --cache-reuse 256 \
  -fa -ctk q8_0 -ctv q8_0 \
  -c "$CTX" -ub 2048 -b 2048 \
  --host 0.0.0.0 --port "$PORT"
