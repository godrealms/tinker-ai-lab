#!/usr/bin/env bash
# Tinker AI — Apple M5 Max / M4 Max Metal 4 TensorOps & MLX Benchmark Runner (Guide #31)
set -euo pipefail

WIRED_MB="110592"
MODEL="mlx-community/Qwen3-32B-4bit"
KV_BITS="8"

echo "=== [1/3] Inspecting Apple Silicon SoC & Raising Metal Wired Limit to $WIRED_MB MB ==="
sysctl -n machdep.cpu.brand_string
sudo sysctl -w iogpu.wired_limit_mb="$WIRED_MB"

echo "=== [2/3] Verifying MLX Version & Metal 4 GPU Device Info ==="
python3 -c "import mlx.core as mx; print('MLX Version:', mx.__version__, '| Device:', mx.metal.device_info())"

echo "=== [3/3] Benchmarking Prompt Prefill (TTFT) & Decode on $MODEL (KV=${KV_BITS}-bit) ==="
python3 -m mlx_lm.generate \
  --model "$MODEL" \
  --kv-bits "$KV_BITS" \
  --max-tokens 256 \
  --prompt "Summarize the architectural difference between memory-bandwidth-bound token decode and compute-bound prompt prefill on Apple Silicon Metal 4 Neural Accelerators."
