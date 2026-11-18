#!/usr/bin/env bash
# Tinker AI — macOS Thunderbolt 5 RDMA & MLX JACCL Distributed Cluster Launcher (Guide #41)
set -euo pipefail

HOSTS="mac-studio-1.local,mac-studio-2.local"
MODEL="mlx-community/DeepSeek-R1-671B-4bit"
WIRED_MB="110592"
HOSTFILE="tb5-jaccl-hosts.json"

echo "=== [1/4] Auditing Thunderbolt 5 RDMA Subsystem (rdma_ctl & ibv_devices) ==="
rdma_ctl status || echo "[WARN] rdma_ctl not enabled! Reboot into macOS Recovery -> Terminal -> run: rdma_ctl enable"
ibv_devices | grep -E "rdma_en|device" || {
  echo "[ERROR] No rdma_en* verbs device found. Ensure Thunderbolt 5 cables are directly connected (no daisy chain)."
  exit 1
}

echo "=== [2/4] Raising Metal Wired Memory Limit ($WIRED_MB MB) Across Cluster Nodes ==="
IFS=',' read -ra NODE_ARRAY <<< "$HOSTS"
for NODE in "${NODE_ARRAY[@]}"; do
  echo "-> Tuning $NODE"
  ssh "$NODE" "sudo sysctl -w iogpu.wired_limit_mb=$WIRED_MB && ibv_devices"
done

echo "=== [3/4] Generating JACCL Full-Mesh Topology Config ($HOSTFILE) ==="
mlx.distributed_config --verbose --hosts "$HOSTS" --backend jaccl > "$HOSTFILE"
cat "$HOSTFILE"

echo "=== [4/4] Launching Tensor-Parallel MLX Distributed Inference (JACCL + Fast Metal Sync) ==="
mlx.launch \
  --backend jaccl \
  --hostfile "$HOSTFILE" \
  --env MLX_METAL_FAST_SYNCH=1 \
  -m mlx_lm.generate \
  --model "$MODEL" \
  --max-tokens 512 \
  --prompt "Explain why Thunderbolt 5 RDMA (~3 us latency) enables Tensor Parallelism across Apple Silicon Macs."
