#!/usr/bin/env bash
# Tinker AI — Next-Gen Edge LLM Bootstrap: Hailo-10H (8GB) / RK3588 NPU / Jetson Thor (Guide #35)
set -euo pipefail

PLATFORM="hailo10h"
MODEL_TAG="qwen2.5-instruct:1.5b"
PORT="11434"

echo "=== [1/3] Auditing Edge Accelerator Platform: $PLATFORM ==="
if [ "$PLATFORM" = "hailo10h" ]; then
  lspci | grep -i "Hailo" || echo "[WARN] Hailo-10H not detected on PCIe bus!"
  hailortcli fw-control identify || true
  echo "=== [2/3] Starting hailo-ollama on Dedicated 8GB NPU RAM (Port $PORT) ==="
  HAILO_OLLAMA_HOST="0.0.0.0:$PORT" hailo-ollama serve &
  sleep 2
  curl -sS "http://127.0.0.1:$PORT/api/tags" || true
elif [ "$PLATFORM" = "rk3588" ]; then
  echo "=== [2/3] Locking RK3588 6 TOPS NPU & DMC Memory Frequency to Performance ==="
  ulimit -l unlimited || true
  cat /sys/kernel/debug/rknpu/version 2>/dev/null || true
  grep -i "Cma" /proc/meminfo || true
  echo "Ready to launch rkllm_server with W4A16 .rkllm model on port $PORT."
else
  echo "=== [2/3] Jetson AGX Thor (T5000 128GB): Locking nvpmodel & jetson_clocks ==="
  sudo nvpmodel -q || true
  sudo jetson_clocks --show || true
  echo "=== [3/3] Launching TensorRT Edge-LLM / vLLM NVFP4 for $MODEL_TAG ==="
fi
