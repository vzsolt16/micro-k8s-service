# TW5 Demo -- Micro Kubernetes Services

Three microservices (`storage`, `auth`, `hr`), each with its own Postgres
database, sitting behind a self-scaling nginx load balancer, all running on
Minikube.

## Architecture

```
                         (minikube tunnel / EKS ELB)
                                    |
                          Service: nginx-lb (type=LoadBalancer)
                                    |
                        Deployment: nginx-lb  (HPA min1/max2)
                        ConfigMap-mounted nginx.conf
                        routes /auth /storage /hr by path
                    /              |                \
                   v               v                 v
      Service:auth-service  Service:storage-service  Service:hr-service
      Deploy: auth-service  Deploy: storage-service   Deploy: hr-service
      HPA min2/max6         HPA min2/max5              HPA min1/max3
            ^                    |    \                    |    \
            |                    |     \___(AUTH_SERVICE_URL)    \
            |                    v                          v     \
            |             Service:storage-db          Service:hr-db \
            |             Deploy: storage-db (postgres) Deploy: hr-db (postgres)
            |
      Service:auth-db
      Deploy: auth-db (postgres)
```

Every arrow that says "Service:x" is a stable ClusterIP -- that's the piece
that makes the whole thing dynamic (see below).



## Optional items implemented

- **ConfigMap for nginx.conf** -- `k8s/02-configmap-nginx.yaml`, mounted via
  `volumeMounts`/`subPath` in `k8s/40-nginx-lb.yaml`.
- **Secrets for DB credentials** -- `k8s/01-secrets.yaml`, consumed only via
  `secretKeyRef` env vars, never hardcoded.
- **Rollout/restart automation** -- `scripts/rollout-restart.sh` restarts
  all four app deployments (not the databases).
- **EKS notes** -- `eks/README-EKS.md`.

## Prerequisites

- Minikube + kubectl
- Docker
- `minikube addons enable metrics-server` (required for CPU-based HPAs to
  report real numbers)

## Running it

```bash
minikube start --cpus=4 --memory=8192
minikube addons enable metrics-server

./scripts/build-images.sh   # builds the 3 app images into Minikube's Docker daemon
./scripts/deploy-all.sh     # applies every manifest in order

# In a second terminal, keep this running:
minikube tunnel
```

## Proving it works

```bash
kubectl get all -n tw5-demo
kubectl get hpa -n tw5-demo -w        # watch replica counts live

./scripts/smoke-test.sh 10            # hit the LB 10x, see pod names rotate

# Force a scale-up manually to demonstrate the HPA reacting, without
# waiting on real CPU load:
kubectl scale deployment/storage-service -n tw5-demo --replicas=4
kubectl get pods -n tw5-demo -l app=storage-service -w

# Prove the ConfigMap is really what's driving nginx's routing:
kubectl get configmap nginx-lb-config -n tw5-demo -o yaml
kubectl exec -n tw5-demo deploy/nginx-lb -- cat /etc/nginx/nginx.conf

# Prove secrets are only ever passed as env vars, never as plaintext files:
kubectl exec -n tw5-demo deploy/auth-service -- printenv | grep DB_

./scripts/rollout-restart.sh          # rolling-restart every app deployment
```

To actually trigger CPU-based autoscaling (rather than the manual
`kubectl scale` above), generate real load against the LB, e.g. with `hey`
or `ab`:

```bash
hey -z 60s -c 50 "$(minikube service nginx-lb -n tw5-demo --url)/storage"
```

## Repo layout

```
services/<name>/       Express app + Dockerfile per microservice
k8s/                   All manifests, applied in numeric-prefix order
scripts/                build-images.sh, deploy-all.sh, rollout-restart.sh, smoke-test.sh
```
