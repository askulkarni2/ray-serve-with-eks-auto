#!/bin/bash
set -e

echo "🔄 Upgrading Prometheus stack with persistent storage..."
echo ""

# Check if helm release exists
if ! helm list -n monitoring | grep -q prometheus; then
    echo "❌ Error: Prometheus helm release not found in monitoring namespace"
    exit 1
fi

echo "📊 Current Prometheus storage configuration:"
kubectl get statefulset prometheus-prometheus-kube-prometheus-prometheus -n monitoring -o jsonpath='{.spec.volumeClaimTemplates}' | jq . || echo "No PVCs configured"
echo ""

echo "📈 Current Grafana storage configuration:"
kubectl get deployment prometheus-grafana -n monitoring -o jsonpath='{.spec.template.spec.volumes[?(@.name=="storage")]}' | jq .
echo ""

echo "⚠️  WARNING: This will restart Prometheus and Grafana pods"
echo "   Existing data in emptyDir volumes will be lost"
echo "   Future data will be persisted to EBS volumes"
echo ""
read -p "Continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "❌ Upgrade cancelled"
    exit 0
fi

echo ""
echo "🚀 Applying persistent storage configuration..."

# Upgrade the helm release
helm upgrade prometheus prometheus-community/kube-prometheus-stack \
    -n monitoring \
    -f monitoring/prometheus-persistent-values.yaml \
    --wait \
    --timeout 10m

echo ""
echo "✅ Upgrade complete!"
echo ""
echo "📦 Checking PVCs..."
kubectl get pvc -n monitoring

echo ""
echo "🔍 Verifying pods are running..."
kubectl get pods -n monitoring -l app.kubernetes.io/name=prometheus
kubectl get pods -n monitoring -l app.kubernetes.io/name=grafana

echo ""
echo "✅ Monitoring stack now has persistent storage!"
echo ""
echo "📊 Prometheus data will be retained for 30 days (50GB volume)"
echo "📈 Grafana dashboards and settings will persist across restarts (10GB volume)"
echo "🔔 AlertManager data will be retained (10GB volume)"
