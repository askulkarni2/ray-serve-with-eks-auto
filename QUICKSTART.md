# ⚡ Quick Start Guide

Get your Ray Serve deployment running in minutes!

## 🚀 One-Command Deployment

```bash
./scripts/deploy-ray-service.sh
```

**Time:** ~45 minutes  
**What it does:** Creates EKS cluster, deploys Ray Serve with vLLM, sets up HA

---

## 📊 Monitor Progress

While deployment is running:

```bash
./scripts/monitor-deployment.sh
```

Or check status anytime:

```bash
./scripts/check-deployment-status.sh
```

---

## 🧪 Test Inference

Once deployed:

```bash
./scripts/test-inference.sh
```

**Expected output:**
```json
{
  "generated_text": " Paris\n\nThe capital of France is Paris...",
  "prompt": "What is the capital of France?",
  "model": "/s3/models/Qwen/Qwen2.5-0.5B-Instruct"
}
```

---

## 🎯 Common Tasks

### View Ray Dashboard
```bash
./scripts/view-ray-dashboard.sh
# Open: http://localhost:8265
```

### Check GPU Usage
```bash
./scripts/check-gpu-utilization.sh
```

### Custom Inference Test
```bash
./scripts/test-inference.sh "Explain quantum computing" 200
```

### Check Ray Status
```bash
kubectl exec -it $(kubectl get pod -l ray.io/node-type=head -o name) -- ray status
```

### Check Serve Status
```bash
kubectl exec -it $(kubectl get pod -l ray.io/node-type=head -o name) -- serve status
```

---

## 🧹 Cleanup

When you're done:

```bash
./scripts/cleanup.sh
```

**⚠️ Warning:** This deletes everything (cluster, S3 bucket, etc.)

---

## 📚 Need More Details?

- **Full Documentation:** [README.md](README.md)
- **Scripts Reference:** [scripts/README.md](scripts/README.md)
- **Monitoring Guide:** [MONITORING_ACCESS.md](MONITORING_ACCESS.md)

---

## 🐛 Troubleshooting

### Pods not starting?
```bash
kubectl get pods --all-namespaces
kubectl describe pod <pod-name>
kubectl logs <pod-name>
```

### GPU nodes not provisioning?
```bash
kubectl get nodepool
kubectl describe nodepool gpu-nodepool
```

### Ray Serve not healthy?
```bash
kubectl exec -it $(kubectl get pod -l ray.io/node-type=head -o name) -- serve status
kubectl logs -l ray.io/cluster=vllm-serve --tail=100
```

### Need to restart?
```bash
kubectl delete pod -l ray.io/cluster=vllm-serve
# Pods will automatically recreate
```

---

## 📋 Prerequisites

Before running deployment:

- ✅ AWS CLI configured (`aws configure`)
- ✅ `eksctl` installed
- ✅ `kubectl` installed
- ✅ `helm` installed
- ✅ AWS account with appropriate permissions

---

## 🎓 What Gets Deployed

1. **EKS Cluster** (1.33 Auto Mode)
2. **4 Nodes** (1 GPU + 3 standard)
3. **KubeRay Operator**
4. **Redis HA** (3 replicas)
5. **Ray Cluster** (1 head + 3 GPU workers)
6. **Ray Serve** with vLLM
7. **Qwen 0.5B Model** (cached in S3)

---

## 💰 Cost Estimate

**Approximate hourly cost:**
- EKS Control Plane: $0.10/hr
- 1x g6.2xlarge (GPU): ~$0.75/hr
- 3x c6a.large (Standard): ~$0.26/hr
- S3 Storage: ~$0.023/GB/month
- **Total: ~$1.11/hr** (~$800/month if running 24/7)

**💡 Tip:** Delete resources when not in use to save costs!

---

**Ready to deploy? Run:** `./scripts/deploy-ray-service.sh`
