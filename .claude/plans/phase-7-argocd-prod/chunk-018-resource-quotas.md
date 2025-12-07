# Chunk 18: Create ResourceQuota and LimitRange Manifests

**Status:** pending
**Dependencies:** chunk-017-hello-world-sample
**Complexity:** simple
**Estimated Time:** 15 minutes
**Tasks:** 2
**Phase:** GitOps Patterns
**Story:** STORY-708
**Jira:** PCC-298

---

## Task 1: Create ResourceQuota Manifests

**Agent:** k8s-architect

**Step 1: Create ResourceQuota for argocd namespace**

File: `core/pcc-app-argo-config/prod/resource-quotas/argocd-quota.yaml`

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: argocd-quota
  namespace: argocd
spec:
  hard:
    requests.cpu: "10"
    requests.memory: "20Gi"
    limits.cpu: "10"
    limits.memory: "20Gi"
    pods: "30"
```

**Step 2: Create ResourceQuota for default namespace**

File: `core/pcc-app-argo-config/prod/resource-quotas/default-quota.yaml`

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: default-quota
  namespace: default
spec:
  hard:
    requests.cpu: "20"
    requests.memory: "40Gi"
    limits.cpu: "20"
    limits.memory: "40Gi"
    pods: "50"
```

**Step 3: Create ResourceQuota for hello-world namespace**

File: `core/pcc-app-argo-config/prod/resource-quotas/hello-world-quota.yaml`

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: hello-world-quota
  namespace: hello-world
spec:
  hard:
    requests.cpu: "5"
    requests.memory: "10Gi"
    limits.cpu: "5"
    limits.memory: "10Gi"
    pods: "20"
```

---

## Task 2: Create LimitRange Manifests

**Agent:** k8s-architect

**Step 1: Create LimitRange for argocd namespace**

File: `core/pcc-app-argo-config/prod/resource-quotas/argocd-limitrange.yaml`

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: argocd-limitrange
  namespace: argocd
spec:
  limits:
  - default:
      cpu: "500m"
      memory: "1Gi"
    defaultRequest:
      cpu: "100m"
      memory: "256Mi"
    type: Container
```

**Step 2: Create LimitRange for default namespace**

File: `core/pcc-app-argo-config/prod/resource-quotas/default-limitrange.yaml`

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limitrange
  namespace: default
spec:
  limits:
  - default:
      cpu: "500m"
      memory: "1Gi"
    defaultRequest:
      cpu: "100m"
      memory: "256Mi"
    type: Container
```

**Step 3: Create README documenting quota strategy**

File: `core/pcc-app-argo-config/prod/resource-quotas/README.md`

```markdown
# Production ResourceQuotas

## Quota Strategy

**argocd namespace**:
- CPU: 10 cores (supports HA deployment with 2-4 replicas)
- Memory: 20Gi
- Pods: 30 (ArgoCD + Redis HA)

**default namespace**:
- CPU: 20 cores (general workloads)
- Memory: 40Gi
- Pods: 50

**hello-world namespace**:
- CPU: 5 cores (sample app)
- Memory: 10Gi
- Pods: 20

## LimitRange Defaults

Pods without resource requests/limits get:
- CPU request: 100m, limit: 500m
- Memory request: 256Mi, limit: 1Gi

## Autopilot Notes

GKE Autopilot automatically provisions nodes to match requested resources.
These quotas ensure cost control by preventing runaway resource consumption.
```

**Step 4: Commit and push**

```bash
cd ~/pcc/core/pcc-app-argo-config
git add prod/resource-quotas/
git commit -m "feat(phase-7): add production ResourceQuotas and LimitRanges"
git push origin main
```

---

## Chunk Complete Checklist

- [ ] ResourceQuota manifests created for 3 namespaces
- [ ] LimitRange manifests created for 2 namespaces
- [ ] Quota limits appropriate for production (ArgoCD HA requirements)
- [ ] Default resource requests/limits configured
- [ ] README documenting quota strategy
- [ ] Manifests committed and pushed (ArgoCD will auto-sync)
- [ ] Ready for chunk 19 (monitoring)
