# Chunk 19: Configure Monitoring and Dashboards

**Status:** pending
**Dependencies:** chunk-018-resource-quotas
**Complexity:** medium
**Estimated Time:** 25 minutes
**Tasks:** 3
**Phase:** GitOps Patterns
**Story:** STORY-708
**Jira:** PCC-299

---

## Task 1: Create ServiceMonitor for ArgoCD

**Agent:** sre-engineer

**Step 1: Create ServiceMonitor manifest**

File: `core/pcc-app-argo-config/prod/monitoring/argocd-servicemonitor.yaml`

```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-metrics
  namespace: argocd
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-metrics
  endpoints:
  - port: metrics
    interval: 30s
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-server-metrics
  namespace: argocd
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  endpoints:
  - port: metrics
    interval: 30s
---
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: argocd-repo-server-metrics
  namespace: argocd
  labels:
    release: prometheus
spec:
  selector:
    matchLabels:
      app.kubernetes.io/name: argocd-repo-server
  endpoints:
  - port: metrics
    interval: 30s
```

---

## Task 2: Create PrometheusRule for Alerts

**Agent:** sre-engineer

**Step 1: Create alert rules**

File: `core/pcc-app-argo-config/prod/monitoring/argocd-alerts.yaml`

```yaml
apiVersion: monitoring.coreos.com/v1
kind: PrometheusRule
metadata:
  name: argocd-alerts
  namespace: argocd
  labels:
    release: prometheus
spec:
  groups:
  - name: argocd
    interval: 30s
    rules:
    - alert: ArgoCDSyncFailure
      expr: sum(argocd_app_sync_total{phase="Failed"}) by (name) > 0
      for: 5m
      labels:
        severity: critical
      annotations:
        summary: "ArgoCD application {{ $labels.name }} sync failed"
        description: "Application {{ $labels.name }} has failed to sync for 5 minutes"

    - alert: ArgoCDAppUnhealthy
      expr: sum(argocd_app_info{health_status!="Healthy"}) by (name) > 0
      for: 10m
      labels:
        severity: high
      annotations:
        summary: "ArgoCD application {{ $labels.name }} is unhealthy"
        description: "Application {{ $labels.name }} health status is {{ $labels.health_status }}"

    - alert: ArgoCDPodRestarts
      expr: rate(kube_pod_container_status_restarts_total{namespace="argocd"}[15m]) > 0.05
      for: 5m
      labels:
        severity: high
      annotations:
        summary: "ArgoCD pod {{ $labels.pod }} restarting frequently"
        description: "Pod {{ $labels.pod }} has restarted {{ $value }} times in last 15 minutes"

    - alert: ArgoCDAPIHighLatency
      expr: histogram_quantile(0.95, argocd_server_api_request_duration_seconds_bucket) > 2
      for: 5m
      labels:
        severity: medium
      annotations:
        summary: "ArgoCD API latency high"
        description: "95th percentile API latency is {{ $value }}s"
```

---

## Task 3: Document Grafana Dashboards

**Agent:** sre-engineer

**Step 1: Create monitoring documentation**

File: `infra/pcc-argocd-prod-infra/environments/prod/docs/monitoring-guide.md`

```markdown
# ArgoCD Production Monitoring

## Grafana Dashboards

Import official ArgoCD dashboards:

1. **ArgoCD Operational Overview** (ID: 14584)
   - URL: https://grafana.com/grafana/dashboards/14584
   - Metrics: Sync status, app health, API requests

2. **ArgoCD Application Activity** (ID: 14585)
   - URL: https://grafana.com/grafana/dashboards/14585
   - Metrics: Application operations, repo server activity

### Import Steps

1. Open Grafana: `https://grafana-prod.portcon.com`
2. Navigate: Dashboards → Import
3. Enter Dashboard ID: 14584
4. Select Prometheus datasource
5. Click Import
6. Repeat for Dashboard ID: 14585

## Prometheus Metrics

Key metrics exposed by ArgoCD:

- `argocd_app_sync_total` - Total sync operations
- `argocd_app_info` - Application health and sync status
- `argocd_server_api_request_duration_seconds` - API latency
- `argocd_git_request_duration_seconds` - Git operation latency

## Alerts

Configured alerts (see `prod/monitoring/argocd-alerts.yaml`):

1. **ArgoCDSyncFailure** (Critical)
   - Trigger: Sync failed for 5+ minutes
   - Action: Check application logs, verify Git repo accessibility

2. **ArgoCDAppUnhealthy** (High)
   - Trigger: Application unhealthy for 10+ minutes
   - Action: Investigate resource status, check K8s events

3. **ArgoCDPodRestarts** (High)
   - Trigger: Pod restarting > 5x in 15 minutes
   - Action: Check pod logs, verify resource limits

4. **ArgoCDAPIHighLatency** (Medium)
   - Trigger: 95th percentile latency > 2s
   - Action: Check API server load, consider scaling

## Cloud Logging Queries

View ArgoCD logs in Cloud Logging:

\`\`\`
resource.type="k8s_container"
resource.labels.namespace_name="argocd"
severity>="WARNING"
\`\`\`
```

**Step 2: Commit monitoring configuration**

```bash
cd ~/pcc/core/pcc-app-argo-config
mkdir -p prod/monitoring
git add prod/monitoring/
git commit -m "feat(phase-7): add ServiceMonitor and PrometheusRule for prod monitoring"
git push origin main

cd ~/pcc/infra/pcc-argocd-prod-infra
git add environments/prod/docs/monitoring-guide.md
git commit -m "docs(phase-7): add monitoring guide for prod ArgoCD"
git push origin main
```

---

## Chunk Complete Checklist

- [ ] ServiceMonitor manifests created (3)
- [ ] PrometheusRule with 4 alerts created
- [ ] Monitoring guide documented (Grafana dashboards, alerts)
- [ ] Cloud Logging queries documented
- [ ] Monitoring configuration committed and pushed
- [ ] Ready for chunk 20 (Velero installation)
