#!/usr/bin/env bash
# Tinker AI — Concurrent Local LLM Throughput & Queue Latency Probe
set -euo pipefail

ENDPOINT="http://127.0.0.1:11434/v1/chat/completions"
MODEL="qwen2.5:7b"
WORKERS="4"

echo "=== Firing $WORKERS Parallel Requests against $MODEL ($ENDPOINT) ==="
START_TS=$(python3 -c 'import time; print(time.time())')

seq 1 "$WORKERS" | xargs -I{} -P "$WORKERS" bash -c '
  REQ_START=$(python3 -c "import time; print(time.time())")
  RESP=$(curl -sS "'"$ENDPOINT"'" -H "Content-Type: application/json" -d "{
    \"model\": \"'"$MODEL"'\",
    \"temperature\": 0,
    \"max_tokens\": 160,
    \"messages\": [{\"role\": \"user\", \"content\": \"Worker #{}: List 3 key differences between continuous batching and static request queues in 80 words.\"}]
  }")
  REQ_END=$(python3 -c "import time; print(time.time())")
  python3 -c "
import json, sys
d = json.loads(sys.argv[1])
toks = d.get("usage", {}).get("completion_tokens", 0)
dur = float(sys.argv[3]) - float(sys.argv[2])
print(f"[Worker #{}] Completed in {dur:.2f}s | {toks} tokens ({toks/max(0.01,dur):.1f} tok/s)")
" "$RESP" "$REQ_START" "$REQ_END"
'

END_TS=$(python3 -c 'import time; print(time.time())')
python3 -c "print(f'=== Total Wall-Clock Duration for $WORKERS parallel requests: {float($END_TS)-float($START_TS):.2f}s ===')"
