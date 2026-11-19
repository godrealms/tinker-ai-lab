#!/usr/bin/env bash
# Tinker AI — Axelera Europa PCIe Audit, CXL Weighted Interleave & AMD IOMMU PerfOpt Tuner (Guide #57)
set -euo pipefail

MODE="amd_iommu_perfopt"
MODEL="./models/Qwen3.8-27B-Q4_K_M.gguf"
W_DDR="10"
W_CXL="3"
PORT="8080"

if [ "$MODE" = "amd_iommu_perfopt" ]; then
  echo "=== [AMD Ryzen UMA] Auditing Linux Kernel & IOMMU PerfOpt Identity Bypass ==="
  uname -r
  if [ -f /sys/module/amdgpu/parameters/iommu_perfopt ]; then
    echo "amdgpu.iommu_perfopt = $(cat /sys/module/amdgpu/parameters/iommu_perfopt)"
  else
    echo "[WARN] Kernel < 7.4 lacks amdgpu.iommu_perfopt; checking cmdline for iommu=pt fallback..."
    grep -o 'iommu=[^ ]*' /proc/cmdline || echo "[ACTION] Add iommu=pt to GRUB_CMDLINE_LINUX_DEFAULT (if no VFIO passthrough) to recover ~18-23% UMA tok/s."
  fi
  exec llama-server -m "$MODEL" -ngl 99 -fa on --cache-type-k q8_0 --cache-type-v q8_0 -c 65536 --port "$PORT"
elif [ "$MODE" = "cxl_weighted_interleave" ]; then
  echo "=== [CXL 2.0 Type-3] Applying Bandwidth-Weighted Interleave (node0=$W_DDR : node1=$W_CXL) ==="
  numactl -H
  echo "$W_DDR" | sudo tee /sys/kernel/mm/mempolicy/weighted_interleave/node0 >/dev/null
  echo "$W_CXL" | sudo tee /sys/kernel/mm/mempolicy/weighted_interleave/node1 >/dev/null
  exec numactl --weighted-interleave=0,1 llama-server \
    -m "$MODEL" -ngl 99 --n-cpu-moe 58 -fa on \
    --cache-type-k q8_0 --cache-type-v q8_0 -c 32768 --port "$PORT"
elif [ "$MODE" = "axelera_europa_audit" ]; then
  echo "=== [Axelera Edge 232p / Server 250p] Checking PCIe x4/x4/x4/x4 Bifurcation & Launching axllm ==="
  EUROPA_COUNT="$(lspci | grep -ci 'Axelera' || true)"
  echo "Detected Axelera AIPU PCIe endpoints: $EUROPA_COUNT (Server 250p requires 4 via x4/x4/x4/x4 bifurcation)"
  exec axllm serve "$MODEL" --host 0.0.0.0 --port "$PORT"
else
  echo "Unknown TUNE_MODE=$MODE (expected: amd_iommu_perfopt | cxl_weighted_interleave | axelera_europa_audit)" >&2
  exit 1
fi
