#!/usr/bin/env bash
# Tinker AI — NVIDIA Blackwell 16GB–72GB GDDR7 & Speculative Decoding Runner (Guide #34)
set -euo pipefail

MAIN_MODEL="./models/Qwen3-14B-Instruct-Q4_K_M.gguf"
DRAFT_MODEL="./models/Qwen3-0.6B-Instruct-Q8_0.gguf"
DRAFT_TOKENS="12"
PORT="8080"

echo "=== [1/2] Inspecting Blackwell GPU VRAM, ECC Mode & GDDR7 P-State ==="
nvidia-smi --query-gpu=name,memory.total,ecc.mode.current,power.draw,power.limit --format=csv

echo "=== [2/2] Starting llama-server with Speculative Decoding (--draft-max $DRAFT_TOKENS) ==="
./build/bin/llama-server \
  -m "$MAIN_MODEL" \
  --model-draft "$DRAFT_MODEL" \
  --gpu-layers 99 --gpu-layers-draft 99 \
  --draft-max "$DRAFT_TOKENS" --draft-min 4 --draft-p-min 0.75 \
  -c 32768 -fa -ctk q8_0 -ctv q8_0 \
  --host 0.0.0.0 --port "$PORT"
