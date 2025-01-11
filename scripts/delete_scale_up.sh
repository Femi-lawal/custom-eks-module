#!/bin/bash
set -euxo pipefail

# Delete the metrics server Helm release
helm uninstall metrics-server --namespace kube-system || true

# Delete Prometheus and Grafana Helm release
helm uninstall prometheus --namespace monitoring || true

# Delete the ServiceMonitor for cluster autoscaler
kubectl delete servicemonitor cluster-autoscaler --namespace kube-system --ignore-not-found=true

# Delete the ServiceMonitor for metrics server
kubectl delete servicemonitor metrics-server --namespace kube-system --ignore-not-found=true

# Delete the monitoring namespace
kubectl delete namespace monitoring --ignore-not-found=true