#!/usr/bin/env bash
# Tinker AI — NVIDIA PC Model Loading & VRAM Spillover Diagnostic (Guide #2)
set -euo pipefail

MODEL="qwen2.5:14b-instruct-q4_K_M"
CTX="16384"

echo "=== [1/4] NVIDIA Driver, CUDA & Physical VRAM Baseline ==="
nvidia-smi --query-gpu=name,driver_version,memory.total,memory.used,memory.free --format=csv

echo "=== [2/4] Triggering Model Load ($MODEL @ num_ctx=$CTX) ==="
curl -sS http://127.0.0.1:11434/api/generate -d "{
  \"model\": \"$MODEL\",
  \"prompt\": \"Warmup VRAM allocation check.\",
  \"stream\": false,
  \"options\": { \"num_ctx\": $CTX }
}" > /dev/null

echo "=== [3/4] Inspecting Layer Offload Split (Look for 100% GPU vs CPU/GPU Split) ==="
ollama ps

echo "=== [4/4] Post-Load Physical VRAM Utilization ==="
nvidia-smi --query-gpu=memory.used,memory.free,utilization.gpu --format=csv
