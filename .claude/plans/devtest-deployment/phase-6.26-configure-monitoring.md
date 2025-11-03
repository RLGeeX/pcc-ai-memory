# Phase 6.26: Configure Monitoring

**Tool**: [WARP] Partner Execution
**Estimated Duration**: 20 minutes

## Purpose

Configure basic monitoring for ArgoCD using GKE Cloud Monitoring (formerly Stackdriver), verify metrics collection, and set up alerts for critical ArgoCD component failures.

## Prerequisites

- Phase 6.25 completed (Velero installed)
- GKE cluster has Cloud Monitoring enabled (default for GKE)
- kubectl access to argocd namespace

## Detailed Steps

### Step 1: Verify Cloud Monitoring Enabled

```bash
gcloud container clusters describe pcc-prj-devops-nonprod \
  --region us-east4 \
  --format='get(monitoringConfig.componentConfig.enableComponents)'
```

**Expected**: `SYSTEM_COMPONENTS` and `WORKLOADS` enabled

**HALT if**: Monitoring not enabled

### Step 2: Verify ArgoCD Metrics Endpoints

Check that ArgoCD components expose metrics:

```bash
# Application Controller metrics
kubectl get svc argocd-application-controller-metrics -n argocd

# Server metrics
kubectl get svc argocd-server-metrics -n argocd

# Repo Server metrics
kubectl get svc argocd-repo-server-metrics -n argocd

# Dex metrics
kubectl get svc argocd-dex-server-metrics -n argocd
```

**Expected**: All services exist with type ClusterIP

### Step 3: Test Metrics Endpoint Accessibility

```bash
# Test application controller metrics
kubectl exec -n argocd deployment/argocd-server -- \
  curl -sS http://argocd-application-controller-metrics.argocd.svc.cluster.local:8082/metrics | head -20
```

**Expected**: Prometheus-format metrics output
```
# HELP argocd_app_info Information about Applications
# TYPE argocd_app_info gauge
argocd_app_info{...} 1
...
```

### Step 4: Create GCP Monitoring Alert for ArgoCD Deployment Down

```bash
# Create alert policy for ArgoCD server container not ready
gcloud alpha monitoring policies create \
  --display-name="ArgoCD Server Down - NonProd" \
  --condition-display-name="ArgoCD Server Container Not Ready" \
  --condition-threshold-value=1 \
  --condition-threshold-duration=300s \
  --condition-threshold-comparison=COMPARISON_LT \
  --condition-threshold-filter='resource.type="k8s_container" AND resource.labels.cluster_name="pcc-prj-devops-nonprod" AND resource.labels.namespace_name="argocd" AND resource.labels.container_name="argocd-server" AND metric.type="kubernetes.io/container/ready"' \
  --condition-threshold-aggregation-alignment-period=60s \
  --condition-threshold-aggregation-per-series-aligner=ALIGN_MEAN \
  --condition-threshold-aggregation-cross-series-reducer=REDUCE_MEAN
```

**Note**: Omit `--notification-channels` for nonprod (no alerts). For production, add notification channels:
```bash
# Example with email notification (create channel first):
# --notification-channels="projects/pcc-prj-devops-nonprod/notificationChannels/CHANNEL_ID"
```

### Step 5: Create Alert for ArgoCD Sync Failures

```bash
# Create log-based metric for sync failures
gcloud logging metrics create argocd-sync-failures \
  --description="Count of ArgoCD application sync failures" \
  --log-filter='resource.type="k8s_container"
resource.labels.cluster_name="pcc-prj-devops-nonprod"
resource.labels.namespace_name="argocd"
resource.labels.container_name="argocd-application-controller"
jsonPayload.level="error"
jsonPayload.msg=~".*failed to sync.*"'
```

**Expected**: Metric created

### Step 6: View ArgoCD Metrics in Cloud Console

1. Navigate to: https://console.cloud.google.com/monitoring
2. Select project: `pcc-prj-devops-nonprod`
3. Go to **Metrics Explorer**
4. Select resource type: `k8s_container`
5. Filter by:
   - Cluster: `pcc-prj-devops-nonprod`
   - Namespace: `argocd`
6. Select metric: `kubernetes.io/container/ready`

**Expected**: Chart showing ArgoCD container readiness over time

### Step 7: Create Dashboard for ArgoCD Health

```bash
# Create custom dashboard JSON
cat > /tmp/argocd-dashboard.json <<'EOF'
{
  "displayName": "ArgoCD NonProd - DevTest",
  "mosaicLayout": {
    "columns": 12,
    "tiles": [
      {
        "width": 6,
        "height": 4,
        "widget": {
          "title": "ArgoCD Deployment Readiness",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"k8s_deployment\" resource.labels.cluster_name=\"pcc-prj-devops-nonprod\" resource.labels.namespace_name=\"argocd\" metric.type=\"kubernetes.io/container/ready\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_MEAN"
                    }
                  }
                }
              }
            ]
          }
        }
      },
      {
        "xPos": 6,
        "width": 6,
        "height": 4,
        "widget": {
          "title": "ArgoCD Pod CPU Usage",
          "xyChart": {
            "dataSets": [
              {
                "timeSeriesQuery": {
                  "timeSeriesFilter": {
                    "filter": "resource.type=\"k8s_container\" resource.labels.cluster_name=\"pcc-prj-devops-nonprod\" resource.labels.namespace_name=\"argocd\" metric.type=\"kubernetes.io/container/cpu/core_usage_time\"",
                    "aggregation": {
                      "alignmentPeriod": "60s",
                      "perSeriesAligner": "ALIGN_RATE"
                    }
                  }
                }
              }
            ]
          }
        }
      }
    ]
  }
}
EOF

# Create dashboard
gcloud monitoring dashboards create --config-from-file=/tmp/argocd-dashboard.json
```

**Expected**: Dashboard created with link to view

### Step 8: View ArgoCD Logs in Cloud Logging

```bash
# View recent ArgoCD application controller logs
gcloud logging read 'resource.type="k8s_container"
resource.labels.cluster_name="pcc-prj-devops-nonprod"
resource.labels.namespace_name="argocd"
resource.labels.container_name="argocd-application-controller"' \
  --limit 10 \
  --format json
```

**Expected**: JSON-formatted logs from application controller

### Step 9: Set Up Log-Based Metric for Application Sync Events

```bash
# Create metric for successful syncs
gcloud logging metrics create argocd-sync-success \
  --description="Count of successful ArgoCD application syncs" \
  --log-filter='resource.type="k8s_container"
resource.labels.cluster_name="pcc-prj-devops-nonprod"
resource.labels.namespace_name="argocd"
resource.labels.container_name="argocd-application-controller"
jsonPayload.level="info"
jsonPayload.msg=~".*sync succeeded.*"'
```

### Step 10: Verify Metrics Collection

Wait 5 minutes for metrics to be collected, then query:

```bash
# Query ArgoCD deployment metrics
gcloud monitoring time-series list \
  --filter='metric.type="kubernetes.io/container/ready" AND resource.labels.namespace_name="argocd"' \
  --format=json \
  --limit=1
```

**Expected**: Returns time series data for ArgoCD containers

## Success Criteria

- ✅ Cloud Monitoring enabled on GKE cluster
- ✅ ArgoCD metrics endpoints accessible
- ✅ Alert created for ArgoCD server down
- ✅ Log-based metrics created for sync events
- ✅ Custom dashboard created for ArgoCD health
- ✅ ArgoCD logs visible in Cloud Logging
- ✅ Metrics collection verified

## HALT Conditions

**HALT if**:
- Cloud Monitoring not enabled
- Metrics endpoints not accessible
- Alert creation fails
- Dashboard creation fails
- No metrics data after 5 minutes

**Resolution**:
- Enable Cloud Monitoring:
  ```bash
  gcloud container clusters update pcc-prj-devops-nonprod \
    --region us-east4 \
    --enable-cloud-monitoring \
    --monitoring=SYSTEM,WORKLOAD
  ```
- Check metrics services: `kubectl get svc -n argocd | grep metrics`
- Verify Cloud Monitoring API enabled:
  ```bash
  gcloud services enable monitoring.googleapis.com
  ```
- Check IAM permissions for Monitoring Writer role
- Wait longer for metrics (initial collection can take 10 minutes)

## Next Phase

Proceed to **Phase 6.27**: E2E Validation

## Notes

- **GKE Monitoring**: Built-in Cloud Monitoring integration (no Prometheus install needed)
- **Metrics**: ArgoCD exposes Prometheus metrics on `:8082` (controller), `:8083` (server)
- **Alerts**: Created via Cloud Monitoring (not PagerDuty/Slack for nonprod)
- **Production**: Add notification channels (email, Slack, PagerDuty)
- **Dashboard**: Custom dashboard for ArgoCD health visualization
- **Logs**: Automatically collected by Cloud Logging (no config needed)
- **Log-Based Metrics**: Create custom metrics from log patterns
- **Retention**: Cloud Logging retains logs for 30 days (default)
- **Cost**: Cloud Monitoring is included with GKE (no extra charge for basic metrics)
- Metrics endpoint format: `http://<service>.<namespace>.svc.cluster.local:<port>/metrics`
- ArgoCD metrics include: app_info, sync_status, health_status, k8s_request_total
- GKE exports metrics automatically (no Prometheus Operator needed)
- Cloud Monitoring aggregates metrics across all pods (no PromQL needed)
- Alerts use metric thresholds (e.g., deployment not ready < 1 for 5 minutes)
- Dashboard shows real-time data (60s refresh)
- Log queries use Cloud Logging filter syntax (not Grafana Loki)
- For advanced monitoring, consider installing Prometheus + Grafana (optional)
- ArgoCD UI has built-in health/sync status (use for quick checks)
- Cloud Console Monitoring UI: https://console.cloud.google.com/monitoring
- Metrics Explorer useful for ad-hoc queries
- Can create alerts for: deployment down, sync failures, high CPU, out of memory
