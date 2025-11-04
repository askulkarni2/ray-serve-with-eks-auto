#!/bin/bash
set -e

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="us-west-2"
CLUSTER_NAME="my-auto-cluster"

echo "=========================================="
echo "🚀 EKS Ray Service Deployment"
echo "=========================================="
echo "Account: $ACCOUNT_ID"
echo "Region: $REGION"
echo "Cluster: $CLUSTER_NAME"
echo ""

# Function to check command status
check_status() {
    if [ $? -eq 0 ]; then
        echo "✅ $1"
    else
        echo "❌ $1 failed"
        exit 1
    fi
}

# Function to wait for pods
wait_for_pods() {
    local label=$1
    local namespace=${2:-default}
    local timeout=${3:-300}
    
    echo "⏳ Waiting for pods with label $label in namespace $namespace..."
    kubectl wait --for=condition=ready pod -l "$label" -n "$namespace" --timeout="${timeout}s" 2>/dev/null || true
}

echo "Step 1: Creating EKS Cluster..."
echo "⏱️  This will take ~15-20 minutes"
eksctl create cluster -f cluster/eks-cluster-config.yaml
check_status "EKS Cluster created"

echo ""
echo "Step 2: Deploying KubeRay Operator..."
helm repo add kuberay https://ray-project.github.io/kuberay-helm/ 2>/dev/null || true
helm repo update
helm install kuberay-operator kuberay/kuberay-operator \
  --version 1.4.2 \
  --create-namespace \
  --namespace kuberay-system \
  --wait
check_status "KubeRay Operator deployed"

echo ""
echo "Step 3: Configuring GPU Node Pool..."
kubectl apply -f cluster/gpu-nodepool.yaml
check_status "GPU Node Pool configured"

echo ""
echo "Step 4: Configuring EBS CSI StorageClass..."
kubectl apply -f cluster/ebs-csi-storageclass.yaml
check_status "EBS CSI StorageClass configured"

echo ""
echo "Step 5: Pushing Ray 2.50.0 Image to ECR..."
kubectl apply -f app/ecr-push-image.yaml
echo "⏳ Waiting for image push to complete..."
kubectl wait --for=condition=complete job/ecr-push-ray-image --timeout=300s 2>/dev/null || kubectl logs job/ecr-push-ray-image
kubectl delete -f app/ecr-push-image.yaml
check_status "Ray image pushed to ECR"

echo ""
echo "Step 6: Installing S3 CSI Driver..."
aws eks create-addon \
  --cluster-name "$CLUSTER_NAME" \
  --addon-name aws-mountpoint-s3-csi-driver \
  --region "$REGION" 2>/dev/null || echo "S3 CSI addon already exists"

echo "⏳ Waiting for S3 CSI addon to be active..."
aws eks wait addon-active \
  --cluster-name "$CLUSTER_NAME" \
  --addon-name aws-mountpoint-s3-csi-driver \
  --region "$REGION"

eksctl create podidentityassociation \
  --cluster "$CLUSTER_NAME" \
  --namespace kube-system \
  --service-account-name s3-csi-driver-sa \
  --permission-policy-arns arn:aws:iam::aws:policy/AmazonS3FullAccess \
  --region "$REGION" 2>/dev/null || echo "Pod identity for S3 CSI already exists"
check_status "S3 CSI Driver installed"

echo ""
echo "Step 7: Creating S3 Bucket for Models..."
BUCKET_NAME="qwen-models-$ACCOUNT_ID"
aws s3 mb "s3://$BUCKET_NAME" --region "$REGION" 2>/dev/null || echo "Bucket already exists"
check_status "S3 bucket created"

echo ""
echo "Step 8: Creating Pod Identity for Model Caching..."
eksctl create podidentityassociation \
  --cluster "$CLUSTER_NAME" \
  --namespace default \
  --service-account-name model-cache-sa \
  --permission-policy-arns arn:aws:iam::aws:policy/AmazonS3FullAccess \
  --region "$REGION" 2>/dev/null || echo "Pod identity for model cache already exists"
check_status "Pod identity created"

echo ""
echo "Step 9: Caching Model to S3..."
kubectl apply -f app/cache-model-job.yaml
echo "⏳ Waiting for model caching to complete (2-3 minutes)..."
kubectl wait --for=condition=complete job/cache-model --timeout=600s 2>/dev/null || kubectl logs job/cache-model --tail=50
check_status "Model cached to S3"

echo ""
echo "Step 10: Deploying Ray Serve with vLLM (High Availability)..."
kubectl apply -f app/ray-serve-vllm-ha.yaml
check_status "Ray Serve HA deployment created"

echo ""
echo "=========================================="
echo "✅ Deployment Complete!"
echo "=========================================="
echo ""
echo "📊 Monitoring deployment progress..."
echo ""
