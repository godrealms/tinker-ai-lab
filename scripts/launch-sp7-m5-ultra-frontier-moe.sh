#!/usr/bin/env bash
# Tinker AI — AMD EPYC SP7 (16-Ch MRDIMM) & Mac Studio M5 Ultra Frontier MoE Launcher (Guide #53)
set -euo pipefail

TARGET="epyc_sp7"
MODEL="/nvme/models/DeepSeek-V4.1-Flash-Q4_K_M.gguf"
CTX="131072"
PORT="8080"

if [ "$TARGET" = "epyc_sp7" ]; then
  echo "=== [EPYC SP7 16-Ch Mode] Auditing DDR5/MRDIMM Speed & Disabling Auto-NUMA ==="
  sudo dmidecode -t memory | grep -E "Speed:|Configured Memory Speed:" | sort -u || true
  sudo sysctl -w kernel.numa_balancing=0
  exec numactl --interleave=all llama-server -m "$MODEL" -t 96 -fa on --cache-type-k fp8_e4m3 -c "$CTX" --port "$PORT"
elif [ "$TARGET" = "mac_m5_ultra" ]; then
  echo "=== [Mac Studio M5 Ultra 512GB Mode] Unlocking 480GB Metal Wired Pool ==="
  sudo sysctl -w iogpu.wired_limit_mb=491520
  exec mlx_lm.server --model "$MODEL" --port "$PORT"
else
  echo "Unknown HOST_TARGET=$TARGET (expected: epyc_sp7 | mac_m5_ultra)" >&2
  exit 1
fi
