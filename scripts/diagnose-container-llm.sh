#!/usr/bin/env bash
# Tinker AI Troubleshooting — Container <-> Host Local Model Diagnostic (Guide #6)
set -euo pipefail

PORT="11434"
CONTAINER="tinker-open-webui"

echo "=== Step 1: Check Host Listening Address on Port $PORT ==="
if lsof -nP -iTCP:"$PORT" -sTCP:LISTEN 2>/dev/null | grep -q "127.0.0.1:$PORT"; then
  echo "[FAIL] Host service is bound ONLY to 127.0.0.1:$PORT."
  echo "  -> Fix: Set OLLAMA_HOST=0.0.0.0:$PORT on the host service and restart."
else
  echo "[OK] Host service is not restricted to loopback only."
fi

echo "=== Step 2: Probe host.docker.internal from inside $CONTAINER ==="
docker exec "$CONTAINER" sh -c "getent hosts host.docker.internal && wget -qO- --timeout=5 http://host.docker.internal:$PORT/api/version" \
  && echo "[OK] Container reached host model API successfully!" \
  || echo "[FAIL] Container cannot reach host.docker.internal:$PORT. Ensure extra_hosts: ['host.docker.internal:host-gateway'] is set."
