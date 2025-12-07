# Chunk 15: Create App-of-Apps Manifests

**Status:** pending
**Dependencies:** chunk-014-rbac-testing
**Complexity:** simple
**Estimated Time:** 15 minutes
**Tasks:** 2
**Phase:** GitOps Patterns
**Story:** STORY-707
**Jira:** PCC-295

---

## Task 1: Create App-of-Apps Directory Structure

**Agent:** gitops-engineer

**Step 1: Create directory in pcc-app-argo-config repo**

```bash
cd ~/pcc/core/pcc-app-argo-config
mkdir -p prod/argocd-apps prod/network-policies prod/resource-quotas
```

**Step 2: Create root Application manifest**

File: `core/pcc-app-argo-config/prod/root-app.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root-prod
  namespace: argocd
spec:
  project: default

  source:
    repoURL: git@github-pcc:PORTCoCONNECT/pcc-app-argo-config.git
    targetRevision: main
    path: prod/argocd-apps

  destination:
    server: https://kubernetes.default.svc
    namespace: argocd

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

---

## Task 2: Create Child Application Manifests

**Agent:** gitops-engineer

**Step 1: Create NetworkPolicy app**

File: `core/pcc-app-argo-config/prod/argocd-apps/network-policies.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: network-policies-prod
  namespace: argocd
spec:
  project: default

  source:
    repoURL: git@github-pcc:PORTCoCONNECT/pcc-app-argo-config.git
    targetRevision: main
    path: prod/network-policies

  destination:
    server: https://kubernetes.default.svc
    namespace: argocd

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Step 2: Create ResourceQuota app**

File: `core/pcc-app-argo-config/prod/argocd-apps/resource-quotas.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: resource-quotas-prod
  namespace: argocd
spec:
  project: default

  source:
    repoURL: git@github-pcc:PORTCoCONNECT/pcc-app-argo-config.git
    targetRevision: main
    path: prod/resource-quotas

  destination:
    server: https://kubernetes.default.svc
    namespace: argocd

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

**Step 3: Commit app-of-apps manifests**

```bash
cd ~/pcc/core/pcc-app-argo-config
git add prod/
git commit -m "feat(phase-7): create app-of-apps for prod ArgoCD"
git push origin main
```

---

## Chunk Complete Checklist

- [ ] Directory structure created in pcc-app-argo-config
- [ ] Root Application manifest created
- [ ] NetworkPolicy child app manifest created
- [ ] ResourceQuota child app manifest created
- [ ] Automated sync configured (prune, selfHeal)
- [ ] Manifests committed and pushed
- [ ] Ready for chunk 16 (NetworkPolicy manifests)
