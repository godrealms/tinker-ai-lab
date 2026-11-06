#!/usr/bin/env bash
# Tinker AI — Mac Studio M3 Ultra (256GB/512GB · 819GB/s) Metal Ceiling & MLX Launcher (Guide #25)
set -euo pipefail

TARGET_MB="486400"
MODEL_REPO="mlx-community/Qwen3-235B-A22B-4bit"
PORT="8080"

echo "=== [1/3] Raising macOS Metal Wired Memory Ceiling to $TARGET_MB MB ==="
CURRENT_MB=$(sysctl -n iogpu.wired_limit_mb 2>/dev/null || echo "0")
echo "Current iogpu.wired_limit_mb: $CURRENT_MB MB"
sudo sysctl -w iogpu.wired_limit_mb="$TARGET_MB"

echo "=== [2/3] Verifying Zero Swap Pressure & Thunderbolt 5 Bridge ==="
sysctl vm.swapusage
ifconfig bridge0 2>/dev/null | grep -E "inet|mtu" || echo "Single-node mode (no Thunderbolt 5 bridge0 active)"

echo "=== [3/3] Starting MLX OpenAI-Compatible Server on 127.0.0.1:$PORT ==="
python3 -m mlx_lm.server \
  --model "$MODEL_REPO" \
  --host 127.0.0.1 \
  --port "$PORT"
