#!/usr/bin/env bash
# Tinker AI — ASUS ET900N G3 / Veriton GN100 + vLLM MoRI UMBP & Strata 3-Tier MoE Launcher (Guide #69)
set -euo pipefail

MODE="mori_umbp_vllm"
NVME_DIR="/mnt/nvme-kv"
DRAM_GB="32"
MODEL="Qwen/Qwen3.8-Flash-Next-NVFP4"
PORT="8000"

echo "=== [1/3] Hardware, NVMe & RDMA Preflight ==="
nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>/dev/null || true
lsblk -d -o NAME,MODEL,SIZE,ROTA,TRAN | grep -E "NAME|nvme" || true
ibv_devinfo -l 2>/dev/null || echo "[INFO] No InfiniBand/RoCE HCA detected (single-node PCIe/NVMe mode)"

if [ "$MODE" = "gb300_gn100_audit" ]; then
  echo "=== [2/3] Deskside GB300 (ET900N G3) / GB10 (Veriton GN100) Coherent Memory & Page Cache Check ==="
  free -h
  awk '/MemTotal|MemAvailable|Cached|SwapTotal/ {print}' /proc/meminfo
  echo "[TIP] Before loading >100GB weights on GB10/GB300 unified memory, flush Linux page cache:"
  echo "      sudo sh -c 'sync; echo 3 > /proc/sys/vm/drop_caches'"
  exit 0
elif [ "$MODE" = "mori_umbp_vllm" ]; then
  echo "=== [2/3] Preparing NVMe KV Pool at $NVME_DIR (DRAM staging: ${DRAM_GB}GB) ==="
  mkdir -p "$NVME_DIR/mori-umbp-kv"
  export MORI_UMBP_STORAGE_DIR="$NVME_DIR/mori-umbp-kv"
  export MORI_UMBP_DRAM_STAGING_GB="$DRAM_GB"
  export MORI_UMBP_ASYNC_PREFETCH=1
  export VLLM_ATTENTION_BACKEND=FLASH_ATTN
  echo "=== [3/3] Launching vLLM with MoRI UMBP NVMe KV Offload on :$PORT ==="
  exec vllm serve "$MODEL" \
    --kv-transfer-config '{"kv_connector":"MoRIUMBPConnector","kv_role":"kv_both"}' \
    --enable-prefix-caching \
    --kv-cache-dtype fp8 \
    --max-model-len 131072 \
    --host 127.0.0.1 --port "$PORT"
elif [ "$MODE" = "strata_3tier_moe" ]; then
  echo "=== [2/3] Launching Strata 3-Tier (VRAM Hot + DDR5 Warm + NVMe Cold) MoE Server ==="
  mkdir -p "$NVME_DIR/strata-cache"
  exec strata serve "$MODEL" \
    --vram-hot-experts auto \
    --ram-budget-gb "$DRAM_GB" \
    --ssd-cache-dir "$NVME_DIR/strata-cache" \
    --async-prefetch \
    --speculative-draft auto \
    --host 127.0.0.1 --port "$PORT"
else
  echo "Unknown RUN_MODE=$MODE" >&2
  exit 1
fi
