#!/usr/bin/env bash
# Tinker AI — Intel Arc Pro B60 Dual 48GB ("Battlematrix") x8/x8 Audit & vLLM-XPU Launcher (Guide #45)
set -euo pipefail

MODEL="Qwen/Qwen3.5-35B-A3B-Instruct"
TP="2"
MASK="0,1"
PORT="8000"

echo "=== [1/4] Auditing PCIe x8/x8 Bifurcation & Enumerated Intel BMG-G21 GPUs ==="
GPU_COUNT=$(lspci -nn | grep -icE "(VGA|Display|3D).*8086:(e20b|e20c|e211|e212)" || true)
lspci -nn | grep -iE "(VGA|Display|3D).*8086" || true
echo "-> Detected Intel Arc Xe2 GPU dies: $GPU_COUNT (Expect 2 per Arc Pro B60 Dual 48GB card!)"
if [ "$GPU_COUNT" -lt "$TP" ]; then
  echo "[WARN] Enumerated GPU dies ($GPU_COUNT) < requested TP_SIZE ($TP)!"
  echo "       Enter motherboard BIOS -> PCIe Slot Configuration -> Set slot from [Auto/x16] to [x8/x8] (or [x8/x8/x8/x8])."
fi

echo "=== [2/4] Verifying Above 4G Decoding & >=32GB Resizable BAR (BAR2) Aperture ==="
sudo lspci -vv -d 8086: | grep -E "Region 2: Memory|LnkSta:" | head -n 8 || true
ls -la /dev/dri/renderD*

echo "=== [3/4] Checking Host IOMMU P2P Passthrough (iommu=pt recommended on WRX90 / Xeon) ==="
grep -o "iommu=[^ ]*" /proc/cmdline || echo "Note: Add iommu=pt to GRUB_CMDLINE_LINUX_DEFAULT if multi-die AllReduce stalls."

echo "=== [4/4] Launching intel/llm-scaler-vllm (TP=$TP, ZE_AFFINITY_MASK=$MASK, Port=$PORT) ==="
docker run --rm -it \
  --device /dev/dri \
  --group-add video --group-add render \
  --shm-size=32g \
  --ipc=host \
  -p "$PORT:8000" \
  -v "$HOME/.cache/huggingface:/root/.cache/huggingface" \
  -e ZE_AFFINITY_MASK="$MASK" \
  -e SYCL_CACHE_PERSISTENT=1 \
  -e SYCL_PI_LEVEL_ZERO_USE_IMMEDIATE_COMMANDLISTS=1 \
  intel/llm-scaler-vllm:latest \
  --model "$MODEL" \
  --tensor-parallel-size "$TP" \
  --quantization fp8 \
  --max-model-len 65536 \
  --gpu-memory-utilization 0.90 \
  --trust-remote-code
