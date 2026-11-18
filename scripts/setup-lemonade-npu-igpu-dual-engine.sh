#!/usr/bin/env bash
# Tinker AI — Split-Engine AMD XDNA 2 NPU (FastFlowLM) + Radeon 8060S (ROCm 7.2) Launcher (Guide #48)
set -euo pipefail

ROCM_MODEL="Qwen3.6-35B-A3B-Q8_0-GGUF"
NPU_MODEL="Qwen3-8B-FLM-NPU-INT4"
TTM_PAGES="28311552"
PORT="13305"

echo "=== [1/4] Checking Linux Kernel, amdxdna NPU Device (/dev/accel/accel0) & memlock ==="
uname -r
ls -la /dev/accel/accel0 /dev/kfd /dev/dri/renderD*
MEMLOCK=$(ulimit -l)
echo "Current memlock limit: $MEMLOCK (must be 'unlimited' for XRT / FastFlowLM NPU BO pinning)"
if [ "$MEMLOCK" != "unlimited" ]; then
  echo "WARNING: Run 'echo "* soft memlock unlimited" | sudo tee -a /etc/security/limits.conf' and re-login!"
fi

echo "=== [2/4] Verifying 108GB Unified GTT/TTM Pool (Target pages_limit >= $TTM_PAGES) ==="
cat /sys/module/amdttm/parameters/pages_limit || true
rocm-smi --showmeminfo vram gtt || true

echo "=== [3/4] Running FastFlowLM Hardware & XDNA 2 Firmware Validation ==="
flm --version || true
flm validate

echo "=== [4/4] Pulling NPU + ROCm Models & Starting Unified Lemonade Server on Port $PORT ==="
lemonade-server pull "$NPU_MODEL" || true
lemonade-server pull "$ROCM_MODEL" || true
echo "Starting lemonade-server (OpenAI endpoint: http://127.0.0.1:$PORT/api/v1)..."
HSA_OVERRIDE_GFX_VERSION=11.5.1 ROCBLAS_USE_HIPBLASLT=1 \
  lemonade-server serve --port "$PORT"
