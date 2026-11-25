#!/usr/bin/env bash
# Tinker AI — Ling-3.2-air (124B-A5.5B KDA/MLA), SenseNova-Loop-9B (32->56 mHC) & TML-d24-varloop Launcher (Guide #66)
set -euo pipefail

PROFILE="ling32_air_sglang_or_gguf"
MODEL="./models/Ling-3.2-air-124B-A5.5B-Q4_K_M.gguf"
LOOPS="2"
CTX="131072"
PORT="8080"

echo "=== [Host Check] Auditing Unified Memory (GEEKOM A9 Mega 128GB / Strix Halo) or Discrete GPU ==="
grep -E 'MemTotal|MemAvailable' /proc/meminfo 2>/dev/null || sysctl hw.memsize 2>/dev/null || true

if [ "$PROFILE" = "ling32_air_sglang_or_gguf" ]; then
  echo "=== [Ant InclusionAI Ling-3.2-air 124B-A5.5B · 35 KDA + 7 Gated MLA] Launching with 262K-Ready KV Compression ==="
  if [[ "$MODEL" == *.gguf ]]; then
    exec llama-server -m "$MODEL" \
      -ngl 99 -fa on \
      --cache-type-k q8_0 --cache-type-v q8_0 \
      -c "$CTX" --host 127.0.0.1 --port "$PORT"
  else
    exec python3 -m sglang.launch_server \
      --model-path "$MODEL" \
      --trust-remote-code \
      --kv-cache-dtype fp8_e4m3 \
      --context-length "$CTX" \
      --mem-fraction-static 0.88 --port "$PORT"
  fi
elif [ "$PROFILE" = "sensenova_loop_9b_512k" ]; then
  echo "=== [SenseTime SenseNova-Loop-9B · 32 Physical -> 56 Effective Layers via mHC] Serving 512K Long-Context VLM ==="
  exec vllm serve sensenova/SenseNova-Loop-9B \
    --trust-remote-code \
    --kv-cache-dtype fp8 \
    --max-model-len "$CTX" \
    --gpu-memory-utilization 0.88 --port "$PORT"
elif [ "$PROFILE" = "tml_varloop_dynamic_depth" ]; then
  echo "=== [Thinking Machines TML-d24-varloop-research] Serving Variable-Depth Looped MoE (default num_loops=$LOOPS) ==="
  export TML_VARLOOP_DEFAULT_STEPS="$LOOPS"
  exec vllm serve thinkingmachines/TML-d24-varloop-research \
    --trust-remote-code \
    --hf-overrides "{\"num_inference_loops\": $LOOPS}" \
    --max-model-len "$CTX" \
    --gpu-memory-utilization 0.88 --port "$PORT"
else
  echo "Unknown LAUNCH_PROFILE=$PROFILE (expected: ling32_air_sglang_or_gguf | sensenova_loop_9b_512k | tml_varloop_dynamic_depth)" >&2
  exit 1
fi
