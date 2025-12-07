# Chunk 9: Create Pre-Flight Validation Script

**Status:** pending
**Dependencies:** chunk-008-rbac-ingress-config
**Complexity:** simple
**Estimated Time:** 15 minutes
**Tasks:** 2
**Phase:** HA Installation
**Story:** STORY-704
**Jira:** PCC-289

---

## Task 1: Create Pre-Flight Validation Script

**Agent:** k8s-architect

**Step 1: Create preflight script**

File: `environments/prod/scripts/preflight-prod.sh`

```bash
#!/bin/bash
set -e

echo "=== ArgoCD Production Pre-Flight Checks ==="

# Check 1: Cluster access via Connect Gateway
echo "[1/5] Verifying cluster access..."
if kubectl get nodes &>/dev/null; then
  echo "✓ Cluster accessible via Connect Gateway"
else
  echo "✗ Cannot access cluster. Run: gcloud container fleet memberships get-credentials pcc-gke-devops-prod --project=pcc-prj-devops-prod"
  exit 1
fi

# Check 2: Verify Autopilot mode
echo "[2/5] Verifying Autopilot mode..."
AUTOPILOT=$(gcloud container clusters describe pcc-gke-devops-prod \
  --region=us-east4 \
  --project=pcc-prj-devops-prod \
  --format="value(autopilot.enabled)")

if [ "$AUTOPILOT" = "True" ]; then
  echo "✓ Autopilot mode enabled"
else
  echo "✗ Autopilot mode not enabled"
  exit 1
fi

# Check 3: Verify Workload Identity enabled
echo "[3/5] Verifying Workload Identity..."
WI_POOL=$(gcloud container clusters describe pcc-gke-devops-prod \
  --region=us-east4 \
  --project=pcc-prj-devops-prod \
  --format="value(workloadIdentityConfig.workloadPool)")

if [ "$WI_POOL" = "pcc-prj-devops-prod.svc.id.goog" ]; then
  echo "✓ Workload Identity configured"
else
  echo "✗ Workload Identity not configured correctly"
  exit 1
fi

# Check 4: Verify namespace creation
echo "[4/5] Creating argocd namespace..."
if kubectl get namespace argocd &>/dev/null; then
  echo "✓ argocd namespace exists"
else
  kubectl create namespace argocd
  echo "✓ argocd namespace created"
fi

# Check 5: Verify Helm chart available
echo "[5/5] Verifying Helm chart..."
if helm search repo argo/argo-cd --version 7.7.11 &>/dev/null; then
  echo "✓ ArgoCD Helm chart 7.7.11 available"
else
  echo "Adding Argo Helm repo..."
  helm repo add argo https://argoproj.github.io/argo-helm
  helm repo update
  echo "✓ Argo Helm repo added"
fi

echo ""
echo "=== Pre-Flight Checks Complete ==="
echo "Ready to install ArgoCD 7.7.11"
```

**Step 2: Make script executable**

```bash
chmod +x environments/prod/scripts/preflight-prod.sh
```

---

## Task 2: Execute Pre-Flight Checks

**Agent:** k8s-architect

**Step 1: Run pre-flight script**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra
./environments/prod/scripts/preflight-prod.sh
```

Expected output:
```
=== ArgoCD Production Pre-Flight Checks ===
[1/5] Verifying cluster access...
✓ Cluster accessible via Connect Gateway
[2/5] Verifying Autopilot mode...
✓ Autopilot mode enabled
[3/5] Verifying Workload Identity...
✓ Workload Identity configured
[4/5] Creating argocd namespace...
✓ argocd namespace created
[5/5] Verifying Helm chart...
✓ ArgoCD Helm chart 7.7.11 available

=== Pre-Flight Checks Complete ===
Ready to install ArgoCD 7.7.11
```

**Step 2: Commit preflight script**

```bash
git add environments/prod/scripts/preflight-prod.sh
git commit -m "feat(phase-7): add preflight validation script for prod deployment"
```

---

## Chunk Complete Checklist

- [ ] Pre-flight script created
- [ ] Script validates: cluster access, Autopilot, WI, namespace, Helm chart
- [ ] Script executed successfully
- [ ] All 5 checks passed
- [ ] argocd namespace created
- [ ] Script committed
- [ ] Ready for chunk 10 (Helm install)
