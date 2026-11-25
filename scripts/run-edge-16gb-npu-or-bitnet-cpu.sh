#!/usr/bin/env bash
# Tinker AI — 16GB Edge NPUs (Axelera Metis M.2 Max / Mobilint MLA100) & BitNet b1.58 Runner (Guide #50)
set -euo pipefail

BACKEND="bitnet_cpu"
BITNET_GGUF="models/BitNet-b1.58-2B-4T/ggml-model-i2_s.gguf"
NPU_MODEL="meta-llama/Llama-3.1-8B-Instruct"
THREADS="4"

if [ "$BACKEND" = "bitnet_cpu" ]; then
  echo "=== [BitNet b1.58 Mode] Running Native 1.58-Bit Ternary ({-1,0,+1}) I2_S LUT Kernel on $THREADS Cores ==="
  lscpu | grep -E "Model name|Architecture|CPU\(s\)" || true
  ./build/bin/llama-cli \
    -m "$BITNET_GGUF" \
    -t "$THREADS" \
    -c 4096 \
    -n 256 \
    --temp 0.3 \
    -p "Explain why ternary {-1, 0, +1} weights replace floating-point FMA with integer LUT additions:"
elif [ "$BACKEND" = "axelera_m2" ]; then
  echo "=== [Axelera Metis M.2 Max 16GB Mode] Checking PCIe M.2 Device & Running Voyager SDK axllm ==="
  lspci | grep -i "Axelera" || true
  axdownloadmodel "$NPU_MODEL" || true
  axllm run "$NPU_MODEL" --ui --port 7860
elif [ "$BACKEND" = "mobilint_pcie" ]; then
  echo "=== [Mobilint ARIES MLA100 16GB 25W Mode] Checking NPU & Starting vllm-mblt Server ==="
  lspci | grep -i "Mobilint" || true
  vllm serve "$NPU_MODEL" \
    --device mblt \
    --max-model-len 8192 \
    --host 0.0.0.0 --port 8000
else
  echo "Unknown EDGE_BACKEND=$BACKEND (expected: bitnet_cpu | axelera_m2 | mobilint_pcie)" >&2
  exit 1
fi
