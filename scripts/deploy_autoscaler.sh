#!/bin/bash
set -euxo pipefail

# Retrieve Terraform outputs
REGION=$(terraform output -raw aws_region)
CLUSTER_NAME=$(terraform output -raw cluster_name)
CLUSTER_AUTOSCALER_ROLE_ARN=$(terraform output -raw cluster_autoscaler_role_arn)

# Update kubeconfig
aws eks update-kubeconfig --region $REGION --name $CLUSTER_NAME

# Create the service account for cluster autoscaler
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cluster-autoscaler
  namespace: kube-system
  annotations:
    eks.amazonaws.com/role-arn: $CLUSTER_AUTOSCALER_ROLE_ARN
EOF

# Deploy the cluster autoscaler Helm chart
helm repo add autoscaler https://kubernetes.github.io/autoscaler || true
helm repo update

helm upgrade --install cluster-autoscaler autoscaler/cluster-autoscaler \
  --namespace kube-system \
  --set autoDiscovery.clusterName=$CLUSTER_NAME \
  --set rbac.serviceAccount.create=false \
  --set rbac.serviceAccount.name=cluster-autoscaler \
  --set awsRegion=$REGION \
  --set extraArgs.balance-similar-node-groups=true \
  --set extraArgs.skip-nodes-with-system-pods=false \
  --set extraArgs.expander=least-waste || true


# Deploy the Kubernetes Dashboard
kubectl apply -f https://raw.githubusercontent.com/kubernetes/dashboard/v2.5.1/aio/deploy/recommended.yaml || true

# Create the admin-user service account and cluster role binding
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF

# Get the token for the admin-user
kubectl -n kubernetes-dashboard create token admin-user || true

# Print the Kubernetes Dashboard URL
echo "Kubernetes Dashboard URL: http://localhost:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/"

# Start a kubectl proxy to access the Kubernetes Dashboard
kubectl proxy --port=8001