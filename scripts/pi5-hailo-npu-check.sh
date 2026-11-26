#!/usr/bin/env bash
# Tinker AI Maker Lab — Raspberry Pi 5 + Hailo-8L NPU Diagnostic
set -euo pipefail

echo "=== [1/4] Checking PCIe Enumeration (Target Gen 3) ==="
lspci | grep -i "Hailo" || echo "[FAIL] Hailo-8L not found on PCIe bus! Check M.2 HAT+ ribbon cable & dtparam=pciex1."

echo "=== [2/4] Verifying HailoRT Firmware & Device Identity ==="
if command -v hailortcli >/dev/null 2>&1; then
  hailortcli fw-control identify
else
  echo "[WARN] hailortcli not installed. Run: sudo apt install hailo-all && sudo reboot"
fi

echo "=== [3/4] Checking Pi 5 Power & Thermal Headroom ==="
vcgencmd get_throttled && vcgencmd measure_temp

echo "=== [4/4] Verifying Paired CPU LLM (qwen2.5:3b) Co-Existence ==="
free -h
ollama ps || true
