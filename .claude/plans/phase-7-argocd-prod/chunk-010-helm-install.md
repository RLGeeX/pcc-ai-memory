# Chunk 10: Install ArgoCD with Merged Validation

**Status:** pending
**Dependencies:** chunk-009-preflight-validation
**Complexity:** medium
**Estimated Time:** 30 minutes
**Tasks:** 3
**Phase:** HA Installation
**Story:** STORY-704
**Jira:** PCC-290

---

## Task 1: Merged Validation (Helm Template + Policy Scan + Dry-Run)

**Agent:** gitops-engineer

**Step 1: Helm template validation**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra/environments/prod
helm template argocd argo/argo-cd \
  --version 7.7.11 \
  --namespace argocd \
  -f helm/values-prod-autopilot.yaml \
  --validate > /tmp/argocd-prod-manifests.yaml
```

Expected: No errors, manifests rendered successfully

**Step 2: Policy scan (allow wide-open egress)**

```bash
# Verify NetworkPolicy allows all egress (if present)
grep -A10 "kind: NetworkPolicy" /tmp/argocd-prod-manifests.yaml | grep -A5 "egress"
# Expected: egress: [{}] (allow all) or no NetworkPolicy yet
```

**Step 3: Admission controller dry-run**

```bash
kubectl apply -f /tmp/argocd-prod-manifests.yaml --dry-run=server
```

Expected: "created (server dry run)" for all resources, no admission errors

---

## Task 2: Helm Install ArgoCD

**Agent:** gitops-engineer

**Step 1: Install ArgoCD 7.7.11**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra/environments/prod

helm install argocd argo/argo-cd \
  --version 7.7.11 \
  --namespace argocd \
  -f helm/values-prod-autopilot.yaml \
  --create-namespace \
  --timeout 10m
```

Expected: "STATUS: deployed"

**Step 2: Wait for pods to be ready**

```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server \
  -n argocd --timeout=300s

kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-repo-server \
  -n argocd --timeout=300s

kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-application-controller \
  -n argocd --timeout=300s
```

Expected: All pods ready within 5 minutes

---

## Task 3: Validate HA Deployment

**Agent:** k8s-architect

**Step 1: Verify replica counts**

```bash
# Verify controller replicas
kubectl get deployment argocd-application-controller -n argocd \
  -o jsonpath='{.spec.replicas}'
# Expected: 2

# Verify repo server replicas
kubectl get deployment argocd-repo-server -n argocd \
  -o jsonpath='{.spec.replicas}'
# Expected: 2

# Verify API server replicas
kubectl get deployment argocd-server -n argocd \
  -o jsonpath='{.spec.replicas}'
# Expected: 2
```

**Step 2: Verify Redis HA pods**

```bash
kubectl get pods -n argocd | grep redis-ha
# Expected: 3 redis-ha-server pods, 3 redis-ha-haproxy pods
```

**Step 3: Verify all pods running**

```bash
kubectl get pods -n argocd
```

Expected: All pods in `Running` state

**Step 4: Document deployment**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra
echo "# ArgoCD Production Deployment" > environments/prod/docs/deployment-notes.md
echo "" >> environments/prod/docs/deployment-notes.md
echo "## Deployment Date: $(date)" >> environments/prod/docs/deployment-notes.md
echo "## Version: 7.7.11" >> environments/prod/docs/deployment-notes.md
echo "## Configuration: HA (2 replicas controller/repo/server, Redis HA 3 replicas)" >> environments/prod/docs/deployment-notes.md

git add environments/prod/docs/deployment-notes.md
git commit -m "feat(phase-7): deploy ArgoCD 7.7.11 with HA configuration to prod"
```

---

## Chunk Complete Checklist

- [ ] Merged validation passed (template + policy + dry-run)
- [ ] ArgoCD 7.7.11 installed successfully
- [ ] Controller replicas = 2
- [ ] Repo server replicas = 2
- [ ] API server replicas = 2
- [ ] Redis HA pods running (3 server + 3 haproxy)
- [ ] All pods in Running state
- [ ] Deployment documented
- [ ] Ready for chunk 11 (Ingress and DNS)
