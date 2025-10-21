#!/bin/bash

CLUSTER_NAME="my-auto-cluster"
REGION="us-west-2"

echo "=========================================="
echo "📊 Ray Service Deployment Monitor"
echo "=========================================="
echo ""

# Function to check cluster status
check_cluster() {
    echo "🔍 Checking EKS Cluster Status..."
    STATUS=$(aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGION" --query 'cluster.status' --output text 2>/dev/null || echo "NOT_FOUND")
    echo "   Cluster Status: $STATUS"
    echo ""
}

# Function to check nodes
check_nodes() {
    echo "🖥️  Checking Nodes..."
    kubectl get nodes -o wide 2>/dev/null || echo "   Cluster not accessible yet"
    echo ""
}

# Function to check node pools
check_nodepools() {
    echo "🎯 Checking Node Pools..."
    kubectl get nodepool 2>/dev/null || echo "   Node pools not ready yet"
    echo ""
}

# Function to check pods
check_pods() {
    echo "📦 Checking Pods..."
    echo ""
    echo "   KubeRay Operator:"
    kubectl get pods -n kuberay-system 2>/dev/null || echo "   Not deployed yet"
    echo ""
    echo "   Redis:"
    kubectl get pods -l app=redis 2>/dev/null || echo "   Not deployed yet"
    echo ""
    echo "   Ray Cluster:"
    kubectl get pods -l ray.io/cluster=vllm-serve 2>/dev/null || echo "   Not deployed yet"
    echo ""
}

# Function to check PDBs
check_pdbs() {
    echo "🛡️  Checking Pod Disruption Budgets..."
    kubectl get pdb 2>/dev/null || echo "   Not configured yet"
    echo ""
}

# Function to check services
check_services() {
    echo "🌐 Checking Services..."
    kubectl get svc -l ray.io/cluster=vllm-serve 2>/dev/null || echo "   Not deployed yet"
    echo ""
}

# Function to check Ray Serve status
check_ray_serve() {
    echo "🎯 Checking Ray Serve Status..."
    HEAD_POD=$(kubectl get pod -l ray.io/node-type=head,ray.io/cluster=vllm-serve -o name 2>/dev/null | head -1)
    if [ -n "$HEAD_POD" ]; then
        kubectl exec -it "$HEAD_POD" -- serve status 2>/dev/null || echo "   Ray Serve not ready yet"
    else
        echo "   Head pod not found"
    fi
    echo ""
}

# Function to check GPU nodes
check_gpu() {
    echo "🎮 Checking GPU Nodes..."
    WORKER_POD=$(kubectl get pod -l ray.io/group-name=gpu-workers -o name 2>/dev/null | head -1)
    if [ -n "$WORKER_POD" ]; then
        kubectl exec -it "$WORKER_POD" -- nvidia-smi --query-gpu=index,name,utilization.gpu,memory.used,memory.total --format=csv 2>/dev/null || echo "   GPU workers not ready yet"
    else
        echo "   GPU worker pods not found"
    fi
    echo ""
}

# Main monitoring loop
while true; do
    clear
    echo "=========================================="
    echo "📊 Ray Service Deployment Monitor"
    echo "=========================================="
    echo "Time: $(date)"
    echo ""
    
    check_cluster
    check_nodes
    check_nodepools
    check_pods
    check_pdbs
    check_services
    check_ray_serve
    check_gpu
    
    echo "=========================================="
    echo "Press Ctrl+C to exit monitoring"
    echo "Refreshing in 30 seconds..."
    echo "=========================================="
    
    sleep 30
done
