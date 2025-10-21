#!/bin/bash
# Test Ray Serve inference endpoint

set -e

PROMPT="${1:-What is the capital of France?}"
MAX_TOKENS="${2:-100}"

echo "=========================================="
echo "🧪 Testing Ray Serve Inference"
echo "=========================================="
echo "Prompt: $PROMPT"
echo "Max Tokens: $MAX_TOKENS"
echo ""

kubectl run test-inference --rm -it --restart=Never \
  --image=curlimages/curl:latest -- \
  curl -s -X POST http://vllm-serve-head-svc:8000/VLLMDeployment \
  -H "Content-Type: application/json" \
  -d "{\"prompt\": \"$PROMPT\", \"max_tokens\": $MAX_TOKENS}" | jq .

echo ""
echo "✅ Test complete!"
