#!/usr/bin/env bash
# Tinker AI — Jetson Orin Nano Super (JetPack 6.2 · 67 TOPS) Edge AI Verifier (Guide #22)
set -euo pipefail

MODE_ID="2"
MODEL="qwen3:4b-q4_K_M"
CTX="4096"

echo "=== [1/4] Verifying JetPack Power Profile (Target: Mode $MODE_ID / 25W MAXN_SUPER) ==="
if command -v nvpmodel >/dev/null 2>&1; then
  sudo nvpmodel -m "$MODE_ID" || true
  sudo nvpmodel -q
  sudo jetson_clocks --show | head -n 8 || true
fi

echo "=== [2/4] Unified 8GB LPDDR5 Memory & Page Cache Audit ==="
free -h
echo "Reclaiming Linux page cache before CUDA allocation..."
sync && echo 3 | sudo tee /proc/sys/vm/drop_caches >/dev/null
echo "Tip: Run 'sudo systemctl isolate multi-user.target' to free ~1.1GB from Ubuntu GDM3/GNOME."

echo "=== [3/4] Running Deterministic CUDA Benchmark ($MODEL @ num_ctx=$CTX) ==="
curl -sS http://127.0.0.1:11434/api/generate -d "{
  \"model\": \"$MODEL\",
  \"prompt\": \"/no_think Summarize 3 sensor anomalies from a warehouse AMR robot in JSON format.\",
  \"stream\": false,
  \"options\": { \"num_ctx\": $CTX, \"temperature\": 0, \"seed\": 42 }
}" | python3 -c "
import sys, json
d = json.load(sys.stdin)
ec = d.get('eval_count', 0)
ed = d.get('eval_duration', 1) / 1e9
print(f'Jetson CUDA Decode Rate: {ec/ed:.2f} tokens/sec ({ec} tokens)')
"

echo "=== [4/4] Active GPU Memory & Thermal Headroom ==="
ollama ps
cat /sys/devices/virtual/thermal/thermal_zone0/temp 2>/dev/null | awk '{printf "SoC Temp: %.1f C\n", $1/1000}' || true
