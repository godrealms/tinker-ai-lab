#!/usr/bin/env bash
# Tinker AI — AMD Ryzen AI Max+ 395 (Strix Halo 128GB · gfx1151) UMA & LLM Verifier (Guide #21)
set -euo pipefail

MODEL="qwen3:30b-a3b-q4_K_M"
TARGET_PAGES="25165824"
CTX="32768"

echo "=== [1/4] Kernel, BIOS UMA & TTM Page Limit Audit ==="
uname -r
if [ -f /sys/module/amdttm/parameters/pages_limit ]; then
  CUR_PAGES=$(cat /sys/module/amdttm/parameters/pages_limit)
  CUR_GB=$(( CUR_PAGES * 4 / 1024 / 1024 ))
  echo "Current amdttm.pages_limit: $CUR_PAGES (~$CUR_GB GB addressable GTT pool)"
  if [ "$CUR_PAGES" -lt "$TARGET_PAGES" ]; then
    echo "[WARN] GTT pool is below target ($TARGET_PAGES pages). Add 'amdttm.pages_limit=$TARGET_PAGES amdttm.page_pool_size=$TARGET_PAGES' to GRUB_CMDLINE_LINUX_DEFAULT."
  fi
fi

echo "=== [2/4] Verifying Radeon 8060S (gfx1151) Visible VRAM ==="
if command -v rocminfo >/dev/null 2>&1; then
  rocminfo | grep -E "Name:\s+gfx|Size:" | head -n 6 || true
fi

echo "=== [3/4] Applying Strix Halo ROCm hipBLASLt & Flash Attention Optimizations ==="
export ROCBLAS_USE_HIPBLASLT=1
export OLLAMA_FLASH_ATTENTION=1
export OLLAMA_KV_CACHE_TYPE=q8_0
echo "Exported ROCBLAS_USE_HIPBLASLT=1 OLLAMA_FLASH_ATTENTION=1 OLLAMA_KV_CACHE_TYPE=q8_0"

echo "=== [4/4] Benchmarking $MODEL at num_ctx=$CTX (seed=42) ==="
curl -sS http://127.0.0.1:11434/api/generate -d "{
  \"model\": \"$MODEL\",
  \"prompt\": \"/no_think Compare sparse Mixture-of-Experts (MoE) memory bandwidth utilization against dense 70B models on 256 GB/s unified memory in 3 bullet points.\",
  \"stream\": false,
  \"options\": { \"num_ctx\": $CTX, \"temperature\": 0, \"seed\": 42 }
}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ec = d.get('eval_count', 0)
ed = d.get('eval_duration', 1) / 1e9
pc = d.get('prompt_eval_count', 0)
pd = d.get('prompt_eval_duration', 1) / 1e9
print(f'Prefill Speed : {pc} tokens ({pc/pd:.1f} tok/s)')
print(f'Decode Speed  : {ec} tokens ({ec/ed:.2f} tok/s)')
"
ollama ps
