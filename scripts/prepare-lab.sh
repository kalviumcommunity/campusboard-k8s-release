#!/usr/bin/env bash
# Infrastructure only: never applies or repairs the assessment k8s/ manifests.
set -euo pipefail
cd "$(dirname "$0")/.."
ROOT="$PWD"
for tool in docker kubectl curl; do
  command -v "$tool" >/dev/null || { echo "Missing prerequisite: $tool. Complete workstation setup before assessment." >&2; exit 1; }
done
docker info >/dev/null 2>&1 || { echo 'Start your local Docker-compatible engine, then rerun setup.' >&2; exit 1; }
mkdir -p .lab/bin
KIND_VERSION=v0.27.0
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)
case "$ARCH" in arm64|aarch64) ARCH=arm64;; x86_64|amd64) ARCH=amd64;; *) echo 'Unsupported CPU architecture' >&2; exit 1;; esac
case "$OS" in linux|darwin) ;; *) echo 'Use Linux, macOS or WSL2 with Docker integration.' >&2; exit 1;; esac
KIND="$ROOT/.lab/bin/kind"
if [ ! -x "$KIND" ]; then
  URL="https://kind.sigs.k8s.io/dl/$KIND_VERSION/kind-$OS-$ARCH"
  curl --fail --location --retry 3 "$URL" -o "$KIND.download"
  curl --fail --location --retry 3 "$URL.sha256sum" -o "$KIND.sha256sum"
  EXPECTED=$(awk '{print $1}' "$KIND.sha256sum")
  if command -v sha256sum >/dev/null; then ACTUAL=$(sha256sum "$KIND.download" | awk '{print $1}'); else ACTUAL=$(shasum -a 256 "$KIND.download" | awk '{print $1}'); fi
  [ "$ACTUAL" = "$EXPECTED" ] || { echo 'kind checksum mismatch' >&2; exit 1; }
  mv "$KIND.download" "$KIND"; chmod +x "$KIND"
fi
CLUSTER=campusboard-ga1
CONTEXT=kind-$CLUSTER
NS=campusboard-exam
# Refuse a second entrypoint before changing anything. Reuse this lab's own tunnel.
if [ -f .lab/forward.pid ] && kill -0 "$(cat .lab/forward.pid)" 2>/dev/null; then
  echo 'Existing lab tunnel found; checking it below.'
else
  if curl -s --max-time 1 http://127.0.0.1:8088/ >/dev/null 2>&1; then
    echo 'Port 8088 already in use. Stop its owner before setup; script will not kill unrelated processes.' >&2; exit 1
  fi
fi
if ! "$KIND" get clusters | grep -qx "$CLUSTER"; then
  "$KIND" create cluster --name "$CLUSTER" --image kindest/node:v1.32.2 --kubeconfig "$ROOT/.lab/kubeconfig" --wait 180s
fi
# Never switch or operate on the user's current/shared context.
"$KIND" get kubeconfig --name "$CLUSTER" > .lab/kubeconfig
chmod 600 .lab/kubeconfig
k() { kubectl --kubeconfig "$ROOT/.lab/kubeconfig" --context "$CONTEXT" "$@"; }
k get namespace "$NS" >/dev/null 2>&1 || k create namespace "$NS"
# Building/loading infrastructure is ungraded preparation, not a student repair.
docker build -t campusboard-api:ga1 .
load_image() {
  # Import only host platform: Docker's image store may retain an incomplete
  # multi-platform index, which kind's --all-platforms import cannot load.
  docker image save "$1" | docker exec --privileged -i "$CLUSTER-control-plane" ctr --namespace=k8s.io images import --platform "linux/$ARCH" --digests -
}
load_image campusboard-api:ga1
# Load controller ahead of time too; avoid timed image pulls.
docker pull traefik:v3.3.6
load_image traefik:v3.3.6
k apply -f scripts/lab-ingress.yaml
k -n campusboard-system rollout status deployment/lab-ingress --timeout=180s
if ! { [ -f .lab/forward.pid ] && kill -0 "$(cat .lab/forward.pid)" 2>/dev/null; }; then
  nohup kubectl --kubeconfig "$ROOT/.lab/kubeconfig" --context "$CONTEXT" -n campusboard-system port-forward service/lab-ingress 8088:80 --address 127.0.0.1 > .lab/forward.log 2>&1 < /dev/null &
  echo $! > .lab/forward.pid
fi
for attempt in $(seq 1 30); do
  CODE=$(curl -s -o /dev/null -w '%{http_code}' --max-time 2 http://127.0.0.1:8088/ || true)
  # No student application routes are deployed yet: controller returns 404.
  [ "$CODE" = 404 ] && break
  sleep 1
done
[ "$CODE" = 404 ] || { echo 'Ingress entrypoint check failed; see .lab/forward.log' >&2; exit 1; }
printf 'export NS=%q\nexport KUBECONFIG=%q\n' "$NS" "$ROOT/.lab/kubeconfig" > .lab/env.sh
"$KIND" get kubeconfig --name "$CLUSTER" > .lab/kubeconfig
chmod 600 .lab/kubeconfig
printf '\nSETUP READY\nCluster: %s\nNamespace: %s\nImage: campusboard-api:ga1\nIngress: campusboard / 127.0.0.1:8088\n' "$CLUSTER" "$NS"
echo 'In each assessment terminal: source .lab/env.sh'
echo 'Assessment manifests remain untouched and unapplied. Do not run setup again after starting tasks.'
