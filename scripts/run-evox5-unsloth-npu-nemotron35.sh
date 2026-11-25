#!/usr/bin/env bash
# Tinker AI — GMKtec EVO-X5 Pro (192GB / 160GB VRAM) + Unsloth XDNA 2 NPU (Q4NX) & Nemotron 3.5 Super VL 120B (Guide #60)
set -euo pipefail

MODE="evox5_nemotron35_super_vl"
GGUF="./models/NVIDIA-Nemotron-3.5-Super-VL-120B-A12B-Q4_K_M.gguf"
NPU_MODEL="Qwen3.6-35B-A3B-NPU2"
CTX="65536"
PORT="8080"
NPU_PORT="$((PORT + 1))"

echo "=== [EVO-X5 Pro Audit] Checking 192GB UMA, Linux 7.4 iommu_perfopt & XDNA 2 NPU ==="
free -h
cat /sys/module/amdgpu/parameters/iommu_perfopt 2>/dev/null || echo "[TIP] Upgrade to Linux 7.4+ or add iommu=pt for +18-23% UMA tok/s"
ls -l /dev/accel/accel* 2>/dev/null || echo "[WARN] /dev/accel/accel0 not found; verify amdxdna driver for XDNA 2 NPU"

if [ "$MODE" = "evox5_nemotron35_super_vl" ]; then
  echo "=== [Radeon 8065S 160GB UMA] Serving Nemotron 3.5 Super VL 120B-A12B (Mamba-2 Hybrid, ctx=$CTX) ==="
  exec llama-server \
    -m "$GGUF" -ngl 99 -fa on \
    --cache-type-k q8_0 --cache-type-v q8_0 \
    -c "$CTX" --host 127.0.0.1 --port "$PORT"
elif [ "$MODE" = "unsloth_xdna2_npu_q4nx" ]; then
  echo "=== [Unsloth Desktop / Lemonade + FastFlowLM] Serving $NPU_MODEL (Q4NX) on 55 TOPS XDNA 2 NPU ==="
  exec lemonade-server serve \
    --backend flm \
    --model "$NPU_MODEL" \
    --host 127.0.0.1 --port "$NPU_PORT"
elif [ "$MODE" = "dual_igpu_npu_agent" ]; then
  echo "=== [Dual-Engine Concurrent Mode] iGPU ($PORT: Nemotron 3.5 VL) + XDNA 2 NPU ($NPU_PORT: $NPU_MODEL Q4NX) ==="
  lemonade-server serve --backend flm --model "$NPU_MODEL" --host 127.0.0.1 --port "$NPU_PORT" &
  exec llama-server \
    -m "$GGUF" -ngl 99 -fa on \
    --cache-type-k q8_0 --cache-type-v q8_0 \
    -c "$CTX" --host 127.0.0.1 --port "$PORT"
else
  echo "Unknown EXEC_MODE=$MODE (expected: evox5_nemotron35_super_vl | unsloth_xdna2_npu_q4nx | dual_igpu_npu_agent)" >&2
  exit 1
fi
