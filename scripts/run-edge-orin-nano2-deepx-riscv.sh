#!/usr/bin/env bash
# Tinker AI — Edge AI Runner: DEEPX DX-M1M (3W Pi 5) / Jetson Orin Nano 2 / RISC-V RVA23 (Guide #52)
set -euo pipefail

PLATFORM="pi5_deepx_lfm3"
MODEL="models/LFM3-1.7B-Q4_K_M.gguf"
THREADS="4"
PORT="8080"

if [ "$PLATFORM" = "pi5_deepx_lfm3" ]; then
  echo "=== [Pi 5 + DEEPX DX-M1M 3W Mode] Checking PCIe Gen3 NPU & launching LFM3-1.7B on CPU ==="
  lspci | grep -iE "DEEPX|DX-M1" || echo "Note: DEEPX M.2 NPU not detected on PCIe; running CPU-only LFM3."
  exec llama-server -m "$MODEL" -t "$THREADS" -c 16384 -fa on --cache-type-k q8_0 --port "$PORT"
elif [ "$PLATFORM" = "jetson_cuda" ]; then
  echo "=== [Jetson Orin Nano 2 / Orin Nano Super CUDA Mode] Offloading 100% layers to GPU ==="
  nvpmodel -q || true
  exec llama-server -m "$MODEL" -ngl 99 -c 32768 -fa on --cache-type-k fp8_e4m3 --port "$PORT"
elif [ "$PLATFORM" = "riscv_rvv" ]; then
  echo "=== [RISC-V RVA23 Vector Mode] Checking RVV ISA & running llama.cpp v1.0.0 ==="
  grep -i "isa" /proc/cpuinfo | head -n 2 || true
  exec llama-server -m "$MODEL" -t "$THREADS" -c 16384 --port "$PORT"
  else
    echo "Unknown EDGE_PLATFORM=$PLATFORM (expected: pi5_deepx_lfm3 | jetson_cuda | riscv_rvv)" >&2
    exit 1
  fi
  
