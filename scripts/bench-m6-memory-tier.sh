#!/usr/bin/env bash
# Tinker AI — Apple M6 MacBook Pro Memory-Tier Benchmark (Guide #38)
set -euo pipefail

MODEL="./models/Qwen3-14B-Q4_K_M.gguf"
WIRED="0"
PROMPT_TOKENS="2048"

echo "=== [1/4] Chip & memory tier ==="
system_profiler SPHardwareDataType | grep -E "Chip|Memory"

echo "=== [2/4] GPU wired-memory limit ==="
if [ "$WIRED" != "0" ]; then
  sudo sysctl iogpu.wired_limit_mb="$WIRED"
fi
sysctl iogpu.wired_limit_mb

swapins() { vm_stat | awk '/Swapins/ {gsub("\\.","",$2); print $2}'; }
BEFORE=$(swapins)

echo "=== [3/4] llama-bench pp$PROMPT_TOKENS / tg128 x3, Q8_0 KV ==="
llama-bench -m "$MODEL" -ngl 99 -fa 1 -ctk q8_0 -ctv q8_0 -p "$PROMPT_TOKENS" -n 128 -r 3 -o md

AFTER=$(swapins)
echo "=== [4/4] Swap guard ==="
if [ "$AFTER" -gt "$BEFORE" ]; then
  echo "[INVALID] macOS swapped $((AFTER - BEFORE)) pages during the run — this model is too large for this memory tier."
else
  echo "[OK] No swap during benchmark — result is valid for this memory tier."
fi
