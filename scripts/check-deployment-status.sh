#!/bin/bash

echo "=========================================="
echo "📊 Ray Service Deployment Status"
echo "=========================================="
echo ""

echo "🖥️  Nodes:"
kubectl get nodes -o wide
echo ""

echo "📦 Pods:"
kubectl get pods -l ray.io/cluster=vllm-serve -o wide
echo ""
kubectl get pods -l app=redis
echo ""

echo "🎯 Ray Cluster Status:"
kubectl exec -it vllm-serve-raycluster-bhr9w-head-h8xw8 -- ray status 2>/dev/null || echo "Head pod not ready"
echo ""

echo "🚀 Ray Serve Status:"
kubectl exec -it vllm-serve-raycluster-bhr9w-head-h8xw8 -- serve status 2>/dev/null || echo "Serve not ready"
echo ""

echo "🛡️  Pod Disruption Budgets:"
kubectl get pdb
echo ""

echo "🌐 Services:"
kubectl get svc -l ray.io/cluster=vllm-serve
echo ""

echo "📊 RayService Status:"
kubectl get rayservice vllm-serve
echo ""

echo "=========================================="
echo "To test inference once ready, run:"
echo "kubectl run test-inference --rm -it --restart=Never --image=curlimages/curl:latest -- curl -X POST http://vllm-serve-head-svc:8000/VLLMDeployment -H 'Content-Type: application/json' -d '{\"prompt\": \"What is the capital of France?\", \"max_tokens\": 100}'"
echo "=========================================="
