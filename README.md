# CampusBoard Kubernetes Release

Campus announcements API, prepared for a free local Kubernetes assessment.
There are exactly two planted manifest faults. Other requested changes are explicit configuration/capacity tasks, not additional hidden faults. Work in task order; early failures may mask later ones. No application-code changes are needed.

## Self-service setup before the timer
Fork this repository and clone your fork. No mentor-provided cluster, image, namespace or Ingress controller is needed. On Linux, macOS or WSL2, have Bash, Git, kubectl, curl and a running Docker-compatible engine available before the assessment. Allow at least 4 GB free memory and internet access for initial downloads. Native Windows shells are not supported; use WSL2 with Docker integration. No paid cloud, registry login, domain purchase or real token required.

Run the supplied setup once before timed tasks. It downloads a checksum-verified local kind binary, creates a dedicated `campusboard-ga1` cluster, builds/loads the supplied application image, prepares namespace `campusboard-exam`, installs the lab Ingress controller and starts its localhost tunnel. First setup may take several minutes depending on downloads; it is ungraded preparation. It does not apply or repair `k8s/`. Start the timer only after `SETUP READY`. If setup fails, do not begin timed work or treat it as a planted fault.

```bash
git clone https://github.com/YOUR-USERNAME/campusboard-k8s-release.git
cd campusboard-k8s-release
git switch -c fix/campusboard-release
bash scripts/prepare-lab.sh
source .lab/env.sh
kubectl config current-context
kubectl get namespace "$NS"
```

## Application contract (correct application code)
- HTTP listens on `0.0.0.0:5000`.
- `GET /health`: HTTP 200 with `service: campusboard`, `status: ok`.
- `GET /` and `/info`: HTTP 200 with environment from APP_ENV, banner from BANNER, token_present boolean, and pod hostname. Token value is never returned.
- Unknown paths return HTTP 404.
- ConfigMap name `campusboard-config`; Deployment/Service/Ingress name `campusboard`; container name `api`; pod label `app=campusboard`.
- Service contract: ClusterIP port 80 must forward to the application listener.
- Ingress contract: class `campusboard`, host `campusboard.local`, prefix `/`, backend `campusboard:80`. Ingress is correct; the setup script prepares its controller.
- Readiness controls traffic eligibility; liveness restarts unhealthy containers. Keep both checks.

## Required configuration and capacity
Task 1: ConfigMap `APP_ENV=campus`, `BANNER=Campus Updates`. Create Secret `campusboard-demo` with key `DEMO_TOKEN` containing harmless `practice-only`. Inject that key as environment variable DEMO_TOKEN using `secretKeyRef` in Deployment. Do not hardcode token in Deployment, print decoded token, or use real secrets. Adding this Secret reference is a requested task, not a planted fault. Do not commit Secret YAML or credentials.
Task 4: final requests CPU `100m`, memory `64Mi`; limits CPU `300m`, memory `128Mi`; final replicas `3`. Persist these in deployment.yaml. No HPA or load test required. This API is stateless; no PVC/database task.

## Command reference (not repair answers)
```bash
kubectl -n "$NS" apply -f k8s/
kubectl -n "$NS" get pods -l app=campusboard -o wide
kubectl -n "$NS" describe pod POD_NAME
kubectl -n "$NS" logs POD_NAME
kubectl -n "$NS" get deployment campusboard -o yaml
kubectl -n "$NS" get service campusboard -o yaml
kubectl -n "$NS" get endpointslices -l kubernetes.io/service-name=campusboard -o yaml
kubectl -n "$NS" get events --sort-by=.metadata.creationTimestamp
kubectl -n "$NS" rollout status deployment/campusboard --timeout=90s
# ConfigMap environment changes need new pods; apply alone does not refresh env:
kubectl -n "$NS" rollout restart deployment/campusboard
# Runtime configuration without exposing token:
kubectl -n "$NS" exec deployment/campusboard -- python -c 'import os; print("APP_ENV="+os.getenv("APP_ENV","")); print("BANNER="+os.getenv("BANNER","")); print("DEMO_TOKEN present:",bool(os.getenv("DEMO_TOKEN")))'
# Service-DNS test from inside cluster (never direct pod IP):
kubectl -n "$NS" exec deployment/campusboard -- python -c 'import urllib.request; r=urllib.request.urlopen("http://campusboard/health",timeout=5); print("HTTP",r.status); print(r.read().decode())'
kubectl -n "$NS" get ingress campusboard -o yaml
# Setup script keeps the controller tunnel on 127.0.0.1:8088:
curl --fail-with-body -i -H 'Host: campusboard.local' http://127.0.0.1:8088/info
# Observe replacement; Ctrl-C after recording evidence:
kubectl -n "$NS" get pods -l app=campusboard -w
# Delete exactly one pod from assigned namespace only:
kubectl -n "$NS" delete pod POD_NAME
```

Use a separate terminal for observation if helpful. Run `source .lab/env.sh` from the repository root in every terminal; it selects only this lab's kubeconfig and namespace. Do not run setup again during tasks. For failure commands, retain error output as evidence; a failed HTTP request is expected until repair. If multiple available pods exist, exec may select one: final replica evidence comes from get deployment/get pods, not a single response.

## Evidence and boundaries
Follow assessment.md supplied separately. Capture original failures before fixing them. Record causes, minimal manifest changes and genuine runtime results in evidence-notes.md. Include relevant YAML/diff in PDF. Do not remove probes, change correct app code, route directly to pods to claim Service recovery, or change Ingress to bypass the Service. No exact screenshot-count requirement. Keep real secrets and decoded Secret values out of all evidence. Setup failures (image/controller/tooling) are not planted faults; resolve prerequisite/setup failures before starting the timer. No mentor action is part of the timed workflow. PR, CI/CD run and pushes of fixes are not required. Instructor solution and solved patches are deliberately absent from this repository.
