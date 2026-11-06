#!/usr/bin/env bash
# Tinker AI — Reproducible Local Vision OCR & Table Extractor (Guide #17)
set -euo pipefail

MODEL="qwen2.5vl:7b"
DPI="150"
API="http://127.0.0.1:11434/api/generate"
INPUT_PDF="${1:-sample-scanned-invoice.pdf}"
OUT_DIR="./ocr-output"

mkdir -p "$OUT_DIR"
echo "=== [1/3] Rasterizing $INPUT_PDF at ${DPI} DPI (Sweet spot for Vision Token budget) ==="
if command -v pdftoppm >/dev/null 2>&1; then
  pdftoppm -png -r "$DPI" "$INPUT_PDF" "$OUT_DIR/page"
else
  echo "[INFO] pdftoppm (poppler) not found; assuming $INPUT_PDF is already an image."
  cp "$INPUT_PDF" "$OUT_DIR/page-1.png"
fi

for IMG in "$OUT_DIR"/page*.png; do
  [ -e "$IMG" ] || continue
  echo "=== [2/3] Extracting Markdown Table from $IMG via $MODEL ==="
  B64_IMG=$(base64 < "$IMG" | tr -d '\n')
  curl -sS "$API" -d "{
    \"model\": \"$MODEL\",
    \"stream\": false,
    \"options\": { \"temperature\": 0, \"num_ctx\": 8192 },
    \"prompt\": \"Transcribe all text and reconstruct any tables into strict GitHub Flavored Markdown. Preserve exact numbers, currency symbols, and column headers. Do not invent missing rows.\",
    \"images\": [\"$B64_IMG\"]
  }" | python3 -c '
import sys, json
res = json.load(sys.stdin)
print(res.get("response", ""))
eval_c = res.get("eval_count", 0)
eval_d = res.get("eval_duration", 1) / 1e9
print(f"
--- [Stats] Generated {eval_c} tokens at {eval_c/eval_d:.2f} tok/s ---")
'
done

echo "=== [3/3] Checking Active Vision Model VRAM Footprint ==="
ollama ps
