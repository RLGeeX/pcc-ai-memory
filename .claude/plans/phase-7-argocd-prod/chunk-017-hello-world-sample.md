# Chunk 17: Deploy Hello-World Sample Application

**Status:** pending
**Dependencies:** chunk-016-networkpolicy-manifests
**Complexity:** simple
**Estimated Time:** 15 minutes
**Tasks:** 2
**Phase:** GitOps Patterns
**Story:** STORY-707
**Jira:** PCC-297

---

## Task 1: Create Hello-World Application Manifest

**Agent:** gitops-engineer

**Step 1: Create hello-world directory**

```bash
cd ~/pcc/core/pcc-app-argo-config
mkdir -p prod/argocd-apps
```

**Step 2: Create hello-world Application**

File: `core/pcc-app-argo-config/prod/argocd-apps/hello-world.yaml`

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hello-world-prod
  namespace: argocd
spec:
  project: default

  source:
    repoURL: https://github.com/argoproj/argocd-example-apps.git
    targetRevision: HEAD
    path: guestbook

  destination:
    server: https://kubernetes.default.svc
    namespace: hello-world

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
    - CreateNamespace=true
```

**Step 3: Commit and push**

```bash
git add prod/argocd-apps/hello-world.yaml
git commit -m "feat(phase-7): add hello-world sample app for prod validation"
git push origin main
```

---

## Task 2: Deploy Root App and Validate

**Agent:** gitops-engineer

**Step 1: Deploy root application**

```bash
kubectl apply -f ~/pcc/core/pcc-app-argo-config/prod/root-app.yaml -n argocd
```

Expected: "application.argoproj.io/root-prod created"

**Step 2: Wait for apps to sync**

```bash
# Wait for root app to sync (creates child apps)
kubectl wait --for=jsonpath='{.status.health.status}'=Healthy \
  application/root-prod -n argocd --timeout=300s

# Verify child apps created
kubectl get applications -n argocd
```

Expected applications:
- root-prod (Healthy)
- network-policies-prod (Healthy)
- resource-quotas-prod (Synced or Healthy)
- hello-world-prod (Healthy)

**Step 3: Verify hello-world pods running**

```bash
kubectl get pods -n hello-world
```

Expected: guestbook pods in `Running` state

**Step 4: Test egress from hello-world pod**

```bash
# Get pod name
POD=$(kubectl get pods -n hello-world -l app=guestbook-ui -o jsonpath='{.items[0].metadata.name}')

# Test egress connectivity
kubectl exec $POD -n hello-world -- curl -s -o /dev/null -w "%{http_code}" https://google.com
```

Expected: "200" (egress allowed via NetworkPolicy)

---

## Chunk Complete Checklist

- [ ] Hello-world Application manifest created
- [ ] Root app deployed to ArgoCD
- [ ] All child apps synced (network-policies, resource-quotas, hello-world)
- [ ] Hello-world pods running
- [ ] Egress connectivity verified (wide-open policy working)
- [ ] GitOps pattern validated
- [ ] Ready for chunk 18 (resource quotas)
