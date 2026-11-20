#!/usr/bin/env bash
# Tinker AI — SC26 Disaggregated Prefill/Decode (Skymizer HTX301-4S 2TB) & TRUSTA PCIe Gen5 3-Tier vLLM KV Offload (Guide #59)
set -euo pipefail

MODE="trusta_tiered_kv_vllm"
MODEL="Qwen/Qwen3-235B-A22B-FP8"
KV_DIR="/mnt/trusta-t7p5-kv"
DRAM_GB="192"
PORT="8100"

echo "=== [SC26 Storage & Accelerator Audit] Checking PCIe Gen5 NVMe Links & CPU AMX ==="
lspci -vv 2>/dev/null | grep -E 'Non-Volatile|LnkSta:' | head -n 16 || true
grep -m1 -o 'amx_bf16' /proc/cpuinfo && echo "[OK] Intel AMX BF16 detected (accelerates host prefill up to ~25%)" || echo "[INFO] Non-AMX CPU detected"

if [ "$MODE" = "trusta_tiered_kv_vllm" ]; then
  echo "=== [TRUSTA AI Scaler / 3-Tier vLLM KV Pool] GPU VRAM -> ${DRAM_GB}GB DRAM -> $KV_DIR (PCIe Gen5 NVMe) ==="
  mkdir -p "$KV_DIR"
  df -h "$KV_DIR"
  export LMCACHE_USE_EXPERIMENTAL=True
  export LMCACHE_LOCAL_CPU=True
  export LMCACHE_MAX_LOCAL_CPU_SIZE="$DRAM_GB"
  export LMCACHE_LOCAL_DISK="file://$KV_DIR/"
  export LMCACHE_MAX_LOCAL_DISK_SIZE=1024
  exec vllm serve "$MODEL" \
    --max-model-len 131072 \
    --enable-prefix-caching \
    --gpu-memory-utilization 0.90 \
    --kv-transfer-config '{"kv_connector":"LMCacheConnectorV1","kv_role":"kv_both"}' \
    --host 0.0.0.0 --port "$PORT"
elif [ "$MODE" = "disagg_prefill_node" ]; then
  echo "=== [Disaggregated Prefill Node] Serving Compute-Bound Prefill Producer on Port $PORT ==="
  exec vllm serve "$MODEL" \
    --max-model-len 131072 \
    --gpu-memory-utilization 0.92 \
    --kv-transfer-config '{"kv_connector":"NixlConnector","kv_role":"kv_producer"}' \
    --host 0.0.0.0 --port "$PORT"
elif [ "$MODE" = "disagg_decode_htx301" ]; then
  echo "=== [MiTAC G4520G6 + 8x Skymizer HTX301-4S] Auditing 32x PCIe Decode Endpoints (4x HTX301 per Card) ==="
  HTX_COUNT="$(lspci | grep -ciE 'Skymizer|HTX301' || true)"
  echo "Detected HTX301 PCIe endpoints: $HTX_COUNT (expected: 4 per HTX301-4S card, 32 for 8-card 2TB decode node)"
  echo "[INFO] Launch LISA v3 decode consumer runtime pointing at prefill producer port $PORT for model $MODEL"
  echo "Example: lisa-serve --role kv_consumer --model '$MODEL' --kv-port '$PORT' --mem-budget-gb 1920"
else
  echo "Unknown RUN_MODE=$MODE (expected: trusta_tiered_kv_vllm | disagg_prefill_node | disagg_decode_htx301)" >&2
  exit 1
fi
