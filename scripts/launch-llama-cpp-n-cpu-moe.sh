#!/usr/bin/env bash
# Tinker AI — Mainstream 12GB–24GB GPU + Dual-Channel DDR5 MoE Offload Launcher (Guide #40)
set -euo pipefail

MODEL="./models/Qwen3-30B-A3B-Q4_K_M.gguf"
NCMOE="16"
THREADS="12"
CTX="32768"

echo "=== [1/3] Checking GPU Free VRAM & PCIe Link State ==="
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,memory.total,memory.free,pcie.link.gen.current,pcie.link.width.current --format=csv
fi

echo "=== [2/3] Verifying llama-server Supports Native --n-cpu-moe ==="
./build/bin/llama-server --help 2>&1 | grep -E -- "--n-cpu-moe|-ncmoe" | head -n 2

echo "=== [3/3] Starting Hybrid MoE Server (-ngl 99 --n-cpu-moe $NCMOE, Attention+KV on GPU, $NCMOE Expert Layers in DDR5) ==="
./build/bin/llama-server \
  -m "$MODEL" \
  -ngl 99 \
  --n-cpu-moe "$NCMOE" \
  -fa -ctk q8_0 -ctv q8_0 \
  -c "$CTX" -t "$THREADS" \
  --host 0.0.0.0 --port 8080
