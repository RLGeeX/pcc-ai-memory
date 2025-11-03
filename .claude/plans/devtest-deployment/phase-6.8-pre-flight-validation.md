# Phase 6.8: Pre-flight Validation

**Tool**: [WARP] Partner Execution
**Estimated Duration**: 10 minutes

## Purpose

Validate GKE Autopilot mode is enabled and Workload Identity is configured before proceeding with ArgoCD installation.

## Prerequisites

- Phase 6.7 completed (infrastructure deployed)
- gcloud CLI authenticated
- kubectl configured for pcc-prj-devops-nonprod cluster

## Detailed Steps

### Step 1: Verify Autopilot Mode Enabled

```bash
gcloud container clusters describe pcc-prj-devops-nonprod \
  --region us-east4 \
  --format='get(autopilot.enabled)'
```

**Expected Output**: `True`

**HALT if**: Output is `False` or empty

### Step 2: Verify Workload Identity Enabled

```bash
gcloud container clusters describe pcc-prj-devops-nonprod \
  --region us-east4 \
  --format='get(workloadIdentityConfig.workloadPool)'
```

**Expected Output**: `pcc-prj-devops-nonprod.svc.id.goog`

**HALT if**: Output is empty

### Step 3: Verify Cluster Health

```bash
kubectl get nodes
```

**Expected Output**: All nodes show STATUS = `Ready`

Example:
```
NAME                                        STATUS   ROLES    AGE   VERSION
gk3-pcc-prj-devops-nonprod-pool-1-abc123   Ready    <none>   5d    v1.29.x
```

### Step 4: Check Cluster Version

```bash
kubectl version --short
```

**Expected**: Kubernetes version >= 1.27

Example output:
```
Client Version: v1.29.1
Server Version: v1.29.3-gke.1282000
```

### Step 5: Verify kubectl Context

```bash
kubectl config current-context
```

**Expected**: Context name contains `pcc-prj-devops-nonprod`

Example: `gke_pcc-prj-devops-nonprod_us-east4_pcc-prj-devops-nonprod`

### Step 6: Verify Namespace Creation Capability

```bash
kubectl auth can-i create namespace
```

**Expected Output**: `yes`

**HALT if**: `no` or `error`

## Success Criteria

- ✅ Autopilot mode = True
- ✅ Workload Identity pool configured correctly
- ✅ All cluster nodes in Ready state
- ✅ Kubernetes version >= 1.27
- ✅ kubectl context points to correct cluster
- ✅ Can create namespaces (for argocd namespace creation)

## HALT Conditions

**HALT if**:
- Autopilot mode is disabled
- Workload Identity not enabled
- Nodes not in Ready state
- K8s version < 1.27
- Wrong kubectl context
- Cannot create namespaces

**Resolution**:
- Verify cluster was created in Phase 3 with Autopilot enabled
- Check Phase 3 GKE configuration for Workload Identity settings
- Wait for nodes to reach Ready state (may take a few minutes after cluster creation)
- Update kubectl and gcloud to latest versions
- Run: `gcloud container clusters get-credentials pcc-prj-devops-nonprod --region us-east4`

## Next Phase

Proceed to **Phase 6.9**: Enhanced Validation - CRD & Custom Resources

## Comprehensive Validation Command Reference

### Quick Validation Script

Run all checks in one command:
```bash
echo "=== Cluster Validation ==="
echo "Autopilot: $(gcloud container clusters describe pcc-prj-devops-nonprod --region us-east4 --format='get(autopilot.enabled)')"
echo "Workload Identity: $(gcloud container clusters describe pcc-prj-devops-nonprod --region us-east4 --format='get(workloadIdentityConfig.workloadPool)')"
echo "K8s Version: $(kubectl version --short 2>&1 | grep Server)"
echo "Context: $(kubectl config current-context)"
echo "Nodes Ready: $(kubectl get nodes --no-headers | wc -l)/$(kubectl get nodes --no-headers | grep Ready | wc -l)"
echo "Can Create NS: $(kubectl auth can-i create namespace)"
echo "=== Infrastructure Validation ==="
echo "Service Accounts: $(gcloud iam service-accounts list --filter='email:argocd-*@pcc-prj-devops-nonprod.iam.gserviceaccount.com' --format='value(email)' | wc -l)/6"
echo "SSL Cert Status: $(gcloud compute ssl-certificates describe argocd-nonprod-cert --global --format='get(managed.status)' 2>/dev/null || echo 'NOT FOUND')"
echo "GCS Bucket: $(gsutil ls gs://pcc-argocd-backups-nonprod 2>&1 | grep -q 'gs://' && echo 'EXISTS' || echo 'NOT FOUND')"
```

**Expected Output**:
```
=== Cluster Validation ===
Autopilot: True
Workload Identity: pcc-prj-devops-nonprod.svc.id.goog
K8s Version: Server Version: v1.29.3-gke.1282000
Context: gke_pcc-prj-devops-nonprod_us-east4_pcc-prj-devops-nonprod
Nodes Ready: 3/3
Can Create NS: yes
=== Infrastructure Validation ===
Service Accounts: 6/6
SSL Cert Status: PROVISIONING
GCS Bucket: EXISTS
```

### Individual Component Validation

**Validate specific service account**:
```bash
# Check SA exists
gcloud iam service-accounts describe argocd-server@pcc-prj-devops-nonprod.iam.gserviceaccount.com

# Check WI binding
gcloud iam service-accounts get-iam-policy argocd-server@pcc-prj-devops-nonprod.iam.gserviceaccount.com \
  --format=json | jq '.bindings[] | select(.role=="roles/iam.workloadIdentityUser")'

# Expected: Shows binding for serviceAccount:pcc-prj-devops-nonprod.svc.id.goog[argocd/argocd-server]
```

**Validate GCS bucket lifecycle**:
```bash
gsutil lifecycle get gs://pcc-argocd-backups-nonprod

# Expected: Shows 3-day deletion rule
```

**Validate IAM permissions**:
```bash
# Check project-level IAM for argocd-server
gcloud projects get-iam-policy pcc-prj-devops-nonprod \
  --flatten="bindings[].members" \
  --filter="bindings.members:serviceAccount:argocd-server@pcc-prj-devops-nonprod.iam.gserviceaccount.com" \
  --format="table(bindings.role)"

# Expected roles:
# - roles/container.viewer
# - roles/compute.viewer
# - roles/logging.logWriter
# - roles/secretmanager.admin
```

**Test cluster connectivity**:
```bash
# Verify API server reachable
kubectl cluster-info

# Check control plane version
kubectl version --output=json | jq '.serverVersion'

# List all API resources (validates API server health)
kubectl api-resources | wc -l

# Expected: ~100+ resources
```

**Verify Autopilot restrictions**:
```bash
# Check node taints (Autopilot adds specific taints)
kubectl get nodes -o json | jq '.items[].spec.taints'

# Expected: cloud.google.com/gke-autopilot=true:NoSchedule

# Verify managed namespaces
kubectl get ns kube-system -o json | jq '.metadata.labels'

# Expected: addonmanager.kubernetes.io/mode=Reconcile
```

### Troubleshooting Commands

**If Workload Identity check fails**:
```bash
# Check if workload identity addon is enabled
gcloud container clusters describe pcc-prj-devops-nonprod \
  --region us-east4 \
  --format='get(addonsConfig.gcpWorkloadIdentityEnabled)'

# Expected: True

# If False, cannot enable on existing cluster - must recreate
```

**If nodes not Ready**:
```bash
# Check node conditions
kubectl describe nodes | grep -A5 "Conditions:"

# Check for resource pressure
kubectl top nodes

# View node events
kubectl get events --all-namespaces --sort-by='.lastTimestamp' | grep -i node
```

**If kubectl context wrong**:
```bash
# List all contexts
kubectl config get-contexts

# Switch context
kubectl config use-context gke_pcc-prj-devops-nonprod_us-east4_pcc-prj-devops-nonprod

# Or fetch fresh credentials
gcloud container clusters get-credentials pcc-prj-devops-nonprod --region us-east4
```

### Copy-Paste Validation Blocks

**Full pre-flight check** (copy entire block):
```bash
#!/bin/bash
set -e

echo "🔍 Running pre-flight validation..."

# Test 1: Autopilot
AUTOPILOT=$(gcloud container clusters describe pcc-prj-devops-nonprod --region us-east4 --format='get(autopilot.enabled)')
[[ "$AUTOPILOT" == "True" ]] && echo "✅ Autopilot: Enabled" || { echo "❌ Autopilot: Disabled"; exit 1; }

# Test 2: Workload Identity
WI_POOL=$(gcloud container clusters describe pcc-prj-devops-nonprod --region us-east4 --format='get(workloadIdentityConfig.workloadPool)')
[[ ! -z "$WI_POOL" ]] && echo "✅ Workload Identity: $WI_POOL" || { echo "❌ Workload Identity: Not configured"; exit 1; }

# Test 3: Nodes Ready
READY_NODES=$(kubectl get nodes --no-headers | grep Ready | wc -l)
TOTAL_NODES=$(kubectl get nodes --no-headers | wc -l)
[[ "$READY_NODES" -eq "$TOTAL_NODES" ]] && echo "✅ Nodes: $READY_NODES/$TOTAL_NODES Ready" || { echo "❌ Nodes: $READY_NODES/$TOTAL_NODES Ready"; exit 1; }

# Test 4: Namespace Creation
CAN_CREATE=$(kubectl auth can-i create namespace)
[[ "$CAN_CREATE" == "yes" ]] && echo "✅ Permissions: Can create namespaces" || { echo "❌ Permissions: Cannot create namespaces"; exit 1; }

# Test 5: Service Accounts
SA_COUNT=$(gcloud iam service-accounts list --filter='email:argocd-*@pcc-prj-devops-nonprod.iam.gserviceaccount.com OR email:externaldns@pcc-prj-devops-nonprod.iam.gserviceaccount.com OR email:velero@pcc-prj-devops-nonprod.iam.gserviceaccount.com' --format='value(email)' | wc -l)
[[ "$SA_COUNT" -eq 6 ]] && echo "✅ Service Accounts: 6/6 created" || { echo "⚠️ Service Accounts: $SA_COUNT/6 created"; }

echo ""
echo "✅ Pre-flight validation PASSED"
echo "Proceed to Phase 6.9"
```

## Notes

- Autopilot mode is immutable - cannot be changed after cluster creation
- Workload Identity is required for ArgoCD pods to authenticate as GCP service accounts
- This validation prevents installation failures by catching configuration issues early
- If any check fails, do NOT proceed to Phase 6.9 - fix the underlying issue first
- **Save validation script**: Store in `~/scripts/validate-argocd-preflight.sh` for reuse
- **Run before upgrades**: Re-run this validation before major ArgoCD upgrades
- **Timeout values**: Most gcloud commands timeout after 30s, kubectl after 1m
