#!/usr/bin/env bash
# Tinker AI — Local Document Q&A (RAG) Sample Corpus & Citation Check (Guide #4)
set -euo pipefail

CHAT_MODEL="qwen2.5:14b-instruct-q4_K_M"
EMBED_MODEL="bge-m3"
CTX="8192"

cat << 'EOF' > ./sample-homelab-sla-policy.md
# Tinker HomeLab Storage & Backup Policy (Rev 2026.10)

## Section 3.1: RPO & Snapshot Frequency
All SQLite application databases (webui.db, n8n.sqlite) MUST be snapshotted every 6 hours using zstd compression. Maximum Recovery Point Objective (RPO) is strictly 6 hours.

## Section 3.2: Cold Storage Retention Trap
Daily archives are retained on local NVMe for 14 days, and replicated to offline NAS cold storage for 90 days. NOTE: Temporary cache directories (/root/.ollama/models/blobs) are EXCLUDED from daily tar snapshots.

## Section 4.4: Emergency Rollback Threshold
If post-upgrade p95 token latency degrades by more than 28% at num_ctx=8192, operators must revert to the previous pinned container digest within 15 minutes.
EOF

echo "=== Generated ./sample-homelab-sla-policy.md ==="
echo "=== Testing Citation Accuracy & Context Retention on $CHAT_MODEL (num_ctx=$CTX) ==="

DOC_CONTENT=$(cat ./sample-homelab-sla-policy.md)
curl -sS http://127.0.0.1:11434/api/generate -d "{
  \"model\": \"$CHAT_MODEL\",
  \"stream\": false,
  \"options\": { \"num_ctx\": $CTX, \"temperature\": 0 },
  \"prompt\": $(python3 -c 'import json,sys; print(json.dumps("Answer ONLY using the document below and cite the exact Section number. Question: Are Ollama model blobs included in daily tar snapshots, and what is the p95 latency rollback threshold?

Document:
" + sys.stdin.read()))' < ./sample-homelab-sla-policy.md)
}" | python3 -c 'import sys,json; print(json.load(sys.stdin).get("response",""))'
