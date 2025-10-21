#!/bin/bash
# Cleanup all deployed resources

set -e

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
CLUSTER_NAME="my-auto-cluster"
REGION="us-west-2"
BUCKET_NAME="qwen-models-$ACCOUNT_ID"

echo "=========================================="
echo "🧹 Cleanup Ray Service Deployment"
echo "=========================================="
echo ""
echo "⚠️  WARNING: This will delete:"
echo "   - Ray Service and all pods"
echo "   - Redis StatefulSet"
echo "   - GPU node pool"
echo "   - S3 bucket: $BUCKET_NAME"
echo "   - EKS cluster: $CLUSTER_NAME"
echo ""
read -p "Are you sure? (yes/no): " CONFIRM

if [ "$CONFIRM" != "yes" ]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Step 1: Deleting Ray Service..."
kubectl delete -f app/ray-serve-vllm-ha.yaml 2>/dev/null || echo "Ray Service not found"

echo ""
echo "Step 2: Deleting GPU node pool..."
kubectl delete -f cluster/gpu-nodepool.yaml 2>/dev/null || echo "GPU node pool not found"

echo ""
echo "Step 3: Waiting for nodes to terminate..."
sleep 30

echo ""
echo "Step 4: Deleting S3 bucket..."
aws s3 rm "s3://$BUCKET_NAME" --recursive 2>/dev/null || echo "Bucket already empty"
aws s3 rb "s3://$BUCKET_NAME" 2>/dev/null || echo "Bucket already deleted"

echo ""
echo "Step 5: Deleting EKS cluster..."
eksctl delete cluster -f cluster/eks-cluster-config.yaml --wait

echo ""
echo "=========================================="
echo "✅ Cleanup Complete!"
echo "=========================================="
