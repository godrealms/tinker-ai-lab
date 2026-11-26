#!/usr/bin/env bash
# Tinker AI Maker Lab — Rule-First Thermal & Log Anomaly Explainer (Guide #9)
set -euo pipefail

THRESHOLD="68"
MODEL="qwen2.5:3b"

RAW_MILLI=$(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null || echo "45000")
TEMP_C=$((RAW_MILLI / 1000))
RECENT_ERRS=$(journalctl -p err..warning -n 15 --no-pager 2>/dev/null || echo "No systemd errors.")

echo "[Rule Check] Current Temp: ${TEMP_C}°C (Threshold: ${THRESHOLD}°C)"

if [ "$TEMP_C" -ge "$THRESHOLD" ]; then
  echo "[Anomaly Triggered] Invoking local $MODEL for root-cause synthesis..."
  curl -sS http://127.0.0.1:11434/api/generate -d "{
    \"model\": \"$MODEL\",
    \"stream\": false,
    \"options\": { \"temperature\": 0.1, \"num_ctx\": 2048 },
    \"prompt\": \"Hardware alert: Pi 5 temperature reached ${TEMP_C}C. Summarize likely cause and 2 check commands from logs: \n${RECENT_ERRS}\"
  }" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("response",""))'
else
  echo "[OK] Within safe thermal boundary; skipping LLM inference (0% CPU overhead)."
fi
