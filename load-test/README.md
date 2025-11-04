# K6 Load Testing

Run load tests against the Ray Serve deployment either locally or in Kubernetes.

## 🖥️ Local Execution (Recommended)

### Prerequisites
- Docker installed and running
- kubectl configured with access to the cluster
- NLB service deployed (`kubectl apply -f app/ray-serve-nlb.yaml`)

### Quick Start

```bash
cd load-test
./run-local.sh
```

This will:
1. Automatically get the NLB endpoint from Kubernetes
2. Run K6 in a Docker container
3. Execute the load test against the external endpoint
4. Display results in your terminal

### Custom Load Test

You can also run with custom parameters:

```bash
# Get the NLB endpoint
NLB_ENDPOINT=$(kubectl get svc ray-serve-nlb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

# Run with custom duration and VUs
docker run --rm -i \
    -e TARGET_URL="http://$NLB_ENDPOINT" \
    -v "$(pwd)/k6-load-test.js:/scripts/k6-load-test.js" \
    grafana/k6:latest \
    run --vus 10 --duration 5m /scripts/k6-load-test.js
```

### Build Custom Image (Optional)

```bash
cd load-test
docker build -t k6-ray-load-test .

# Run it
NLB_ENDPOINT=$(kubectl get svc ray-serve-nlb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
docker run --rm -e TARGET_URL="http://$NLB_ENDPOINT" k6-ray-load-test
```

## ☸️ Kubernetes Execution

For running the load test inside the cluster:

```bash
# Deploy the load test
kubectl apply -f k6-deployment.yaml
kubectl apply -f k6-job.yaml

# Watch progress
kubectl logs -f job/k6-load-test

# Cleanup
kubectl delete job k6-load-test
kubectl delete deployment k6-load-test
kubectl delete configmap k6-script
kubectl delete svc k6-web-ui
```

## 📊 Load Test Configuration

Default configuration (in `k6-load-test.js`):
- **Ramp up:** 2 minutes to 15 VUs
- **Sustained load:** 55 minutes at 15 VUs
- **Cool down:** 3 minutes to 0 VUs
- **Total duration:** 60 minutes

### Modify Load Profile

Edit `k6-load-test.js` and change the `options.stages`:

```javascript
export const options = {
  stages: [
    { duration: '1m', target: 5 },   // Ramp up to 5 VUs
    { duration: '5m', target: 5 },   // Hold at 5 VUs
    { duration: '1m', target: 0 },   // Ramp down
  ],
};
```

## 🎯 Metrics

The load test tracks:
- **HTTP request duration** (p95 < 10s threshold)
- **Error rate** (< 10% threshold)
- **Inference latency** (custom metric)
- **Request rate**
- **Success rate**

## 🔍 Monitoring

While the load test runs, monitor in Grafana:

```bash
kubectl port-forward -n monitoring svc/prometheus-grafana 3000:80
```

Open http://localhost:3000 and check:
- Ray Serve Enhanced Dashboard
- GPU Metrics Dashboard

## 💡 Tips

1. **Start small:** Test with 1-2 VUs first to verify everything works
2. **Monitor GPU:** Watch GPU utilization to ensure you're not overloading
3. **Check logs:** Monitor Ray worker logs for errors
4. **Adjust think time:** Modify `sleep()` in the script to control request rate

## 🐛 Troubleshooting

**DNS resolution fails:**
```bash
# Wait a few minutes for NLB DNS to propagate
sleep 120
./run-local.sh
```

**Connection timeout:**
```bash
# Verify NLB is accessible
NLB_ENDPOINT=$(kubectl get svc ray-serve-nlb -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -v http://$NLB_ENDPOINT/VLLMDeployment \
  -H "Content-Type: application/json" \
  -d '{"prompt": "test", "max_tokens": 10}'
```

**High error rate:**
- Check Ray Serve status: `kubectl exec -it $(kubectl get pod -l ray.io/node-type=head -o name) -- serve status`
- Check worker logs: `kubectl logs -l ray.io/group=gpu-workers --tail=100`
- Reduce VUs or increase think time
