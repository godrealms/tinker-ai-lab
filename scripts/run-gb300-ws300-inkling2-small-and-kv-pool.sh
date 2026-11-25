#!/usr/bin/env bash
# Tinker AI — SC26 Optical/CXL/NVMe-oF KV Pool & Deskside GB300 (MSI WS300 / GIGABYTE W775-V10) Inkling 2 Small Launcher (Guide #63)
set -euo pipefail

MODE="vllm_ws300_inkling2_small_nvfp4"
MODEL="thinking-machines/Inkling-2-Small-NVFP4"
CTX="262144"
KV_DIR="/mnt/gen6-kv-scratch"
PORT="8000"

echo "=== [SC26 Deskside GB300 & CXL/NVMe-oF KV Tier Audit] ==="
numactl --hardware 2>/dev/null | grep -E 'available|node [0-9]+ size|node distances' || true
lspci -vv 2>/dev/null | grep -E 'CXL|ConnectX-8|ConnectX-7|Non-Volatile|LnkSta:' | head -n 24 || true

if [ "$MODE" = "audit_gb300_cxl_topology" ]; then
  echo "=== [Topology Check] Verifying HBM3e + LPDDR5X / CXL DAX tiers & ConnectX-8 400GbE links ==="
  nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader 2>/dev/null || true
  ibv_devinfo -l 2>/dev/null || echo "[INFO] ibv_devinfo not installed"
elif [ "$MODE" = "vllm_ws300_inkling2_small_nvfp4" ]; then
  echo "=== [GB300 748GB Coherent] Serving $MODEL (594B-A17B, ctx=$CTX) on MSI WS300 / GIGABYTE W775-V10 ==="
  exec vllm serve "$MODEL" \
    --quantization nvfp4 \
    --kv-cache-dtype fp8 \
    --max-model-len "$CTX" \
    --enable-prefix-caching \
    --gpu-memory-utilization 0.92 --port "$PORT"
elif [ "$MODE" = "vllm_lmcache_cxl_nvmeof_pool" ]; then
  echo "=== [LMCache Tiered KV Pool] Offloading Multi-Turn KV to CXL DRAM + $KV_DIR ==="
  mkdir -p "$KV_DIR"
  export LMCACHE_MAX_LOCAL_CPU_SIZE="256.0"
  export LMCACHE_LOCAL_DISK="file://$KV_DIR/"
  export LMCACHE_MAX_LOCAL_DISK_SIZE="2048.0"
  exec vllm serve "$MODEL" \
    --kv-cache-dtype fp8 \
    --max-model-len "$CTX" \
    --kv-transfer-config '{"kv_connector":"LMCacheConnectorV1","kv_role":"kv_both"}' \
    --gpu-memory-utilization 0.88 --port "$PORT"
else
  echo "Unknown DEPLOY_MODE=$MODE (expected: audit_gb300_cxl_topology | vllm_ws300_inkling2_small_nvfp4 | vllm_lmcache_cxl_nvmeof_pool)" >&2
  exit 1
fi
