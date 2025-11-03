# Phase 6.9: Enhanced Validation - CRD & Custom Resources

**Tool**: [WARP] Partner Execution
**Estimated Duration**: 25 minutes

## Purpose

Validate ArgoCD Helm manifests against GKE Autopilot policies using a two-phase approach: (1) CRD validation first, (2) custom resource validation with OPA policy scan + kubectl admission dry-run.

## Prerequisites

- Phase 6.8 completed (pre-flight checks passed)
- Helm CLI >= 3.12 installed
- conftest installed (OPA policy tool): `brew install conftest` or equivalent
- values-autopilot.yaml file from Phase 6.5

## Detailed Steps

### Part 1: CRD Validation (10 minutes)

#### Step 1: Add ArgoCD Helm Repository

```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
```

Expected output:
```
"argo" has been added to your repositories
Hang tight while we grab the latest from your chart repositories...
Successfully got an update from the "argo" chart repository
```

#### Step 2: Template CRDs Only

```bash
cd /home/jfogarty/pcc/infra/pcc-devops-infra/argocd-nonprod/devtest

helm template argocd argo/argo-cd \
  --version 9.0.5 \
  --namespace argocd \
  --include-crds \
  -f values-autopilot.yaml \
  | grep -A 10000 "kind: CustomResourceDefinition" \
  > /tmp/argocd-crds.yaml
```

#### Step 3: Validate CRDs with Server-Side Dry-Run

```bash
kubectl apply --dry-run=server -f /tmp/argocd-crds.yaml
```

**Expected Output**:
```
customresourcedefinition.apiextensions.k8s.io/applications.argoproj.io created (dry run)
customresourcedefinition.apiextensions.k8s.io/applicationsets.argoproj.io created (dry run)
customresourcedefinition.apiextensions.k8s.io/appprojects.argoproj.io created (dry run)
```

**HALT if**: Any validation errors appear

### Part 2: Custom Resource Validation (15 minutes)

#### Step 4: Template All Resources

```bash
helm template argocd argo/argo-cd \
  --version 9.0.5 \
  --namespace argocd \
  -f values-autopilot.yaml \
  > /tmp/argocd-manifests.yaml
```

#### Step 5: OPA Policy Scan (Optional but Recommended)

```bash
# Scan for security issues
conftest test /tmp/argocd-manifests.yaml
```

**Expected**: No failures (warnings are acceptable)

**Note**: If conftest not available, skip this step - kubectl admission in Step 6 provides validation.

#### Step 6: Kubernetes Admission Dry-Run

```bash
kubectl apply --dry-run=server -f /tmp/argocd-manifests.yaml
```

**Expected**: All resources validated successfully

Example output:
```
namespace/argocd created (dry run)
serviceaccount/argocd-application-controller created (dry run)
serviceaccount/argocd-server created (dry run)
...
clusterrole.rbac.authorization.k8s.io/argocd-application-controller created (dry run)
...
deployment.apps/argocd-server created (dry run)
```

**Note**: May see warnings about CRDs already existing - this is acceptable.

#### Step 7: Verify Resource Counts

```bash
echo "Total resources:"
grep -c "^kind:" /tmp/argocd-manifests.yaml

echo "Resource breakdown:"
grep "^kind:" /tmp/argocd-manifests.yaml | sort | uniq -c
```

Expected: ~50-70 total resources including:
- ServiceAccounts
- ClusterRoles
- ClusterRoleBindings
- Deployments
- Services
- ConfigMaps
- Secrets

#### Step 8: Verify Autopilot Compliance

Check for resource requests/limits in critical deployments:

```bash
grep -A 5 "kind: Deployment" /tmp/argocd-manifests.yaml | grep -E "(cpu|memory):"
```

**Expected**: All Deployments have resource requests >= Autopilot minimums (250m CPU, 512Mi memory)

## Success Criteria

- ✅ Helm template renders without errors
- ✅ CRDs validate via server-side dry-run
- ✅ OPA policy scan passes (no failures)
- ✅ Admission webhooks validate all resources successfully
- ✅ No Autopilot policy violations
- ✅ Resource requests meet Autopilot minimums
- ✅ Security contexts configured (runAsNonRoot, no privilege escalation)

## HALT Conditions

**HALT if**:
- Helm template command fails
- CRD validation errors
- OPA policy scan shows failures (not warnings)
- Admission webhook denials
- Resources missing requests/limits
- Security context violations

**Resolution**:
- Review values-autopilot.yaml for syntax errors
- Verify chart version 9.0.5 is available: `helm search repo argo/argo-cd --versions`
- Check Autopilot constraints documentation
- Ensure resource limits are set in values-autopilot.yaml
- Verify security contexts match Phase 6.5 configuration

## Next Phase

Proceed to **Phase 6.10**: Install ArgoCD via Helm

## Notes

- This two-phase validation (CRDs first, then custom resources) prevents race conditions
- Server-side dry-run (`--dry-run=server`) validates against admission webhooks and policies
- Client-side dry-run (`--dry-run=client`) only validates syntax - NOT sufficient for Autopilot
- conftest policy scan is optional but recommended for additional security validation
- Validation failures here are MUCH easier to fix than post-installation issues
- This phase makes NO changes to the cluster - purely validation
