#!/usr/bin/env bash
# Tinker AI — Reproducible Mac Local LLM Benchmark (Guide #1)
set -euo pipefail

MODEL="qwen2.5:14b-instruct-q4_K_M"
CTX="8192"
API="http://127.0.0.1:11434/api/generate"

echo "=== [1/3] Hardware & Version Snapshot ==="
uname -a
ollama --version || true

echo "=== [2/3] Running Fixed Deterministic Task (seed=42, num_ctx=$CTX) ==="
RESPONSE=$(curl -sS "$API" -d "{
  \"model\": \"$MODEL\",
  \"prompt\": \"Extract three technical risks of running local LLMs with large context windows in strict JSON format with keys: risk, cause, mitigation.\",
  \"stream\": false,
  \"options\": {
    \"num_ctx\": $CTX,
    \"temperature\": 0,
    \"seed\": 42
  }
}")

echo "$RESPONSE" | python3 -c '
import sys, json
data = json.load(sys.stdin)
eval_count = data.get("eval_count", 0)
eval_dur = data.get("eval_duration", 1) / 1e9
prompt_count = data.get("prompt_eval_count", 0)
prompt_dur = data.get("prompt_eval_duration", 1) / 1e9
print(f"Prompt Eval : {prompt_count} tokens ({prompt_count/prompt_dur:.2f} tok/s)")
print(f"Generation  : {eval_count} tokens ({eval_count/eval_dur:.2f} tok/s)")
'

echo "=== [3/3] Active Metal / Unified Memory Footprint ==="
ollama ps
