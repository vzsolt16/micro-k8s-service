#!/usr/bin/env bash
# Hits the public LB repeatedly and pretty-prints each response, then prints
# a summary of which pod answered each request -- the fastest way to prove
# pod-level load balancing live in front of a mentor.
#
# Usage: ./scripts/smoke-test.sh [number-of-requests-per-endpoint]
set -euo pipefail
NS=tw5-demo
N="${1:-10}"

USE_COLOR=0
if [ -t 1 ]; then USE_COLOR=1; fi
bold() { if [ "$USE_COLOR" = 1 ]; then printf '\033[1m%s\033[0m' "$1"; else printf '%s' "$1"; fi; }
dim()  { if [ "$USE_COLOR" = 1 ]; then printf '\033[2m%s\033[0m' "$1"; else printf '%s' "$1"; fi; }

pretty_json() {
  if command -v jq >/dev/null 2>&1; then
    jq .
  else
    python3 -m json.tool
  fi
}

# Extracts "<pod>  ->  auth: <auth-pod>" for storage/hr, or just "<pod>" for auth.
pod_summary() {
  if command -v jq >/dev/null 2>&1; then
    jq -r 'if .auth then "\(.pod)  ->  auth: \(.auth.pod)" else .pod end' 2>/dev/null || echo "(parse error)"
  else
    python3 -c '
import json, sys
try:
    d = json.load(sys.stdin)
    if "auth" in d:
        print("{}  ->  auth: {}".format(d["pod"], d["auth"]["pod"]))
    else:
        print(d["pod"])
except Exception:
    print("(parse error)")
'
  fi
}

# On the docker driver, `minikube service --url` opens its own blocking
# tunnel and never returns -- capturing it here would hang forever. Instead,
# ask kubectl directly for the IP that `minikube tunnel` assigned to the
# LoadBalancer Service (this works the same way on every driver, and doesn't
# block). Falls back to `minikube service --url` only if no tunnel is
# running yet, in which case we cap how long we'll wait for it.
get_lb_url() {
  local ip
  ip=$(kubectl get svc nginx-lb -n "${NS}" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)
  if [ -n "${ip}" ]; then
    echo "http://${ip}"
    return 0
  fi
  echo "" # signal: no tunnel detected
}

URL=$(get_lb_url)
if [ -z "${URL}" ]; then
  echo "No external IP found for nginx-lb yet."
  echo "Make sure 'minikube tunnel' is running in another terminal (it needs"
  echo "your sudo password once)."
  echo "Checking again in a moment..."
  sleep 3
  URL=$(get_lb_url)
fi
if [ -z "${URL}" ]; then
  echo "Still no external IP. Run 'kubectl get svc nginx-lb -n ${NS}' yourself"
  echo "to check -- EXTERNAL-IP should show an address, not <pending>."
  exit 1
fi

echo "$(bold "LB URL:") ${URL}"
echo

# path, human label
run_batch() {
  local path="$1"
  local label="$2"
  local -a summary=()
  local i body line

  echo "$(bold "==================================================")"
  echo "$(bold " ${label}")  $(dim "(${N} requests to ${path})")"
  echo "$(bold "==================================================")"
  echo

  for i in $(seq 1 "${N}"); do
    echo "$(dim "--- request ${i}/${N} ---")"
    body=$(curl -s -f "${URL}${path}" || true)
    if [ -z "${body}" ]; then
      echo "  (request failed)"
      summary+=("request ${i}: FAILED")
    else
      echo "${body}" | pretty_json
      line=$(echo "${body}" | pod_summary)
      summary+=("request ${i}: ${line}")
    fi
    echo
  done

  echo "$(bold "-- summary for ${label} --")"
  for line in "${summary[@]}"; do
    echo "  ${line}"
  done
  echo
}

run_batch "/storage" "storage-service -> auth-service"
run_batch "/hr" "hr-service -> auth-service"
