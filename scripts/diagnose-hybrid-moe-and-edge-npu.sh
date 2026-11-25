#!/usr/bin/env bash
# Tinker AI — Hybrid CPU+GPU MoE NUMA & Edge NPU (Hailo-10H / RK3588) Doctor (Guide #36)
set -euo pipefail

MIN_CMA="256"
MAX_VRAM="22500"

echo "=== [1/4] Checking Linux Auto-NUMA Balancing & Socket Interleaving ==="
if [ -f /proc/sys/kernel/numa_balancing ]; then
  NB=$(cat /proc/sys/kernel/numa_balancing)
  echo "kernel.numa_balancing = $NB"
  if [ "$NB" = "1" ]; then
    echo "[WARN] Auto-NUMA balancing is ON (1)! On multi-node EPYC/Xeon running KTransformers or ik_llama.cpp, this causes 50-65% decode slowdown. Fix: sudo sysctl -w kernel.numa_balancing=0"
  else
    echo "[OK] Auto-NUMA balancing is disabled."
  fi
fi

echo "=== [2/4] Checking GPU Free VRAM vs Hybrid MoE Attention + KV Budget ($MAX_VRAM MB) ==="
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=index,name,memory.used,memory.free --format=csv
  echo "Tip: If ik_llama.cpp -ngl 99 OOMs on 671B/235B MoE, ensure regex matches routed experts: -ot 'blk\.[0-9]+\.ffn_.*_exps\.weight=CPU'"
fi

echo "=== [3/4] Checking Hailo-10H (AI HAT+ 2) PCIe Link Width & Firmware ==="
if command -v hailortcli >/dev/null 2>&1; then
  hailortcli fw-control identify || echo "[WARN] hailortcli failed: verify hailo-h10-all package (do not mix with hailo-all for Hailo-8)!"
fi

echo "=== [4/4] Checking Contiguous Memory Allocator (CMA >= $MIN_CMA MB) & Memlock Limits ==="
grep -i "Cma" /proc/meminfo || true
echo "Current max locked memory (ulimit -l): $(ulimit -l)"
