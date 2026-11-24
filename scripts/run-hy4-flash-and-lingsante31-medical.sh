#!/usr/bin/env bash
# Tinker AI — Tencent Hy4-Flash (224B-A12B · Engram + LatentMoE + DFly2) & Ant LingSante-3.1 Medical MoE Launcher (Guide #64)
set -euo pipefail

MODE="vllm_hy4_flash_dfly2_fp8"
HY4_GGUF="./models/AngelSlim-Hy4-flash-Q4_K_M.gguf"
LINGSANTE="inclusionAI/LingSante-3.1-air-VL"
CTX="131072"
PORT="8000"

echo "=== [Host Memory & GPU Check] ==="
nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null || echo "[INFO] Running on Unified Memory / Apple Silicon / CPU-GPU Hybrid"

if [ "$MODE" = "vllm_hy4_flash_dfly2_fp8" ]; then
  echo "=== [vLLM Hy4-Flash FP8 + DFly2 0.85B Speculator] Serving tencent/Hy4-flash-FP8 (ctx=$CTX) ==="
  exec vllm serve tencent/Hy4-flash-FP8 \
    --trust-remote-code \
    --kv-cache-dtype fp8 \
    --max-model-len "$CTX" \
    --reasoning-parser hy_v4 \
    --speculative-config '{"model":"tencent/Hy4-flash-DFly2-0.85B","num_speculative_tokens":4}' \
    --gpu-memory-utilization 0.90 --port "$PORT"
elif [ "$MODE" = "llamacpp_hy4_flash_engram_offload" ]; then
  echo "=== [llama.cpp AngelSlim GGUF] Keeping 12B active layers + 1/6 SWA KV on GPU while pinning 64B Engram tables to Host RAM ==="
  exec llama-server -m "$HY4_GGUF" \
    -ngl 99 -fa on \
    -ot "engram\..*=CPU" \
    --cache-type-k q8_0 --cache-type-v q8_0 \
    -c "$CTX" --host 127.0.0.1 --port "$PORT"
elif [ "$MODE" = "vllm_lingsante31_air_vl" ]; then
  echo "=== [Air-Gapped Medical AI] Serving $LINGSANTE (124B-A5.5B MIT Multimodal MoE, ctx=$CTX) ==="
  export HF_HUB_OFFLINE=1
  exec vllm serve "$LINGSANTE" \
    --trust-remote-code \
    --kv-cache-dtype fp8 \
    --max-model-len "$CTX" \
    --limit-mm-per-prompt '{"image": 6, "video": 1}' \
    --gpu-memory-utilization 0.88 --port "$PORT"
else
  echo "Unknown RUN_MODE=$MODE (expected: vllm_hy4_flash_dfly2_fp8 | llamacpp_hy4_flash_engram_offload | vllm_lingsante31_air_vl)" >&2
  exit 1
fi
