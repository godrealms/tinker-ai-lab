#!/usr/bin/env bash
# Tinker AI — Blackwell (sm_120) & RDNA 4 (gfx1201) Compute Doctor (Guide #28)
set -euo pipefail

SM_TARGET="12.0"
GFX_TARGET="gfx1201"

echo "=== [1/4] NVIDIA Blackwell ($SM_TARGET) Driver & PCIe Link Audit ==="
if command -v nvidia-smi >/dev/null 2>&1; then
  nvidia-smi --query-gpu=name,driver_version,compute_cap,pcie.link.gen.current,pcie.link.gen.max,power.draw,power.limit --format=csv
else
  echo "No nvidia-smi detected; skipping NVIDIA check."
fi

echo "=== [2/4] PyTorch / CUDA sm_120 Kernel Image Verification ==="
if command -v python3 >/dev/null 2>&1; then
  python3 -c "
import sys
try:
    import torch
    arches = torch.cuda.get_arch_list()
    print('PyTorch:', torch.__version__, '| CUDA:', torch.version.cuda, '| Arches:', arches)
    if not any('12.0' in a or '120' in a for a in arches):
        print('[FAIL] PyTorch build lacks sm_120! Install CUDA 12.8 (+cu128) wheels or set TORCH_CUDA_ARCH_LIST="12.0+PTX".')
except Exception as e:
    print('Torch check skipped:', e)
"
fi

echo "=== [3/4] Kernel PCIe 5.0 AER & NVRM Xid 79 Bus Drop Audit ==="
dmesg -T 2>/dev/null | grep -iE "AER|Xid|fallen off the bus|amdgpu.*error" | tail -n 15 || echo "[OK] Zero PCIe AER or GPU Xid errors found."

echo "=== [4/4] AMD RDNA 4 ($GFX_TARGET) ROCm Override Trap Check ==="
if [ -n "${HSA_OVERRIDE_GFX_VERSION:-}" ]; then
  echo "[WARN] HSA_OVERRIDE_GFX_VERSION=$HSA_OVERRIDE_GFX_VERSION is set! On $GFX_TARGET (RDNA 4), spoofing gfx1100 causes INVALID_ISA crashes. Run: unset HSA_OVERRIDE_GFX_VERSION"
else
  echo "[OK] HSA_OVERRIDE_GFX_VERSION is not polluting the environment."
fi
