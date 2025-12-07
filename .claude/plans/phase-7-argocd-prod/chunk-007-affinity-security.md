# Chunk 7: Configure Pod Affinity and Security Contexts

**Status:** pending
**Dependencies:** chunk-006-ha-helm-values
**Complexity:** simple
**Estimated Time:** 15 minutes
**Tasks:** 2
**Phase:** HA Installation
**Story:** STORY-703
**Jira:** PCC-287

---

## Task 1: Configure Pod Anti-Affinity

**Agent:** k8s-architect

**Step 1: Add anti-affinity rules to values-prod-autopilot.yaml**

```yaml
controller:
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app.kubernetes.io/name
              operator: In
              values:
              - argocd-application-controller
          topologyKey: kubernetes.io/hostname

repoServer:
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app.kubernetes.io/name
              operator: In
              values:
              - argocd-repo-server
          topologyKey: kubernetes.io/hostname

server:
  affinity:
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: app.kubernetes.io/name
              operator: In
              values:
              - argocd-server
          topologyKey: kubernetes.io/hostname
```

---

## Task 2: Configure Security Contexts

**Agent:** k8s-security

**Step 1: Add security contexts to values-prod-autopilot.yaml**

```yaml
controller:
  containerSecurityContext:
    runAsNonRoot: true
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    capabilities:
      drop:
      - ALL

repoServer:
  containerSecurityContext:
    runAsNonRoot: true
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    capabilities:
      drop:
      - ALL

server:
  containerSecurityContext:
    runAsNonRoot: true
    readOnlyRootFilesystem: true
    allowPrivilegeEscalation: false
    capabilities:
      drop:
      - ALL
```

**Step 2: Commit affinity and security configuration**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra
git add environments/prod/helm/values-prod-autopilot.yaml
git commit -m "feat(phase-7): add pod anti-affinity and security contexts for HA"
```

---

## Chunk Complete Checklist

- [ ] Pod anti-affinity configured for controller, repo, server
- [ ] Security contexts configured (runAsNonRoot, readOnlyRootFilesystem)
- [ ] Capabilities dropped (drop: ALL)
- [ ] Configuration committed
- [ ] Ready for chunk 8 (RBAC and ingress)
