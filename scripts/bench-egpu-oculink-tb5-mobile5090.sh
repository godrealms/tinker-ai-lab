#!/usr/bin/env bash
# Tinker AI — OCuLink 64G / Thunderbolt 5 80G eGPU & RTX 5090 Laptop 24GB LLM Runner (Guide #44)
set -euo pipefail

MODEL="./models/Qwen3-30B-A3B-Q4_K_M.gguf"
CTX="32768"
SPLIT="layer"

echo "=== [1/3] Auditing PCIe Link Negotiation (OCuLink / TB5 x4 vs Internal) & TGP Power Cap ==="
nvidia-smi --query-gpu=index,name,power.draw,power.limit,memory.total,pcie.link.gen.current,pcie.link.gen.max,pcie.link.width.current,pcie.link.width.max --format=csv

echo "=== [2/3] Running Cold Model Load + PP512 / TG128 Throughput Benchmark ==="
TIMEFORMAT="-> Total Wall-Clock Load + Benchmark Time: %3R seconds"
time ./build/bin/llama-bench -m "$MODEL" -ngl 99 -sm "$SPLIT" -fa 1 -ctk q8_0 -ctv q8_0 -p 512 -n 128 -r 2 -o md

echo "=== [3/3] Starting llama-server (--split-mode $SPLIT avoids eGPU AllReduce bottlenecks) ==="
./build/bin/llama-server \
  -m "$MODEL" \
  -ngl 99 --split-mode "$SPLIT" \
  -fa -ctk q8_0 -ctv q8_0 \
  -c "$CTX" \
  --host 0.0.0.0 --port 8080
