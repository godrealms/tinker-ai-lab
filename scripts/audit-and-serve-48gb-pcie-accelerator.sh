#!/usr/bin/env bash
# Tinker AI — 48GB–96GB PCIe Inference Card Doctor & OpenAI Server Launcher (Guide #47)
set -euo pipefail

MODE="cuda48g"
MODEL="Qwen/Qwen3.6-35B-A3B-FP8"
PL_WATTS="350"
PORT="8000"

echo "=== [1/3] Enumerating PCIe Gen4/Gen5 Link Width, Airflow & BAR Mapping ==="
lspci -nn | grep -iE "VGA|3D|Processing|Furiosa|Huawei" || true

if [ "$MODE" = "furiosa" ]; then
  echo "=== [2/3] Auditing FuriosaAI RNGD (48GB HBM3 · 180W TCP) via furiosa-smi ==="
  furiosa-smi
  echo "Note: Ensure chassis airflow keeps passive RNGD die < 78C under sustained prefill!"
  echo "=== [3/3] Launching furiosa-llm OpenAI Server on port $PORT ==="
  furiosa-llm serve "$MODEL" \
    --host 0.0.0.0 \
    --port "$PORT"
elif [ "$MODE" = "cuda48g" ]; then
  echo "=== [2/3] Auditing Clamshell RTX 4090 48GB Blower & Clamping Power to ${PL_WATTS}W ==="
  sudo nvidia-smi -pm 1 || true
  sudo nvidia-smi -pl "$PL_WATTS" || true
  nvidia-smi --query-gpu=index,name,memory.total,power.limit,temperature.gpu,pstate --format=csv
  nvidia-smi topo -m || true
  echo "=== [3/3] Launching vLLM OpenAI Server (48GB Single-Card Zero-Split Mode) ==="
  vllm serve "$MODEL" \
    --max-model-len 65536 \
    --gpu-memory-utilization 0.92 \
    --enable-prefix-caching \
    --host 0.0.0.0 --port "$PORT"
elif [ "$MODE" = "ascend" ]; then
  echo "=== [2/3] Auditing Huawei Atlas 300I Duo (2x 48GB Ascend 310P Dies) via npu-smi ==="
  npu-smi info
  ls -la /dev/davinci* /dev/davinci_manager /dev/devmm_svm /dev/hisi_hdc || true
  echo "=== [3/3] Reminder: Use FP16 / W8A8 (NOT BF16) across TP=2 (/dev/davinci0,1) in MindIE ==="
  docker ps --filter "ancestor=ascendhub.huawei.com/public-ascendhub/mindie" || echo "Ready to start MindIE W8A8 container on port $PORT (bind /dev/davinci0 & /dev/davinci1)."
else
  echo "Unknown BACKEND_MODE=$MODE (expected: furiosa | cuda48g | ascend)" >&2
  exit 1
fi
