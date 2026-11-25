#!/usr/bin/env bash
# Tinker AI — WRX90 Threadripper PRO 9995WX & DGX Station GB300 Frontier LLM Launcher (Guide #43)
set -euo pipefail

MODEL="/nvme/models/DeepSeek-R1-671B-Q4_K_M.gguf"
NCMOE="42"
THREADS="64"

echo "=== [1/4] Auditing CPU Architecture, AVX-512 / ARMv9 SVE2 & NUMA Topology ==="
lscpu | grep -E "Model name|Architecture|Socket|NUMA|avx512" || true
numactl --hardware | head -n 16 || true

echo "=== [2/4] Checking GPU HBM3e / GDDR7 VRAM & NVLink-C2C / PCIe Gen5 Link Width ==="
nvidia-smi --query-gpu=index,name,memory.total,memory.free,pcie.link.gen.current,pcie.link.width.current --format=csv
nvidia-smi nvlink --status 2>/dev/null || echo "[INFO] Standard PCIe 5.0 workstation topology (no NVLink-C2C)."

echo "=== [3/4] Disabling Auto-NUMA Page Thrashing for Multi-CCD / Grace-Blackwell Stability ==="
sudo sysctl -w kernel.numa_balancing=0

echo "=== [4/4] Launching Frontier 235B/671B MoE Server (GPU Attention + 8-Ch DDR5 / LPDDR5X Experts) ==="
numactl --interleave=all ./build/bin/llama-server \
  -m "$MODEL" \
  -ngl 99 --n-cpu-moe "$NCMOE" \
  -fa -ctk q8_0 -ctv q8_0 \
  -c 32768 -t "$THREADS" \
  --host 0.0.0.0 --port 8080
