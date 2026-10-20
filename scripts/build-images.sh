#!/usr/bin/env bash
# Builds the three app images directly inside Minikube's Docker daemon so
# the cluster can use them with imagePullPolicy: IfNotPresent, no registry
# push needed.
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

eval "$(minikube docker-env)"

for svc in auth-service storage-service hr-service; do
  echo ">> Building ${svc}:local"
  docker build -t "${svc}:local" "${ROOT_DIR}/services/${svc}"
done

echo "Done. Images are available inside Minikube's Docker daemon."
