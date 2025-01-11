#!/bin/bash
set -euxo pipefail


# Deploy the metrics server Helm chart
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server || true
helm repo update

helm upgrade --install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args[0]="--kubelet-insecure-tls" \
  --set args[1]="--kubelet-preferred-address-types=InternalIP" || true

# Deploy Prometheus and Grafana using the kube-prometheus-stack Helm chart
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts || true
helm repo add grafana https://grafana.github.io/helm-charts || true
helm repo update

helm upgrade --install prometheus prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set grafana.enabled=true \
  --set grafana.adminPassword='admin' \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set defaultRules.create=true \
  --set alertmanager.enabled=false || true

# Ensure Prometheus is scraping metrics from the cluster autoscaler and metrics server
cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app: cluster-autoscaler
  endpoints:
  - port: http
    interval: 30s
EOF

cat <<EOF | kubectl apply -f -
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: metrics-server
  namespace: kube-system
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      k8s-app: metrics-server
  endpoints:
  - port: https
    interval: 30s
    tlsConfig:
      insecureSkipVerify: true
EOF