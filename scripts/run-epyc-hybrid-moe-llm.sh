#!/usr/bin/env bash
# Tinker AI — AMD EPYC 12-Channel DDR5 + Single GPU Hybrid MoE Launcher (Guide #33)
set -euo pipefail

ENGINE="ik_llama"
MODEL_PATH="/mnt/nvme/models/DeepSeek-R1-671B-IQ4_XS.gguf"
THREADS="32"
CTX="32768"

echo "=== [1/3] Auditing NUMA Topology & Disabling Linux Auto-NUMA Thrashing ==="
sudo sysctl -w kernel.numa_balancing=0 >/dev/null || true
numactl --hardware | head -n 10 || true

echo "=== [2/3] Flushing VFS Page Cache Before Mapping 250GB–400GB MoE Weights ==="
sync && echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null

echo "=== [3/3] Launching Hybrid GPU (Attention+KV) + CPU (MoE Experts) Engine: $ENGINE ==="
if [ "$ENGINE" = "ktransformers" ]; then
  export USE_NUMA=1
  python3 -m ktransformers.server.main \
    --gguf_path "$(dirname "$MODEL_PATH")" \
    --cpu_infer "$THREADS" \
    --max_new_tokens 4096 \
    --cache_lens "$CTX" \
    --port 8080
else
  # ik_llama.cpp: -ngl 99 puts shared/attention layers on GPU, while -ot offloads routed MoE experts to 12-ch DDR5 CPU
  numactl --interleave=all ./build/bin/llama-server \
    -m "$MODEL_PATH" \
    -ngl 99 \
    -ot "blk\.[0-9]+\.ffn_.*_exps\.weight=CPU" \
    -fa -ctk q8_0 -ctv q8_0 \
    -c "$CTX" -t "$THREADS" \
    --host 0.0.0.0 --port 8080
fi
