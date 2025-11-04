#!/bin/bash
set -e

# Get the NLB endpoint
NLB_ENDPOINT=$(kubectl get svc ray-serve-nlb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$NLB_ENDPOINT" ]; then
    echo "❌ Error: NLB endpoint not found."
    exit 1
fi

echo "🎯 Testing endpoint: http://$NLB_ENDPOINT/v1/completions"
echo ""

# Test the endpoint
RESPONSE=$(curl -X POST "http://$NLB_ENDPOINT/v1/completions" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen-0.5b",
    "prompt": "What is machine learning?",
    "max_tokens": 50,
    "temperature": 0.7
  }' \
  -w "\n%{time_total}" \
  -s)

# Parse response and time
BODY=$(echo "$RESPONSE" | sed '$d')
TIME=$(echo "$RESPONSE" | tail -1)

echo "$BODY" | jq .
echo ""
echo "⏱️  Response time: ${TIME}s"

echo ""
echo "✅ Test complete!"
