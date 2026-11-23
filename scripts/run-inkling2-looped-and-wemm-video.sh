#!/usr/bin/env bash
# Tinker AI — RTX Spark OEM (ProArt GR1X / EdgeMesa N AI+) + Inkling 2 Mini (Looped MoE) & WeMM-Video-35B-A3B (Guide #62)
set -euo pipefail

MODE="vllm_inkling2_dspark"
GGUF="./models/Inkling-2-Mini-Q4_K_M.gguf"
CTX="131072"
MTP="3"
PORT="8000"

echo "=== [Hardware & Arch Check] Host Arch: $(uname -m) ==="
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>/dev/null || echo "[INFO] nvidia-smi unavailable (Apple Silicon / CPU mode)"

if [ "$MODE" = "vllm_inkling2_dspark" ]; then
  echo "=== [vLLM + DSpark MTP] Serving Thinking Machines Inkling 2 Mini (48 logical KV passes, ctx=$CTX, mtp=$MTP) ==="
  exec vllm serve thinking-machines/Inkling-2-Mini \
    --kv-cache-dtype fp8 \
    --max-model-len "$CTX" \
    --speculative-config "{\"method\": \"mtp\", \"num_speculative_tokens\": $MTP}" \
    --gpu-memory-utilization 0.85 --port "$PORT"
elif [ "$MODE" = "llamacpp_inkling2_q8kv" ]; then
  echo "=== [llama.cpp Q8_0 KV] Serving $GGUF (48-pass KV guard enabled, ctx=$CTX) ==="
  exec llama-server -m "$GGUF" \
    -ngl 99 -fa on \
    --cache-type-k q8_0 --cache-type-v q8_0 \
    -c "$CTX" --host 127.0.0.1 --port "$PORT"
elif [ "$MODE" = "vllm_wemm_video_nvfp4" ]; then
  echo "=== [vLLM Omni-Modal] Serving Tencent WeMM-Video-35B-A3B-NVFP4 (ctx=$CTX) ==="
  exec vllm serve tencent/WeMM-Video-35BA3B-NVFP4 \
    --trust-remote-code \
    --kv-cache-dtype fp8 \
    --max-model-len "$CTX" \
    --limit-mm-per-prompt '{"video": 2, "audio": 2}' \
    --gpu-memory-utilization 0.88 --port "$PORT"
else
  echo "Unknown SERVE_MODE=$MODE (expected: vllm_inkling2_dspark | llamacpp_inkling2_q8kv | vllm_wemm_video_nvfp4)" >&2
  exit 1
fi
