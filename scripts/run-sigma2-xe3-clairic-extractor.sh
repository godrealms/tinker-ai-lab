#!/usr/bin/env bash
# Tinker AI — LattePanda Sigma 2 (Core Ultra X7 358H 64GB) & Cloudflare Clairic / Clef Runner (Guide #58)
set -euo pipefail

MODE="clairic_vllm"
MODEL="Cloudflare/clairic-flash"
CTX="32768"
P_NULL="0.65"
PORT="8000"

echo "=== [Host Check] Auditing Intel Xe3 Render Node, 10GbE Links & OCuLink PCIe ==="
ls -l /dev/dri/renderD* 2>/dev/null || true
lspci | grep -Ei 'VGA|Display|3D|Ethernet' || true

if [ "$MODE" = "clairic_vllm" ]; then
  echo "=== [Clairic System-1 Extraction] Serving $MODEL (p_null threshold=$P_NULL, ctx=$CTX) ==="
  export HF_HUB_OFFLINE="${HF_HUB_OFFLINE:-0}"
  export TINKER_CLAIRIC_P_NULL_MAX="$P_NULL"
  exec vllm serve "$MODEL" \
    --trust-remote-code \
    --max-model-len "$CTX" \
    --gpu-memory-utilization 0.88 \
    --host 127.0.0.1 --port "$PORT"
elif [ "$MODE" = "sigma2_xe3_gguf" ]; then
  echo "=== [LattePanda Sigma 2 Arc B390 Xe3] Launching SYCL / Vulkan GGUF Server (59GB UMA Ceiling) ==="
  export GGML_VK_VISIBLE_DEVICES=0
  exec llama-server \
    -m "$MODEL" -ngl 99 -fa on \
    --cache-type-k q8_0 --cache-type-v q8_0 \
    -c "$CTX" --host 127.0.0.1 --port "$PORT"
elif [ "$MODE" = "clef_router_dual" ]; then
  echo "=== [Dual-Model Pipeline] Starting Clef-Flash 9B Calibrated Router on Port $((PORT + 1)) + $MODEL on $PORT ==="
  vllm serve Cloudflare/clef-flash --max-model-len 16384 --gpu-memory-utilization 0.28 --port "$((PORT + 1))" &
  exec vllm serve "$MODEL" --max-model-len "$CTX" --gpu-memory-utilization 0.60 --port "$PORT"
else
  echo "Unknown DEPLOY_MODE=$MODE (expected: clairic_vllm | sigma2_xe3_gguf | clef_router_dual)" >&2
  exit 1
fi
