#!/usr/bin/env bash
# Tinker AI — SC26 DGX Spark 4-Node Switchless 200GbE Ring + LMCache GDS Launcher (Guide #55)
set -euo pipefail

IFACES="enP7s7f0,enP7s7f1"
HEAD_IP="10.10.12.1"
MODEL="deepseek-ai/DeepSeek-V4.1-Flash-NVFP4"
KV_DIR="/nvme/lmcache_gds"
MAX_GB="512"

echo "=== [1/4] Auditing ConnectX-7 200GbE Ring MTU 9000, Diagonal IP Forwarding & GDS ==="
IFS=',' read -ra DEV_ARR <<< "$IFACES"
for dev in "${DEV_ARR[@]}"; do
  ip -br link show "$dev" || echo "WARN: Ring interface $dev not found"
done
sudo sysctl -w net.ipv4.ip_forward=1 >/dev/null
lsmod | grep -q nvidia_fs && echo "OK: nvidia_fs (GPUDirect Storage cuFile) kernel module loaded" || echo "INFO: nvidia_fs not loaded; LMCache will fall back to POSIX O_DIRECT"

echo "=== [2/4] Flushing GB10 Coherent UMA Page Cache Before Sharded Weight mmap ==="
sync && echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null
mkdir -p "$KV_DIR"

echo "=== [3/4] Locking Switchless 4-Node Ring NCCL & LMCache GDS Environment ==="
export NCCL_SOCKET_IFNAME="$IFACES"
export UCX_NET_DEVICES="${DEV_ARR[0]}"
export NCCL_ALGO=Ring
export NCCL_CROSS_NIC=1
export NCCL_BUFFSIZE=4194304
export LMCACHE_USE_EXPERIMENTAL=True
export LMCACHE_LOCAL_CPU=True
export LMCACHE_MAX_LOCAL_CPU_SIZE=16.0
export LMCACHE_CUFILE_BUFFER_SIZE="4096"
export LMCACHE_GDS_PATH="$KV_DIR"
export LMCACHE_MAX_LOCAL_DISK_SIZE="$MAX_GB"

echo "=== [4/4] Starting vLLM TP=4 Distributed Server over Ray ($HEAD_IP:6379) ==="
exec vllm serve "$MODEL" \
  --tensor-parallel-size 4 \
  --distributed-executor-backend ray \
  --quantization nvfp4 \
  --max-model-len 131072 \
  --kv-transfer-config '{"kv_connector":"LMCacheConnectorV1","kv_role":"kv_both"}' \
  --host 0.0.0.0 --port 8000
