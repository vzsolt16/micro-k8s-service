# TW5 Demo — Cheat Sheet

## 1. Start everything (up to `minikube tunnel`)

Run in your project folder (`tw5-demo`):

```bash
# 1. Start the cluster (skip if it's already running — check with `minikube status`)
minikube start --driver=docker --cpus=4 --memory=3072

# 2. Re-enable metrics-server (needed for the HPAs)
minikube addons enable metrics-server

# 3. Build the three app images
minikube image build -t auth-service:local ./services/auth-service
minikube image build -t storage-service:local ./services/storage-service
minikube image build -t hr-service:local ./services/hr-service

# 4. Deploy everything
./scripts/deploy-all.sh
```

Then in a **second terminal**, leave this running for the whole demo:

```bash
minikube tunnel
```

- It'll ask for your Mac password once — nothing shows on screen as you type, that's normal.
- Confirm it worked, back in your first terminal:

```bash
kubectl get svc nginx-lb -n tw5-demo
```

`EXTERNAL-IP` should show `127.0.0.1`, not `<pending>`.

---

## 2. Running the demo

**A. Architecture (~2.5 min)** — walk through the slide deck (title → architecture → scaling model → config/secrets → demo plan). No terminal needed yet.

**B. Show the configuration (~1–1.5 min)** — pick one or two of these to highlight:

```bash
# The ConfigMap-mounted nginx.conf, proven live inside the running pod
kubectl exec -n tw5-demo deploy/nginx-lb -- cat /etc/nginx/nginx.conf

# Secrets only ever reach the pod as env vars, never hardcoded
kubectl exec -n tw5-demo deploy/auth-service -- printenv | grep DB_

# The HPA definitions themselves
kubectl get hpa -n tw5-demo
```

**C. Prove it works (~1 min):**

```bash
../scripts/smoke-test.sh 5
```

Point out the pod names rotating in the summary at the end of each block — that's the live proof of pod-level load balancing.

**D. scaling:**

```bash
LB_URL="http://$(kubectl get svc nginx-lb -n tw5-demo -o jsonpath='{.status.loadBalancer.ingress[0].ip}')"
hey -z 60s -c 50 "${LB_URL}/storage"
```

```bash
kubectl get hpa -n tw5-demo

```
**E. If asked about rollout automation:**

```bash
../scripts/rollout-restart.sh
```

---

## After the demo

- `minikube tunnel` terminal → Ctrl+C
- `minikube stop`