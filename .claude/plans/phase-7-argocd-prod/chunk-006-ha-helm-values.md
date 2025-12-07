# Chunk 6: Create HA Helm Values Configuration

**Status:** pending
**Dependencies:** chunk-005-deploy-infrastructure
**Complexity:** medium
**Estimated Time:** 20 minutes
**Tasks:** 2
**Phase:** HA Installation
**Story:** STORY-703
**Jira:** PCC-286

---

## Task 1: Copy and Modify Base Helm Values

**Agent:** gitops-engineer

**Step 1: Copy nonprod values as baseline**

```bash
cd ~/pcc/infra
cp pcc-argocd-nonprod-infra/helm/argocd/values-nonprod-autopilot.yaml \
   pcc-argocd-prod-infra/environments/prod/helm/values-prod-autopilot.yaml
```

**Step 2: Configure multi-replica HA**

Edit `environments/prod/helm/values-prod-autopilot.yaml`:

```yaml
controller:
  replicas: 2  # Changed from 1
  resources:
    requests:
      cpu: "2000m"
      memory: "4Gi"
    limits:
      cpu: "2000m"
      memory: "4Gi"

repoServer:
  replicas: 2  # Changed from 1
  resources:
    requests:
      cpu: "1000m"
      memory: "2Gi"
    limits:
      cpu: "1000m"
      memory: "2Gi"

  autoscaling:
    enabled: true
    minReplicas: 2
    maxReplicas: 4
    targetCPUUtilizationPercentage: 70

server:
  replicas: 2  # Changed from 1
  resources:
    requests:
      cpu: "500m"
      memory: "1Gi"
    limits:
      cpu: "500m"
      memory: "1Gi"
```

---

## Task 2: Configure Redis HA

**Agent:** gitops-engineer

**Step 1: Enable Redis HA subchart**

Add to `values-prod-autopilot.yaml`:

```yaml
# Disable single Redis instance
redis:
  enabled: false

# Enable Redis HA with 3 replicas
redis-ha:
  enabled: true
  replicas: 3

  haproxy:
    enabled: true
    replicas: 3
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "100m"
        memory: "128Mi"

  redis:
    resources:
      requests:
        cpu: "200m"
        memory: "256Mi"
      limits:
        cpu: "200m"
        memory: "256Mi"

  sentinel:
    resources:
      requests:
        cpu: "100m"
        memory: "128Mi"
      limits:
        cpu: "100m"
        memory: "128Mi"
```

**Step 2: Commit HA configuration**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra
git add environments/prod/helm/values-prod-autopilot.yaml
git commit -m "feat(phase-7): configure HA with multi-replica and Redis HA"
```

---

## Chunk Complete Checklist

- [ ] Helm values copied from nonprod
- [ ] Controller replicas = 2
- [ ] Repo server replicas = 2 (autoscaling 2-4)
- [ ] Server replicas = 2
- [ ] Redis HA enabled with 3 replicas
- [ ] Resource requests/limits configured
- [ ] Configuration committed
- [ ] Ready for chunk 7 (affinity and security)
