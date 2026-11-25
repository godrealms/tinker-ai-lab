#!/usr/bin/env bash
# Tinker AI — RTX PRO 6000 Blackwell (96GB) & Radeon AI PRO R9700 (32GB) Launcher (Guide #30)
set -euo pipefail

WATTS="300"
MODEL="Qwen/Qwen3-Next-80B-A3B-Instruct-FP8"
CTX="65536"

if command -v nvidia-smi >/dev/null 2>&1; then
  echo "=== [NVIDIA RTX PRO 6000 Blackwell 96GB] Applying $WATTS W Power Profile & Checking ECC ==="
  sudo nvidia-smi -pm 1
  sudo nvidia-smi -pl "$WATTS"
  nvidia-smi --query-gpu=name,memory.total,ecc.mode.current,power.draw,power.limit --format=csv
  exec vllm serve "$MODEL" \
    --max-model-len "$CTX" \
    --gpu-memory-utilization 0.92 \
    --kv-cache-dtype fp8 \
    --enable-prefix-caching \
    --port 8000
else
  echo "=== [AMD Radeon AI PRO R9700 32GB RDNA 4 (gfx1201)] Configuring ROCm / Vulkan Stack ==="
  unset HSA_OVERRIDE_GFX_VERSION
  export HSA_ENABLE_SDMA=0
  export NCCL_IB_DISABLE=1
  export NCCL_P2P_LEVEL=PHB
  rocm-smi --showproductname --showmeminfo vram || vulkaninfo --summary | grep -i "deviceName"
  echo "Ready for ROCm vLLM or llama-server Vulkan RADV (-ngl 99 -fa -ctk q8_0 -ctv q8_0 -c $CTX)."
fi
