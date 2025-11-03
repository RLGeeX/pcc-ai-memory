# Phase 6.11: Validate Workload Identity

**Tool**: [WARP] Partner Execution
**Estimated Duration**: 10 minutes

## Purpose

Test Workload Identity bindings by verifying each ArgoCD pod can authenticate as its assigned GCP service account via the metadata server.

## Prerequisites

- Phase 6.10 completed (ArgoCD installed, all pods running)
- kubectl access to argocd namespace

## Detailed Steps

### Step 1: Test ArgoCD Application Controller

```bash
kubectl exec -n argocd deployment/argocd-application-controller -- \
  curl -sS -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email
```

**Expected**: `argocd-controller@pcc-prj-devops-nonprod.iam.gserviceaccount.com`

### Step 2: Test ArgoCD Server

```bash
kubectl exec -n argocd deployment/argocd-server -- \
  curl -sS -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email
```

**Expected**: `argocd-server@pcc-prj-devops-nonprod.iam.gserviceaccount.com`

### Step 3: Test ArgoCD Dex

```bash
kubectl exec -n argocd deployment/argocd-dex-server -- \
  curl -sS -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email
```

**Expected**: `argocd-dex@pcc-prj-devops-nonprod.iam.gserviceaccount.com`

### Step 4: Test ArgoCD Redis

```bash
kubectl exec -n argocd statefulset/argocd-redis -- \
  sh -c 'curl -sS -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email'
```

**Expected**: `argocd-redis@pcc-prj-devops-nonprod.iam.gserviceaccount.com`

### Step 5: Verify Service Account Annotations

```bash
kubectl get sa -n argocd argocd-application-controller -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}'
```

**Expected**: `argocd-controller@pcc-prj-devops-nonprod.iam.gserviceaccount.com`

Repeat for other service accounts:
```bash
for sa in argocd-server argocd-dex-server argocd-redis; do
  echo "Testing $sa:"
  kubectl get sa -n argocd $sa -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}'
  echo ""
done
```

## Success Criteria

- ✅ All 4 pods return correct GCP service account emails
- ✅ ArgoCD server can generate GCP access tokens
- ✅ All K8s service accounts have correct WI annotations
- ✅ No "permission denied" or "404" errors from metadata server

## HALT Conditions

**HALT if**:
- Metadata server returns 404 (WI not enabled)
- Pods return wrong service account email
- Pods return default compute SA email (WI binding failed)
- gcloud auth list shows no active account

**Resolution**:
- Verify Workload Identity enabled: Phase 6.8 Step 2
- Check service account annotations: `kubectl get sa -n argocd -o yaml`
- Verify Terraform WI bindings: `terraform state list | grep workload_identity`
- Check GCP IAM bindings:
  ```bash
  gcloud iam service-accounts get-iam-policy argocd-server@pcc-prj-devops-nonprod.iam.gserviceaccount.com
  ```
- Restart pods to pick up annotation changes: `kubectl rollout restart deployment/argocd-server -n argocd`

## Next Phase

Proceed to **Phase 6.12**: Extract Admin Password to Secret Manager

## Detailed Validation Guide

### Understanding Workload Identity Test Commands

The metadata server commands test three things:

1. **Pod can reach metadata server**: `http://metadata.google.internal` (resolves to 169.254.169.254)
2. **Metadata server returns correct SA**: Expected format `SA_NAME@PROJECT.iam.gserviceaccount.com`
3. **Not using default compute SA**: Would indicate WI binding failed

**Expected Success Output**:
```
argocd-controller@pcc-prj-devops-nonprod.iam.gserviceaccount.com
```

**Failure Indicators**:
- `404 Not Found`: Workload Identity not enabled on cluster
- `compute-123456@developer.gserviceaccount.com`: Using default compute SA (WI failed)
- `curl: (6) Could not resolve host`: DNS resolution issue
- `curl: (7) Failed to connect`: Network policy blocking metadata server

### Troubleshooting Failed Tests

**If Step 1 fails (Application Controller)**:
```bash
# Check pod is running
kubectl get pod -n argocd -l app.kubernetes.io/name=argocd-application-controller

# Check service account annotation
kubectl get sa argocd-application-controller -n argocd -o yaml | grep iam.gke.io

# Check GCP IAM binding
gcloud iam service-accounts get-iam-policy \
  argocd-controller@pcc-prj-devops-nonprod.iam.gserviceaccount.com \
  --format=json | jq '.bindings[] | select(.role=="roles/iam.workloadIdentityUser")'
```

**If Step 2 fails (Server)**:
```bash
# Check deployment status
kubectl describe deployment argocd-server -n argocd

# Verify Terraform WI binding exists
cd /home/jfogarty/pcc/infra/pcc-devops-infra/argocd-nonprod/devtest
terraform state show 'module.argocd_server_wi.google_service_account_iam_binding.workload_identity'
```

**If returning default compute SA**:
1. Restart the deployment to pick up SA annotations:
   ```bash
   kubectl rollout restart deployment/argocd-server -n argocd
   ```
2. Wait 2 minutes for pods to restart
3. Retry metadata server test

## Notes

- **Why only 4 SAs tested?** Only Application Controller and Server actually use GCP APIs (container.viewer, compute.viewer, logging.logWriter, secretmanager.admin). Dex and Redis have Workload Identity configured for flexibility but don't actively call GCP APIs. ApplicationSet and Notifications controllers don't need GCP access (manage K8s resources only).
- Workload Identity allows pods to authenticate without managing keys
- Metadata server (169.254.169.254) is accessible from all GKE pods
- Default compute SA email indicates WI binding NOT working
- ArgoCD server needs WI working for Phase 6.12 Secret Manager write
- This validation prevents authentication failures in later phases
- **Metadata server endpoint**: `http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email`
- **Required header**: `Metadata-Flavor: Google` (prevents SSRF attacks)
- **Timeout**: Default curl timeout 2 minutes, sufficient for metadata server
