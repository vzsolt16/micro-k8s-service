#!/usr/bin/env bash
# Applies manifests in dependency order: namespace/secrets/config first,
# then databases, then the services that depend on them, then the LB.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
K="${ROOT_DIR}/k8s"

kubectl apply -f "${K}/00-namespace.yaml"
kubectl apply -f "${K}/01-secrets.yaml"
kubectl apply -f "${K}/02-configmap-nginx.yaml"

kubectl apply -f "${K}/10-auth-db.yaml"
kubectl apply -f "${K}/11-auth-service.yaml"
kubectl apply -f "${K}/12-auth-hpa.yaml"

kubectl apply -f "${K}/20-storage-db.yaml"
kubectl apply -f "${K}/21-storage-service.yaml"
kubectl apply -f "${K}/22-storage-hpa.yaml"

kubectl apply -f "${K}/30-hr-db.yaml"
kubectl apply -f "${K}/31-hr-service.yaml"
kubectl apply -f "${K}/32-hr-hpa.yaml"

kubectl apply -f "${K}/40-nginx-lb.yaml"
kubectl apply -f "${K}/41-nginx-hpa.yaml"

echo
echo "Deployed to namespace tw5-demo."
echo "Run 'minikube tunnel' in another terminal to get an external IP for nginx-lb."
echo "Then: kubectl get all -n tw5-demo"
