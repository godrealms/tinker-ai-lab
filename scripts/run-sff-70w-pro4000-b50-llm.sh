#!/usr/bin/env bash
# Tinker AI — 70W SFF Workstation GPU & Open PCIe Accelerator HomeLab Runner (Guide #42)
set -euo pipefail

MODEL="./models/Qwen3-30B-A3B-Q4_K_M.gguf"
CTX="32768"
PORT="8080"

echo "=== [1/3] Probing PCIe Slot Power, ECC State & Accelerator Backend ==="
if command -v nvidia-smi >/dev/null 2>&1; then
  echo "[NVIDIA CUDA] Checking RTX PRO 4000 Blackwell SFF 70W TBP, ECC mode & PCIe link:"
  nvidia-smi --query-gpu=name,power.draw,power.limit,ecc.mode.current,memory.total,memory.free,pcie.link.gen.current,pcie.link.width.current --format=csv
elif command -v tt-smi >/dev/null 2>&1; then
  echo "[Tenstorrent Blackhole] Checking p150a / p300c Tensix ASIC state & telemetry:"
  tt-smi -s
else
  echo "[Intel Arc Pro B50 / Vulkan / SYCL] Listing active XPU devices:"
  ./build/bin/llama-bench --list-devices
fi

echo "=== [2/3] Running Quick 512-Token Prefill & 128-Token Decode Sanity Check ==="
./build/bin/llama-bench -m "$MODEL" -ngl 99 -fa 1 -ctk q8_0 -ctv q8_0 -p 512 -n 128 -r 2 -o md

echo "=== [3/3] Starting Low-Power 24/7 HomeLab llama-server on Port $PORT ==="
./build/bin/llama-server \
  -m "$MODEL" \
  -ngl 99 -fa \
  -ctk q8_0 -ctv q8_0 \
  -c "$CTX" \
  --host 0.0.0.0 --port "$PORT"
