# 🛠️ Helper Scripts

This directory contains utility scripts for managing the Ray Service deployment.

## 📋 Available Scripts

### Deployment

#### `deploy-ray-service.sh`
Complete end-to-end deployment script that:
- Creates EKS cluster
- Installs KubeRay operator
- Configures GPU node pool
- Sets up S3 CSI driver
- Caches model to S3
- Deploys Ray Serve with HA

**Usage:**
```bash
./scripts/deploy-ray-service.sh
```

**Time:** ~45 minutes

---

### Monitoring

#### `check-deployment-status.sh`
Quick status check of all components:
- Nodes and node pools
- Ray cluster status
- Ray Serve status
- Pod Disruption Budgets
- Services

**Usage:**
```bash
./scripts/check-deployment-status.sh
```

#### `monitor-deployment.sh`
Continuous monitoring with auto-refresh every 30 seconds.

**Usage:**
```bash
./scripts/monitor-deployment.sh
```

Press `Ctrl+C` to exit.

#### `check-gpu-utilization.sh`
Check GPU utilization on all Ray worker pods.

**Usage:**
```bash
./scripts/check-gpu-utilization.sh
```

#### `view-ray-dashboard.sh`
Port-forward to Ray dashboard for web UI access.

**Usage:**
```bash
./scripts/view-ray-dashboard.sh
```

Then open: http://localhost:8265

---

### Testing

#### `test-inference.sh`
Test the Ray Serve inference endpoint.

**Usage:**
```bash
# Default test
./scripts/test-inference.sh

# Custom prompt
./scripts/test-inference.sh "Explain quantum computing" 200

# Arguments: <prompt> <max_tokens>
```

**Example Output:**
```json
{
  "generated_text": " Paris\n\nThe capital of France is Paris...",
  "prompt": "What is the capital of France?",
  "model": "/s3/models/Qwen/Qwen2.5-0.5B-Instruct"
}
```

---

### Cleanup

#### `cleanup.sh`
Complete cleanup of all resources:
- Ray Service and pods
- GPU node pool
- S3 bucket
- EKS cluster

**Usage:**
```bash
./scripts/cleanup.sh
```

**⚠️ Warning:** This is destructive and will prompt for confirmation.

---

## 🚀 Quick Start Workflow

1. **Deploy everything:**
   ```bash
   ./scripts/deploy-ray-service.sh
   ```

2. **Monitor progress:**
   ```bash
   ./scripts/monitor-deployment.sh
   ```

3. **Check status:**
   ```bash
   ./scripts/check-deployment-status.sh
   ```

4. **Test inference:**
   ```bash
   ./scripts/test-inference.sh
   ```

5. **View dashboard:**
   ```bash
   ./scripts/view-ray-dashboard.sh
   ```

6. **Check GPU usage:**
   ```bash
   ./scripts/check-gpu-utilization.sh
   ```

7. **Cleanup (when done):**
   ```bash
   ./scripts/cleanup.sh
   ```

---

## 📝 Notes

- All scripts assume you're running from the project root directory
- Scripts require `kubectl`, `aws`, and `eksctl` CLI tools
- Make scripts executable: `chmod +x scripts/*.sh`
- Check logs if any script fails: `kubectl logs <pod-name>`

---

## 🔧 Troubleshooting

If a script fails:

1. **Check cluster access:**
   ```bash
   kubectl get nodes
   ```

2. **Check pod status:**
   ```bash
   kubectl get pods --all-namespaces
   ```

3. **View logs:**
   ```bash
   kubectl logs -l ray.io/cluster=vllm-serve --tail=100
   ```

4. **Check Ray status:**
   ```bash
   kubectl exec -it $(kubectl get pod -l ray.io/node-type=head -o name) -- ray status
   ```
