#!/usr/bin/env bash
# Tinker AI — llama.cpp v1.0.0 OCP FP8 KV Cache & MoE Host-Memory Cache Launcher (Guide #51)
set -euo pipefail

MODEL="models/LiquidAI_LFM3-1.7B-Q4_K_M.gguf"
KV_TYPE="fp8_e4m3"
CTX="32768"
CPU_MOE="0"
PORT="8080"

echo "=== Verifying llama.cpp v1.0.0+ binary & starting hardened llama-server ==="
llama-server --version || true

EXTRA_FLAGS=()
if [ "$CPU_MOE" -gt 0 ] 2>/dev/null; then
  EXTRA_FLAGS+=(--n-cpu-moe "$CPU_MOE")
fi

# Note: llama.cpp v1.0.0 enables SSRF/DNS-rebinding hardening & auto-cancels MCP calls on disconnect
exec llama-server \
  -m "$MODEL" \
  -c "$CTX" \
  -fa on \
  --cache-type-k "$KV_TYPE" \
  --cache-type-v "$KV_TYPE" \
  -ngl 99 \
  "${EXTRA_FLAGS[@]}" \
  --host 127.0.0.1 \
  --port "$PORT"
