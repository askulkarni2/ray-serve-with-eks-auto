# 📊 Monitoring Stack Access Guide

## ✅ Deployed Components

### Prometheus & Grafana Stack
- **Prometheus:** Metrics collection and storage
- **Grafana:** Visualization dashboards
- **Alertmanager:** Alert management
- **Node Exporter:** Node-level metrics
- **Kube State Metrics:** Kubernetes object metrics

### GPU Monitoring
- **DCGM Exporter:** NVIDIA GPU metrics

### Ray Serve Monitoring
- **ServiceMonitors:** Ray head and worker metrics
- **PodMonitor:** Ray Serve application metrics

## 🔐 Access Grafana

### Port Forward to Grafana
```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

Then open: http://localhost:3000

### Login Credentials
- **Username:** `admin`
- **Password:** `prom-operator`

## 📈 Available Dashboards

### Pre-configured Dashboards
1. **Ray Serve Enhanced Dashboard** - Ray Serve metrics and performance
2. **NVIDIA GPU Dashboard** - GPU utilization, memory, temperature, power

### Built-in Dashboards
- Kubernetes / Compute Resources / Cluster
- Kubernetes / Compute Resources / Namespace (Pods)
- Kubernetes / Compute Resources / Node (Pods)
- Node Exporter / Nodes

## 🎯 Key Metrics to Monitor

### Ray Serve Metrics
- `ray_serve_num_http_requests` - Total HTTP requests
- `ray_serve_request_latency_ms` - Request latency
- `ray_serve_deployment_replica_healthy` - Healthy replicas
- `ray_serve_deployment_queued_queries` - Queued requests
- `ray_serve_num_deployment_http_error_requests` - Failed requests

### GPU Metrics (DCGM)
- `DCGM_FI_DEV_GPU_UTIL` - GPU utilization %
- `DCGM_FI_DEV_FB_USED` - GPU memory used
- `DCGM_FI_DEV_GPU_TEMP` - GPU temperature
- `DCGM_FI_DEV_POWER_USAGE` - Power consumption

### vLLM Metrics
- `vllm:num_requests_running` - Active requests
- `vllm:num_requests_waiting` - Queued requests
- `vllm:gpu_cache_usage_perc` - KV cache usage
- `vllm:time_to_first_token_seconds` - TTFT latency
- `vllm:time_per_output_token_seconds` - Token generation speed

## 🔍 Prometheus Queries

### Check Ray Serve Status
```promql
ray_serve_deployment_replica_healthy
```

### GPU Utilization
```promql
DCGM_FI_DEV_GPU_UTIL
```

### Request Rate (last 5 minutes)
```promql
rate(ray_serve_num_http_requests[5m])
```

### P95 Latency
```promql
histogram_quantile(0.95, rate(ray_serve_request_latency_ms_bucket[5m]))
```

## 📊 Access Prometheus UI

```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090
```

Then open: http://localhost:9090

## 🚨 Alerting

### View Alerts in Alertmanager
```bash
kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-alertmanager 9093:9093
```

Then open: http://localhost:9093

## 🔧 Troubleshooting

### Check Prometheus Targets
1. Port forward to Prometheus: `kubectl port-forward -n monitoring svc/prometheus-kube-prometheus-prometheus 9090:9090`
2. Open http://localhost:9090/targets
3. Look for `ray-head-monitor`, `ray-worker-monitor`, and `dcgm-exporter`

### Check ServiceMonitors
```bash
kubectl get servicemonitor -n default
kubectl describe servicemonitor ray-head-monitor -n default
```

### Check DCGM Exporter
```bash
kubectl get pods -n monitoring -l app.kubernetes.io/name=dcgm-exporter
kubectl logs -n monitoring -l app.kubernetes.io/name=dcgm-exporter
```

### Verify Metrics Endpoint
```bash
# Ray head metrics
kubectl port-forward svc/vllm-serve-head-svc 8080:8080
curl http://localhost:8080/metrics

# DCGM metrics
kubectl port-forward -n monitoring $(kubectl get pod -n monitoring -l app.kubernetes.io/name=dcgm-exporter -o name) 9400:9400
curl http://localhost:9400/metrics
```

## 📦 Monitoring Stack Status

### Check All Monitoring Pods
```bash
kubectl get pods -n monitoring
```

### Check Services
```bash
kubectl get svc -n monitoring
```

### Check ConfigMaps (Dashboards)
```bash
kubectl get configmap -n monitoring | grep dashboard
```

## 🎨 Custom Dashboards

To add custom dashboards:
1. Create a ConfigMap with label `grafana_dashboard: "1"`
2. Place in the `monitoring` namespace
3. Grafana will auto-import it

Example:
```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: my-custom-dashboard
  namespace: monitoring
  labels:
    grafana_dashboard: "1"
data:
  my-dashboard.json: |
    {
      "dashboard": { ... }
    }
```

## 🔄 Restart Grafana

If dashboards don't appear:
```bash
kubectl rollout restart deployment -n monitoring prometheus-grafana
```

---

**Monitoring stack is ready! 📊**
