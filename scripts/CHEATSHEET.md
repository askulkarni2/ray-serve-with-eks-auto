# 📋 Ray Service Cheat Sheet

Quick reference for common commands and operations.

## 🚀 Deployment

```bash
# Full deployment
./scripts/deploy-ray-service.sh

# Monitor deployment
./scripts/monitor-deployment.sh

# Check status
./scripts/check-deployment-status.sh
```

---

## 🔍 Monitoring

```bash
# View Ray dashboard
./scripts/view-ray-dashboard.sh

# Check GPU utilization
./scripts/check-gpu-utilization.sh

# Get all pods
kubectl get pods -l ray.io/cluster=vllm-serve

# Get nodes
kubectl get nodes -o wide

# Get node pools
kubectl get nodepool
```

---

## 🧪 Testing

```bash
# Test inference (default)
./scripts/test-inference.sh

# Test with custom prompt
./scripts/test-inference.sh "Your prompt here" 200

# Direct curl test
kubectl run test --rm -it --restart=Never --image=curlimages/curl:latest -- \
  curl -X POST http://vllm-serve-head-svc:8000/VLLMDeployment \
  -H "Content-Type: application/json" \
  -d '{"prompt": "Hello", "max_tokens": 50}'
```

---

## 📊 Ray Commands

```bash
# Get head pod name
HEAD_POD=$(kubectl get pod -l ray.io/node-type=head -o name)

# Ray status
kubectl exec -it $HEAD_POD -- ray status

# Serve status
kubectl exec -it $HEAD_POD -- serve status

# List actors
kubectl exec -it $HEAD_POD -- ray list actors

# Dashboard URL
kubectl exec -it $HEAD_POD -- ray dashboard
```

---

## 🎮 GPU Commands

```bash
# Get worker pod name
WORKER_POD=$(kubectl get pod -l ray.io/group-name=gpu-workers -o name | head -1)

# Check GPU
kubectl exec -it $WORKER_POD -- nvidia-smi

# GPU utilization
kubectl exec -it $WORKER_POD -- nvidia-smi --query-gpu=utilization.gpu --format=csv

# GPU memory
kubectl exec -it $WORKER_POD -- nvidia-smi --query-gpu=memory.used,memory.total --format=csv
```

---

## 🔧 Troubleshooting

```bash
# View logs (head)
kubectl logs -l ray.io/node-type=head --tail=100

# View logs (workers)
kubectl logs -l ray.io/group-name=gpu-workers --tail=100

# View logs (specific pod)
kubectl logs <pod-name> --tail=100 -f

# Describe pod
kubectl describe pod <pod-name>

# Get events
kubectl get events --sort-by='.lastTimestamp'

# Check PVCs
kubectl get pvc

# Check services
kubectl get svc
```

---

## 🔄 Restart/Scale

```bash
# Restart head pod
kubectl delete pod -l ray.io/node-type=head

# Restart workers
kubectl delete pod -l ray.io/group-name=gpu-workers

# Scale workers (edit replicas in yaml)
kubectl edit rayservice vllm-serve

# Force recreate
kubectl delete rayservice vllm-serve
kubectl apply -f app/ray-serve-vllm-ha.yaml
```

---

## 🛡️ High Availability

```bash
# Check PDBs
kubectl get pdb

# Check Redis
kubectl get pods -l app=redis
kubectl logs -l app=redis

# Check pod distribution
kubectl get pods -o wide -l ray.io/cluster=vllm-serve

# Test failover (delete a worker)
kubectl delete pod <worker-pod-name>
# Watch it recreate
kubectl get pods -w
```

---

## 📦 S3 & Storage

```bash
# List S3 bucket
aws s3 ls s3://qwen-models-$(aws sts get-caller-identity --query Account --output text)/

# Check PVCs
kubectl get pvc

# Check storage classes
kubectl get storageclass

# Test S3 mount
kubectl run s3-test --rm -it --restart=Never \
  --image=amazon/aws-cli \
  --serviceaccount=model-cache-sa -- \
  s3 ls s3://qwen-models-$(aws sts get-caller-identity --query Account --output text)/
```

---

## 🌐 Networking

```bash
# Get services
kubectl get svc -l ray.io/cluster=vllm-serve

# Port forward to dashboard
kubectl port-forward svc/vllm-serve-head-svc 8265:8265

# Port forward to serve endpoint
kubectl port-forward svc/vllm-serve-head-svc 8000:8000

# Test from within cluster
kubectl run test --rm -it --restart=Never --image=curlimages/curl:latest -- \
  curl http://vllm-serve-head-svc:8000/health
```

---

## 🧹 Cleanup

```bash
# Full cleanup (interactive)
./scripts/cleanup.sh

# Delete Ray Service only
kubectl delete -f app/ray-serve-vllm-ha.yaml

# Delete GPU node pool
kubectl delete -f cluster/gpu-nodepool.yaml

# Delete cluster
eksctl delete cluster -f cluster/eks-cluster-config.yaml
```

---

## 📈 Metrics

```bash
# Top pods
kubectl top pods

# Top nodes
kubectl top nodes

# Ray metrics endpoint
kubectl port-forward svc/vllm-serve-head-svc 8080:8080
curl http://localhost:8080/metrics

# Serve metrics
kubectl exec -it $(kubectl get pod -l ray.io/node-type=head -o name) -- \
  curl http://localhost:8000/metrics
```

---

## 🔐 IAM & Permissions

```bash
# List pod identity associations
eksctl get podidentityassociation --cluster my-auto-cluster

# Check service accounts
kubectl get sa

# Describe service account
kubectl describe sa model-cache-sa
```

---

## 💡 Quick Tips

- **Logs not showing?** Add `-f` to follow: `kubectl logs <pod> -f`
- **Pod stuck?** Check events: `kubectl describe pod <pod>`
- **Need more resources?** Edit node pool: `kubectl edit nodepool gpu-nodepool`
- **Model not loading?** Check S3 mount: `kubectl exec -it <pod> -- ls -lah /s3/models/`
- **Slow inference?** Check GPU: `kubectl exec -it <worker-pod> -- nvidia-smi`

---

## 📚 More Resources

- [Full README](../README.md)
- [Quick Start Guide](../QUICKSTART.md)
- [Scripts Documentation](README.md)
- [Deployment Summary](../DEPLOYMENT_SUMMARY.md)
