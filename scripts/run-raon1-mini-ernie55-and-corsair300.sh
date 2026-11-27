#!/usr/bin/env bash
# Tinker AI — KRAFTON Raon-1 Mini (28.8B-A4.3B) & Baidu ERNIE 5.5 Flash (280B-A14B) Launcher (Guide #70)
set -euo pipefail

MODE="raon1_vllm_256k"
RAON="krafton-ai/Raon-1-mini-NVFP4"
EFFORT="medium"
ERNIE="baidu/ERNIE-5.5-Flash-FP8"
PORT="8000"

if [ "$MODE" = "raon1_vllm_256k" ]; then
  echo "=== [KRAFTON Raon-1 Mini · 28.8B-A4.3B · 18 RDA + 7 Gated MLA · 256K] ==="
  echo "[INFO] Full 256K context KV cache is only ~2.0 GB in BF16 (~8 KiB/tok) thanks to 18 RDA linear layers."
  echo "[INFO] Pass extra_body={\"reasoning_effort\": \"$EFFORT\"} (none|low|medium|high|xhigh|max) per request."
  exec vllm serve "$RAON" \
    --max-model-len 262144 \
    --gpu-memory-utilization 0.90 \
    --enable-auto-tool-choice \
    --host 127.0.0.1 --port "$PORT"
elif [ "$MODE" = "raon1_corsair300_llama" ]; then
  echo "=== [Corsair AI Workstation 300 (128GB Strix Halo) · Raon-1 Mini GGUF] ==="
  echo "[INFO] Ensure BIOS UMA / Linux amdgpu.gttsize allocates >=96GB VRAM before loading."
  export GGML_VK_VISIBLE_DEVICES=0
  exec llama-server -m "$RAON" \
    -ngl 99 -fa on \
    --cache-type-k q8_0 --cache-type-v q8_0 \
    -c 262144 --host 127.0.0.1 --port "$PORT"
elif [ "$MODE" = "ernie55_vllm_plugin" ]; then
  echo "=== [Baidu ERNIE 5.5 Flash · 280B-A14B · Hybrid HCA + MLA-DSA · vllm-ernie] ==="
  python3 -c "import vllm_ernie" 2>/dev/null || {
    echo "[ERROR] vllm-ernie plugin not found. Install with: pip install vllm==0.32.0 vllm-ernie" >&2
    exit 1
  }
  exec vllm serve "$ERNIE" \
    --reasoning-parser ernie5 \
    --kv-cache-dtype fp8 \
    --max-model-len 262144 \
    --enable-prefix-caching \
    --host 127.0.0.1 --port "$PORT"
else
  echo "Unknown STACK_MODE=$MODE" >&2
  exit 1
fi
