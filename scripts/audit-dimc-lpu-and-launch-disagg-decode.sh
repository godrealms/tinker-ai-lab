#!/usr/bin/env bash
# Tinker AI — SC26 DIMC & High-Utilization LPU Evaluator: d-Matrix Corsair, HyperAccel Bertha 500 & Positron Atlas (Guide #65)
set -euo pipefail

TARGET="dmatrix_corsair_aviator"
MODEL="inclusionAI/Ling-3.2-air"
SRAM_MB="1920"
CTX="131072"
PORT="8000"

echo "=== [1/2] Auditing PCIe Gen5 x16 Accelerator Endpoints & Power Caps ==="
lspci -vv 2>/dev/null | grep -Ei 'd-Matrix|HyperAccel|Positron|Processing accelerators|3D controller|LnkSta:' | head -n 20 || true

if [ "$TARGET" = "dmatrix_corsair_aviator" ]; then
  echo "=== [2/2] [d-Matrix Corsair 256GB] Pinning Hot Layers/Attention into ${SRAM_MB}MB 150 TB/s DIMC SRAM + 256GB LPDDR5X Capacity Tier ==="
  export DMX_AVIATOR_SRAM_BUDGET_MB="$SRAM_MB"
  export DMX_BRIDGE_P2P_ENABLE=1
  exec vllm serve "$MODEL" \
    --device dmatrix \
    --kv-cache-dtype fp8 \
    --max-model-len "$CTX" \
    --port "$PORT"
elif [ "$TARGET" = "hyperaccel_bertha500_lpu" ]; then
  echo "=== [2/2] [HyperAccel Bertha 500 LPU 128GB · 250W] Launching Deterministic Dataflow Engine (~90% Memory BW Utilization) ==="
  export HYPERACCEL_DATAFLOW_PREFETCH=1
  exec vllm serve "$MODEL" \
    --device lpu \
    --quantization fp8 \
    --max-model-len "$CTX" \
    --port "$PORT"
elif [ "$TARGET" = "positron_atlas_disagg" ]; then
  echo "=== [2/2] [Positron Atlas 8x Archer 256GB HBM] Starting Memory-First Disaggregated Decode Worker (>93% HBM Utilization) ==="
  exec vllm serve "$MODEL" \
    --kv-transfer-config '{"kv_connector":"PyNcclConnector","kv_role":"kv_consumer"}' \
    --max-model-len "$CTX" \
    --port "$PORT"
elif [ "$TARGET" = "bandwidth_efficiency_calc" ]; then
  echo "=== [2/2] Effective Decode Bandwidth & Token/s/Watt Ledger ==="
  python3 -c '
specs = [
  ("HyperAccel Bertha 500 (128GB LPDDR5X)", 546, 0.90, 250),
  ("d-Matrix Corsair (2GB DIMC + 256GB LPDDR5X)", 2400, 0.88, 600),
  ("Positron Atlas 8x Archer (256GB HBM)", 6400, 0.93, 2000),
  ("Standard 80GB HBM3 GPU Baseline", 3350, 0.58, 700),
]
for name, bw, util, tdp in specs:
  eff = bw * util
  print(f"{name:44s} | Raw: {bw:5d} GB/s | Eff({int(util*100)}%): {eff:6.1f} GB/s | Eff/Watt: {eff/tdp:5.2f} GB/s/W")
'
else
  echo "Unknown ACCEL_TARGET=$TARGET" >&2
  exit 1
fi
