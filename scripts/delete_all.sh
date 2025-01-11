#!/bin/bash
set -euxo pipefail

# Retrieve Terraform outputs
REGION=$(terraform output -raw aws_region)
CLUSTER_NAME=$(terraform output -raw cluster_name)

# Update kubeconfig
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Delete the cluster autoscaler Helm release
helm uninstall cluster-autoscaler --namespace kube-system || true

# Delete the metrics server Helm release
helm uninstall metrics-server --namespace kube-system || true

# Delete Prometheus and Grafana Helm release
helm uninstall prometheus --namespace monitoring || true

# Delete the service account for cluster autoscaler
kubectl delete serviceaccount cluster-autoscaler --namespace kube-system --ignore-not-found=true

# Check if ServiceMonitor resource type exists before attempting to delete
if kubectl get crd servicemonitors.monitoring.coreos.com > /dev/null 2>&1; then
  # Delete the ServiceMonitor for cluster autoscaler
  kubectl delete servicemonitor cluster-autoscaler --namespace kube-system --ignore-not-found=true

  # Delete the ServiceMonitor for metrics server
  kubectl delete servicemonitor metrics-server --namespace kube-system --ignore-not-found=true
fi

# Delete the Kubernetes Dashboard
kubectl delete -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.5.1/aio/deploy/recommended.yaml --ignore-not-found=true

# Delete the admin-user service account and cluster role binding
kubectl delete serviceaccount admin-user --namespace kubernetes-dashboard --ignore-not-found=true
kubectl delete clusterrolebinding admin-user --ignore-not-found=true

# Delete the monitoring namespace
kubectl delete namespace monitoring --ignore-not-found=true