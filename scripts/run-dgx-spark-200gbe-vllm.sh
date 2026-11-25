#!/usr/bin/env bash
# Tinker AI — NVIDIA DGX Spark (GB10) UMA Cache Flush & 200GbE RoCEv2 vLLM Runner (Guide #29)
set -euo pipefail

IFACE="enp1s0f0np0"
HEAD_IP="192.168.10.1"
MODEL="Qwen/Qwen3-235B-A22B-FP8"
PP_SIZE="2"

echo "=== [1/4] Flushing Linux VFS Page Cache on GB10 128GB Unified Memory ==="
sync && echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null
free -h

echo "=== [2/4] Verifying ConnectX-7 200GbE Interface ($IFACE) & MTU 9000 ==="
if ip link show "$IFACE" >/dev/null 2>&1; then
  sudo ip link set dev "$IFACE" mtu 9000
  ethtool "$IFACE" | grep -E "Speed|Link detected" || true
fi

echo "=== [3/4] Exporting NCCL RoCEv2 Environment Variables (sm_121 / mlx5_0) ==="
export NCCL_DEBUG=INFO
export NCCL_IB_DISABLE=0
export NCCL_IB_HCA=mlx5_0:1
export NCCL_IB_GID_INDEX=3
export NCCL_SOCKET_IFNAME="$IFACE"
export GLOO_SOCKET_IFNAME="$IFACE"

echo "=== [4/4] Launching vLLM ($MODEL, PP=$PP_SIZE) on Head IP $HEAD_IP ==="
python3 -m vllm.entrypoints.openai.api_server \
  --model "$MODEL" \
  --pipeline-parallel-size "$PP_SIZE" \
  --distributed-executor-backend ray \
  --max-model-len 32768 \
  --gpu-memory-utilization 0.88 \
  --enable-prefix-caching \
  --host 0.0.0.0 --port 8000
