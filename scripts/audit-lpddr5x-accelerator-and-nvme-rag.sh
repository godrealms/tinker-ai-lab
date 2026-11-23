#!/usr/bin/env bash
# Tinker AI — SC26 Non-HBM LPDDR5X Accelerator (Intel GPU D270 Xe3P) & Near-Data NVMe RAG Audit (Guide #61)
set -euo pipefail

MODE="pcie5_numa_audit"
MODEL="Qwen/Qwen3-235B-A22B-FP8"
MAX_LEN="65536"
NVME_FILE="/mnt/nvme-corpus/tinker-rag-bench.bin"
PORT="8000"

echo "=== [SC26 Host Audit] PCIe 5.0 Accelerator & NVMe Link Topology ==="
lspci -vv 2>/dev/null | grep -E 'Display|Processing accelerators|Non-Volatile|LnkSta:' | head -n 28 || true
if command -v numactl >/dev/null 2>&1; then
  numactl --hardware | grep -E 'available|node [0-9]+ cpus|node [0-9]+ size' || true
fi

if [ "$MODE" = "pcie5_numa_audit" ]; then
  echo "=== [Audit Complete] Verify 32GT/s (PCIe 5.0) x16 for D270-class cards and same-socket NUMA for NVMe ==="
  ls -la /dev/dri 2>/dev/null || echo "[INFO] /dev/dri not present on this host"
elif [ "$MODE" = "vllm_xpu_d270_serve" ]; then
  echo "=== [Intel vLLM-XPU] Launching $MODEL (max_len=$MAX_LEN) on port $PORT ==="
  exec docker run --rm --device=/dev/dri -p "$PORT:$PORT" \
    -e ZE_AFFINITY_MASK=0 -e VLLM_USE_V1=1 \
    intel/vllm-xpu:latest \
    --model "$MODEL" \
    --dtype bfloat16 --max-model-len "$MAX_LEN" \
    --gpu-memory-utilization 0.90 --port "$PORT"
elif [ "$MODE" = "nvme_rag_fio_bench" ]; then
  echo "=== [Near-Data RAG Baseline] Measuring Host NVMe -> RAM Sequential Scan Ceiling ==="
  mkdir -p "$(dirname "$NVME_FILE")"
  exec fio --name=tinker-rag-seq-scan --filename="$NVME_FILE" --size=8G \
    --rw=read --bs=1M --iodepth=32 --ioengine=io_uring --direct=1 --group_reporting
else
  echo "Unknown AUDIT_MODE=$MODE (expected: pcie5_numa_audit | vllm_xpu_d270_serve | nvme_rag_fio_bench)" >&2
  exit 1
fi
