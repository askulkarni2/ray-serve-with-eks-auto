#!/bin/bash
set -e

# Get the NLB endpoint
NLB_ENDPOINT=$(kubectl get svc ray-serve-nlb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

if [ -z "$NLB_ENDPOINT" ]; then
    echo "❌ Error: NLB endpoint not found. Make sure ray-serve-nlb service is deployed."
    echo "Run: kubectl apply -f app/ray-serve-nlb.yaml"
    exit 1
fi

echo "🎯 Target endpoint: http://$NLB_ENDPOINT"
echo "🚀 Starting K6 load test..."
echo ""

# Run K6 in Docker with the NLB endpoint
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
docker run --rm -i \
    -e TARGET_URL="http://$NLB_ENDPOINT" \
    -v "$SCRIPT_DIR:/scripts" \
    grafana/k6:latest \
    run /scripts/k6-load-test.js

echo ""
echo "✅ Load test complete!"
