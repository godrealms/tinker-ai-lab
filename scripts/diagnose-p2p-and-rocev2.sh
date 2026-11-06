#!/usr/bin/env bash
# Tinker AI — Multi-GPU PCIe P2P & ConnectX-7 200GbE RoCEv2 Doctor (Guide #32)
set -euo pipefail

IFACE="enp1s0f0np0"
TARGET_MTU="9000"

echo "=== [1/4] Auditing Kernel IOMMU Passthrough (iommu=pt) ==="
CMDLINE=$(cat /proc/cmdline)
echo "Kernel cmdline: $CMDLINE"
if echo "$CMDLINE" | grep -q "iommu=pt"; then
  echo "[OK] iommu=pt is active (direct PCIe BAR1 P2P DMA enabled)."
else
  echo "[WARN] iommu=pt is MISSING! Multi-GPU vLLM (TP>=2) on AMD/Intel boards may deadlock. Add iommu=pt to GRUB or set export NCCL_P2P_DISABLE=1."
fi

echo "=== [2/4] Checking PCIe ACS Redirection & GPU P2P Matrix ==="
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi topo -p2p r || true
elif command -v rocm-smi >/dev/null 2>&1; then
  rocm-smi --showtopo || true
fi
sudo lspci -vvv 2>/dev/null | grep -E "ACSCtl:.*SrcValid\+" | head -n 5 && echo "[INFO] PCIe ACS is enabled on bridge ports; if NCCL hangs, export NCCL_P2P_DISABLE=1 or disable ACS in BIOS." || true

echo "=== [3/4] Checking ConnectX-7 / RDMA Devices & Interface MTU ($IFACE -> $TARGET_MTU) ==="
if ip link show "$IFACE" >/dev/null 2>&1; then
  ip -br link show "$IFACE"
  ip link show "$IFACE" | grep -q "mtu $TARGET_MTU" && echo "[OK] $IFACE MTU is $TARGET_MTU" || echo "[WARN] $IFACE MTU is not $TARGET_MTU! Run: sudo ip link set dev $IFACE mtu $TARGET_MTU"
fi

echo "=== [4/4] Inspecting RoCEv2 GID Index Table ==="
if command -v show_gids >/dev/null 2>&1; then
  show_gids | grep -i "v2" | head -n 8 || true
  echo "Recommended NCCL env: export NCCL_IB_HCA=mlx5_0:1 NCCL_IB_GID_INDEX=3 NCCL_SOCKET_IFNAME=$IFACE"
fi
