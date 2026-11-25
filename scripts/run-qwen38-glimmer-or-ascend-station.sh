#!/usr/bin/env bash
# Tinker AI — Qwen3.8-27B / Flash-Next / Muse Glimmer 30B & Orange Pi AI Station 96GB Runner (Guide #56)
set -euo pipefail

MODE="gpu_24gb_128k"
MODEL="./models/Qwen3.8-27B-Q4_K_M.gguf"
CTX="131072"
CPU_MOE="36"
PORT="8080"

if [ "$MODE" = "gpu_24gb_128k" ]; then
  echo "=== [24GB-32GB GPU] Launching Qwen3.8-27B (16 KV layers) / Muse Glimmer 30B at $CTX Context ==="
  exec llama-server \
    -m "$MODEL" -ngl 99 -fa on \
    --cache-type-k q8_0 --cache-type-v q8_0 \
    -c "$CTX" --host 127.0.0.1 --port "$PORT"
elif [ "$MODE" = "flash_next_hybrid" ]; then
  echo "=== [GPU + 128GB DDR5] Launching Qwen3.8-Flash-Next (6B Active + Host N-Gram/MoE Offload) ==="
  exec llama-server \
    -m "$MODEL" -ngl 99 --n-cpu-moe "$CPU_MOE" -fa on \
    --cache-type-k fp8_e4m3 --cache-type-v q8_0 \
    -c "$CTX" --host 127.0.0.1 --port "$PORT"
elif [ "$MODE" = "ascend_96gb" ]; then
  echo "=== [Orange Pi AI Station 96GB] Auditing Ascend 310 CANN Runtime & Launching vllm-ascend ==="
  npu-smi info
  df -h / | awk 'NR==2 {print "Boot rootfs:", $1, $6}'
  exec vllm serve "$MODEL" \
    --device npu --dtype float16 \
    --max-model-len 32768 --port "$PORT"
else
  echo "Unknown RUN_MODE=$MODE (expected: gpu_24gb_128k | flash_next_hybrid | ascend_96gb)" >&2
  exit 1
fi
