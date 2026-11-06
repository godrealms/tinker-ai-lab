#!/usr/bin/env bash
# Tinker AI — RAG Embedding Dimension & Multi-Model VRAM Healthcheck (Guide #20)
set -euo pipefail

EMBED="bge-m3:latest"
EXP_DIM="1024"
API="http://127.0.0.1:11434/api/embed"

echo "=== [1/3] Probing Vector Dimension for $EMBED ==="
RESP=$(curl -sS "$API" -d "{
  \"model\": \"$EMBED\",
  \"input\": [\"Tinker AI Lab bilingual RAG verification\", \"本地知识库跨语言向量检索测试\"],
  \"keep_alive\": \"5m\"
}")

echo "$RESP" | python3 -c "
import sys, json, math
data = json.load(sys.stdin)
vecs = data.get('embeddings', [])
if not vecs:
    print('[FAIL] Empty embeddings array returned! Check model tag.')
    sys.exit(1)
dim = len(vecs[0])
exp = int('$EXP_DIM')
status = 'OK' if dim == exp else f'MISMATCH (Expected {exp}, Got {dim} -> Must re-index Vector DB!)'
dot = sum(a*b for a, b in zip(vecs[0], vecs[1]))
norm0 = math.sqrt(sum(a*a for a in vecs[0]))
norm1 = math.sqrt(sum(b*b for b in vecs[1]))
cos = dot / (norm0 * norm1) if (norm0 and norm1) else 0.0
print(f'Vector Dimension : {dim} [{status}]')
print(f'EN-ZH Cosine Sim : {cos:.4f} (Expect > 0.55 for multilingual models like bge-m3)')
"

echo "=== [2/3] Inspecting Co-Loaded Models & VRAM Split ==="
ollama ps

echo "=== [3/3] Checking OLLAMA_MAX_LOADED_MODELS Policy ==="
echo "Tip: Ensure OLLAMA_MAX_LOADED_MODELS>=2 so $EMBED and your Chat LLM do not thrash disk on every RAG query."
