# Chunk 8: Configure RBAC and Ingress

**Status:** pending
**Dependencies:** chunk-007-affinity-security
**Complexity:** medium
**Estimated Time:** 20 minutes
**Tasks:** 3
**Phase:** HA Installation
**Story:** STORY-703
**Jira:** PCC-288

---

## Task 1: Configure Google Workspace Groups RBAC

**Agent:** gitops-engineer

**Step 1: Add RBAC policy to values-prod-autopilot.yaml**

```yaml
server:
  rbacConfig:
    policy.default: role:readonly  # Workaround - NO BL-003 required

    policy.csv: |
      # Admins group
      g, argocd-admins@portcon.com, role:admin

      # DevOps group
      p, role:devops, applications, *, */*, allow
      p, role:devops, projects, *, *, allow
      p, role:devops, clusters, get, *, allow
      p, role:devops, repositories, *, *, allow
      g, argocd-devops@portcon.com, role:devops

      # Developers group
      p, role:developer, applications, sync, */*, allow
      p, role:developer, applications, get, */*, allow
      p, role:developer, projects, get, *, allow
      g, argocd-developers@portcon.com, role:developer

      # Read-only group
      g, argocd-readonly@portcon.com, role:readonly
```

---

## Task 2: Configure Workload Identity Annotations

**Agent:** k8s-architect

**Step 1: Add WI annotations to values-prod-autopilot.yaml**

```yaml
controller:
  serviceAccount:
    annotations:
      iam.gke.io/gcp-service-account: argocd-application-controller@pcc-prj-devops-prod.iam.gserviceaccount.com

repoServer:
  serviceAccount:
    annotations:
      iam.gke.io/gcp-service-account: argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com

server:
  serviceAccount:
    annotations:
      iam.gke.io/gcp-service-account: argocd-server@pcc-prj-devops-prod.iam.gserviceaccount.com
```

---

## Task 3: Configure Ingress with Managed Certificate

**Agent:** gitops-engineer

**Step 1: Add ingress configuration to values-prod-autopilot.yaml**

```yaml
server:
  ingress:
    enabled: true
    ingressClassName: gce

    annotations:
      kubernetes.io/ingress.class: gce
      networking.gke.io/managed-certificates: argocd-prod-tls
      kubernetes.io/ingress.allow-http: "true"

    hosts:
    - argocd-prod.portcon.com

    tls:
    - secretName: argocd-prod-tls
      hosts:
      - argocd-prod.portcon.com
```

**Step 2: Commit RBAC, WI, and ingress configuration**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra
git add environments/prod/helm/values-prod-autopilot.yaml
git commit -m "feat(phase-7): configure RBAC (4 groups), workload identity, ingress"
```

---

## Chunk Complete Checklist

- [ ] RBAC policy configured with 4 groups
- [ ] policy.default: role:readonly workaround configured
- [ ] Workload Identity annotations added (3 service accounts)
- [ ] Ingress configured with managed certificate reference
- [ ] Configuration committed
- [ ] Ready for chunk 9 (pre-flight validation)
