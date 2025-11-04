#!/bin/bash
set -e

echo "=========================================="
echo "🚀 K6 Load Test - Local Execution"
echo "=========================================="
echo ""

# Get NLB endpoint
echo "📡 Fetching NLB endpoint..."
NLB_ENDPOINT=$(kubectl get svc ray-serve-nlb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null)

if [ -z "$NLB_ENDPOINT" ]; then
    echo "❌ Error: Could not get NLB endpoint"
    echo "Make sure ray-serve-nlb service is deployed and has an external IP"
    exit 1
fi

TARGET_URL="http://${NLB_ENDPOINT}"
echo "✅ Target URL: $TARGET_URL"
echo ""

# Test connectivity
echo "🔍 Testing connectivity..."
if curl -s --max-time 5 "${TARGET_URL}" > /dev/null 2>&1; then
    echo "✅ Endpoint is reachable"
else
    echo "⚠️  Warning: Endpoint may not be ready yet, but continuing..."
fi
echo ""

# Check if Docker/Finch is running
if command -v docker > /dev/null 2>&1; then
    CONTAINER_CMD="docker"
elif command -v finch > /dev/null 2>&1; then
    CONTAINER_CMD="finch"
else
    echo "❌ Error: Neither Docker nor Finch is installed"
    exit 1
fi

echo "🐳 Starting K6 load test with ${CONTAINER_CMD}..."
echo ""
echo "📊 Test Configuration:"
echo "   Duration: 60 minutes"
echo "   Stages:"
echo "     0-2min:  Ramp up to 15 VUs"
echo "     2-57min: Hold at 15 VUs"
echo "     57-60min: Ramp down to 0"
echo ""
echo "⏱️  Starting test at $(date)"
echo "=========================================="
echo ""

# Run K6 with Docker/Finch
${CONTAINER_CMD} run --rm -i \
  -e TARGET_URL="${TARGET_URL}" \
  grafana/k6:latest run - < load-test/k6-load-test.js

echo ""
echo "=========================================="
echo "✅ Load test completed at $(date)"
echo "=========================================="
