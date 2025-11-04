#!/bin/bash
set -e

echo "🔄 Updating Ray Service to use ElastiCache Redis..."
echo ""

# Get ElastiCache endpoint
echo "📡 Getting ElastiCache endpoint..."
REDIS_ENDPOINT=$(kubectl get replicationgroup ray-redis-cluster -n default -o jsonpath='{.status.configurationEndpoint.address}' 2>/dev/null)
REDIS_PORT=$(kubectl get replicationgroup ray-redis-cluster -n default -o jsonpath='{.status.configurationEndpoint.port}' 2>/dev/null)

if [ -z "$REDIS_ENDPOINT" ]; then
    echo "❌ Error: ElastiCache cluster not found or not ready"
    echo "   Run: kubectl get replicationgroup ray-redis-cluster -n default"
    exit 1
fi

REDIS_ADDRESS="${REDIS_ENDPOINT}:${REDIS_PORT}"
echo "   Redis Address: $REDIS_ADDRESS"
echo ""

# Get AWS account ID for image substitution
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
export AWS_ACCOUNT_ID

# Update Ray Service configuration
echo "📝 Updating Ray Service configuration..."

# Create temporary file with updated config
TEMP_FILE=$(mktemp)
envsubst < app/ray-serve-vllm-ha.yaml | \
    sed "s|redis-0.redis-svc.default.svc.cluster.local:6379|${REDIS_ADDRESS}|g" > "$TEMP_FILE"

# Show the diff
echo ""
echo "📋 Changes to be applied:"
echo "   Old: redis-0.redis-svc.default.svc.cluster.local:6379"
echo "   New: $REDIS_ADDRESS"
echo ""

# Apply the updated configuration
echo "🚀 Applying updated Ray Service..."
kubectl apply -f "$TEMP_FILE"

rm -f "$TEMP_FILE"

echo ""
echo "✅ Ray Service updated to use ElastiCache!"
echo ""
echo "⏳ Waiting for Ray Service to restart..."
kubectl rollout status rayservice vllm-serve -n default --timeout=10m

echo ""
echo "🔍 Verifying Ray cluster is using ElastiCache..."
kubectl get rayservice vllm-serve -n default -o yaml | grep -A 2 "RAY_REDIS_ADDRESS"

echo ""
echo "✅ Update complete!"
echo ""
echo "📊 You can now delete the in-cluster Redis StatefulSet:"
echo "   kubectl delete statefulset redis -n default"
echo "   kubectl delete service redis-svc -n default"
echo "   kubectl delete pdb redis-pdb -n default"
