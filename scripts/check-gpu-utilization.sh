#!/bin/bash
# Check GPU utilization on Ray workers

echo "=========================================="
echo "🎮 GPU Utilization"
echo "=========================================="
echo ""

WORKER_PODS=$(kubectl get pods -l ray.io/group-name=gpu-workers -o name 2>/dev/null)

if [ -z "$WORKER_PODS" ]; then
    echo "❌ No GPU worker pods found"
    exit 1
fi

for POD in $WORKER_PODS; do
    POD_NAME=$(echo $POD | cut -d'/' -f2)
    echo "📊 $POD_NAME:"
    echo "----------------------------------------"
    kubectl exec -it $POD -- nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total,temperature.gpu --format=csv 2>/dev/null || echo "Failed to get GPU info"
    echo ""
done

echo "=========================================="
