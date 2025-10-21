#!/bin/bash
# Port-forward to Ray dashboard

echo "=========================================="
echo "📊 Ray Dashboard Port Forward"
echo "=========================================="
echo ""

HEAD_POD=$(kubectl get pod -l ray.io/node-type=head -o name 2>/dev/null | head -1)

if [ -z "$HEAD_POD" ]; then
    echo "❌ Ray head pod not found"
    exit 1
fi

echo "✅ Found head pod: $HEAD_POD"
echo ""
echo "🌐 Opening Ray Dashboard..."
echo "   URL: http://localhost:8265"
echo ""
echo "Press Ctrl+C to stop port forwarding"
echo "=========================================="
echo ""

kubectl port-forward $HEAD_POD 8265:8265
