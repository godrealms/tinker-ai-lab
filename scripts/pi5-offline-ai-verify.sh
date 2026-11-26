#!/usr/bin/env bash
# Tinker AI Maker Lab — Raspberry Pi 5 Pre-Flight & BOM Verification
set -euo pipefail

echo "=== [1/4] Checking Power Supply & Thermal Throttling ==="
if command -v vcgencmd >/dev/null 2>&1; then
  THROTTLED=$(vcgencmd get_throttled)
  TEMP=$(vcgencmd measure_temp)
  echo "Status: $THROTTLED | Temp: $TEMP"
  if [ "$THROTTLED" != "throttled=0x0" ]; then
    echo "WARNING: Under-voltage or thermal throttling detected! Use official 5V/5A (27W) USB-C PD supply + active cooler."
  fi
fi

echo "=== [2/4] Verifying USB Audio (USB) & Camera Devices ==="
arecord -l | grep -i "USB" || echo "Notice: Matching USB microphone not found."
ls -l /dev/video* 2>/dev/null || echo "Notice: No /dev/video* camera node detected."

echo "=== [3/4] Checking Available Memory (Require >= 4.5GB Free for qwen2.5:3b) ==="
free -h

echo "=== [4/4] Smoke-Testing Offline Model (qwen2.5:3b, num_ctx=2048) ==="
ollama run "qwen2.5:3b" "Reply in 10 words: confirm offline edge node is operational."
