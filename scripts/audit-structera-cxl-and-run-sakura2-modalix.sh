#!/usr/bin/env bash
# Tinker AI — SC26 Marvell Structera A 2504 / X 2404 CXL & EdgeCortix SAKURA-II / SiMa.ai Modalix Runner (Guide #67)
set -euo pipefail

MODE="structera_a2504_cxl_lz4"
MODEL="Aleph-Alpha/Kolibri-1.1"
CXL_NODE="2"
MOE_LAYERS="28"
PORT="8000"

echo "=== [1/2] Inspecting PCIe 5.0 / CXL 2.0 Topology & Edge NPU Devices ==="
lspci -vv 2>/dev/null | grep -Ei 'CXL|Marvell|Structera|EdgeCortix|SAKURA|SiMa|Modalix|LnkSta:' | head -n 20 || true
numactl -H 2>/dev/null | head -n 16 || true

if [ "$MODE" = "structera_a2504_cxl_lz4" ]; then
  echo "=== [2/2] [Marvell Structera A 2504 · 16x Neoverse V2 + 4-Ch DDR5 200 GB/s + Inline LZ4] Weighted Interleave & vLLM KV Tier ==="
  if [ -d "/sys/kernel/mm/mempolicy/weighted_interleave" ]; then
    echo 23 | sudo tee /sys/kernel/mm/mempolicy/weighted_interleave/node0 >/dev/null || true
    echo 10 | sudo tee "/sys/kernel/mm/mempolicy/weighted_interleave/node${CXL_NODE}" >/dev/null || true
  fi
  export STRUCTERA_INLINE_LZ4_ENABLE=1
  export STRUCTERA_NEOVERSE_KV_PREFILTER=1
  exec numactl --weighted-interleave=0,"${CXL_NODE}" vllm serve "$MODEL" \
    --swap-space 256 \
    --kv-cache-dtype fp8 \
    --max-model-len 262144 \
    --port "$PORT"
elif [ "$MODE" = "structera_x2404_ddr4_moe" ]; then
  echo "=== [2/2] [Marvell Structera X 2404 · 12-DIMM Recycled DDR4-3200 768GB CXL Pool] Offloading $MOE_LAYERS MoE Layers ==="
  export STRUCTERA_INLINE_LZ4_ENABLE=1
  exec numactl --membind=0,"${CXL_NODE}" llama-server \
    -m "$MODEL" \
    -ngl 99 --n-cpu-moe "$MOE_LAYERS" \
    -fa on --cache-type-k q8_0 --cache-type-v q8_0 \
    -c 131072 --host 127.0.0.1 --port "$PORT"
elif [ "$MODE" = "edgecortix_sakura2_mera" ]; then
  echo "=== [2/2] [EdgeCortix SAKURA-II · DNA-II 60 TOPS INT8 / 30 TFLOPS BF16 @ 8-10W] Launching MERA 2.0 Runtime Server ==="
  export MERA_DEVICE_TARGET="sakura2"
  export MERA_BF16_VISION_ENCODER=1
  exec mera-serve --model "$MODEL" --precision w4a16_bf16 --port "$PORT"
elif [ "$MODE" = "sima_modalix_eagle3" ]; then
  echo "=== [2/2] [SiMa.ai MLSoC Modalix · 50 TOPS @ <10W] Launching Palette 3.0 with Hardware EAGLE-3 Speculative Decoding ==="
  export SIMA_PALETTE_SPECULATIVE_MODE="eagle3"
  exec palette-llm-serve --model "$MODEL" --speculative-draft eagle3 --max-draft-tokens 4 --port "$PORT"
else
  echo "Unknown DEPLOY_MODE=$MODE" >&2
  exit 1
fi
