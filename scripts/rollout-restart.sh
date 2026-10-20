#!/usr/bin/env bash
# Rolling restart of every microservice deployment (NOT the databases --
# restarting a stateless DB pod with no PVC would wipe its data).
set -euo pipefail
NS=tw5-demo
DEPLOYMENTS=(auth-service storage-service hr-service nginx-lb)

for d in "${DEPLOYMENTS[@]}"; do
  echo ">> Restarting deployment/${d}"
  kubectl rollout restart "deployment/${d}" -n "${NS}"
done

for d in "${DEPLOYMENTS[@]}"; do
  kubectl rollout status "deployment/${d}" -n "${NS}"
done

echo "All microservice deployments restarted and rolled out successfully."
