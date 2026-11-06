#!/usr/bin/env bash
# Tinker AI — New Hardware GPU & Unified Memory Diagnostic Probe (Guide #24)
set -euo pipefail

DRI_DEV="/dev/dri/renderD128"
MIN_GB="24"

echo "=== [1/4] Kernel Boot Parameters & Deprecated Flag Check ==="
CMDLINE=$(cat /proc/cmdline 2>/dev/null || echo "N/A")
echo "Kernel: $(uname -r) | Cmdline: $CMDLINE"
if echo "$CMDLINE" | grep -q "amdgpu.gttsize"; then
  echo "[WARN] Deprecated 'amdgpu.gttsize' detected! On Linux 6.14+, migrate to 'amdttm.pages_limit' + 'amdttm.page_pool_size' or BIOS UMA Frame Buffer."
fi

echo "=== [2/4] AMD Strix Halo (gfx1151) / ROCm TTM Memory Ceiling ==="
if [ -f /sys/module/amdttm/parameters/pages_limit ]; then
  PAGES=$(cat /sys/module/amdttm/parameters/pages_limit)
  POOL_GB=$(( PAGES * 4 / 1024 / 1024 ))
  echo "amdttm.pages_limit = $PAGES (~$POOL_GB GB)"
  if [ "$POOL_GB" -lt "$MIN_GB" ]; then
    echo "[FAIL] Addressable GTT pool ($POOL_GB GB) is below required $MIN_GB GB!"
  fi
fi

echo "=== [3/4] Intel Arc B580 (Xe2) & Linux DRI Render Group Audit ==="
if [ -e "$DRI_DEV" ]; then
  RENDER_GID=$(stat -c "%g" "$DRI_DEV" 2>/dev/null || stat -f "%g" "$DRI_DEV")
  echo "Found $DRI_DEV -> Host render GID is $RENDER_GID (Pass '--group-add $RENDER_GID' to Docker)"
else
  echo "No $DRI_DEV device found on this host."
fi

echo "=== [4/4] Unified Memory (DGX Spark / Strix Halo / Jetson) Page Cache Pressure ==="
free -g || vm_stat || true
echo "If 'buff/cache' is holding >20GB on a Unified Memory Linux host and causing cudaMallocManaged/ROCm OOM, run:"
echo "  sync && echo 3 | sudo tee /proc/sys/vm/drop_caches"
