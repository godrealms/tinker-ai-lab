#!/usr/bin/env bash
# Tinker AI — Rebellions ATOM-Max (vllm-rbln) & SGLang vs vLLM RadixAttention / Eagle-3 Launcher (Guide #49)
set -euo pipefail

MODE="sglang_radix"
MODEL="Qwen/Qwen3.6-35B-A3B"
TP="1"
PORT="30000"

if [ "$MODE" = "sglang_radix" ]; then
  echo "=== [SGLang Mode] Launching RadixAttention + FP8 KV Cache + Eagle-3/MTP Server on Port $PORT ==="
  nvidia-smi --query-gpu=index,name,memory.total,utilization.gpu --format=csv || true
  python3 -m sglang.launch_server \
    --model-path "$MODEL" \
    --tp-size "$TP" \
    --kv-cache-dtype fp8_e5m2 \
    --context-length 65536 \
    --mem-fraction-static 0.88 \
    --chunked-prefill-size 8192 \
    --host 0.0.0.0 --port "$PORT"
elif [ "$MODE" = "vllm_apc" ]; then
  echo "=== [vLLM Mode] Launching PagedAttention + Automatic Prefix Caching + FP8 KV on Port $PORT ==="
  vllm serve "$MODEL" \
    --tensor-parallel-size "$TP" \
    --enable-prefix-caching \
    --kv-cache-dtype fp8 \
    --max-model-len 65536 \
    --gpu-memory-utilization 0.90 \
    --host 0.0.0.0 --port "$PORT"
elif [ "$MODE" = "rbln_npu" ]; then
  echo "=== [Rebellions NPU Mode] Auditing ATOM-Max (64GB 4-Die RBLN-CA25) via rbln-smi ==="
  rbln-smi
  COMPILED_DIR="./rbln-compiled-$(basename "$MODEL")-tp4"
  if [ ! -d "$COMPILED_DIR" ]; then
    echo "Compiling static PagedAttention graph for 4x ATOM dies (batch=4, max_seq_len=32768)..."
    optimum-cli export rbln \
      --model "$MODEL" \
      --batch_size 4 \
      --max_seq_len 32768 \
      --tensor_parallel_size 4 \
      --kvcache_partition_len 4096 \
      "$COMPILED_DIR"
  fi
  echo "Starting vLLM with Rebellions RBLN device backend on port $PORT..."
  vllm serve "$COMPILED_DIR" \
    --device rbln \
    --max-num-seqs 4 \
    --max-model-len 32768 \
    --host 0.0.0.0 --port "$PORT"
else
  echo "Unknown ENGINE_MODE=$MODE (expected: sglang_radix | vllm_apc | rbln_npu)" >&2
  exit 1
fi
