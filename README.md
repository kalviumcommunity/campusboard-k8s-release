# CampusBoard Kubernetes Release

Campus announcements API, prepared for a free local Kubernetes assessment.
There are exactly two planted manifest faults. Other requested changes are explicit configuration/capacity tasks, not additional hidden faults. Work in task order; early failures may mask later ones. No application-code changes are needed.

## Before timer
Fork https://github.com/kalviumcommunity/campusboard-k8s-release and clone your fork. Create branch `fix/campusboard-release`. Instructor provides a running local cluster, loaded image `campusboard-api:ga1`, dedicated namespace, controller for IngressClass `campusboard`, and a verified local entrypoint. No paid cloud, registry login, domain purchase, real token, installations or builds during assessment. Docker Desktop is not required: a free container engine plus kind/minikube also works. Check context before all work.

```bash
git clone https://github.com/YOUR-USERNAME/campusboard-k8s-release.git
cd campusboard-k8s-release
git switch -c fix/campusboard-release
export NS=YOUR_ASSIGNED_NAMESPACE
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
- Ingress contract: class `campusboard`, host `campusboard.local`, prefix `/`, backend `campusboard:80`. Ingress is correct; instructor supplies working controller.
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
# Instructor starts controller port-forward on 127.0.0.1:8088 before timer:
curl --fail-with-body -i -H 'Host: campusboard.local' http://127.0.0.1:8088/info
# Observe replacement; Ctrl-C after recording evidence:
kubectl -n "$NS" get pods -l app=campusboard -w
# Delete exactly one pod from assigned namespace only:
kubectl -n "$NS" delete pod POD_NAME
```

Use a separate terminal for observation if helpful. Export NS in every terminal. For failure commands, retain error output as evidence; a failed HTTP request is expected until repair. If multiple available pods exist, exec may select one: final replica evidence comes from get deployment/get pods, not a single response.

## Evidence and boundaries
Follow assessment.md supplied separately. Capture original failures before fixing them. Record causes, minimal manifest changes and genuine runtime results in evidence-notes.md. Include relevant YAML/diff in PDF. Do not remove probes, change correct app code, route directly to pods to claim Service recovery, or change Ingress to bypass the Service. No exact screenshot-count requirement. Keep real secrets and decoded Secret values out of all evidence. Report setup failures (image/controller/tooling) to instructor: those are not planted faults. PR, CI/CD run and pushes of fixes are not required. Instructor solution and solved patches are deliberately absent from this repository.
