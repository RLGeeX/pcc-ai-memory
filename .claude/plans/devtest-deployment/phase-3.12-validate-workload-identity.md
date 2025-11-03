# Phase 3.12: Validate Workload Identity

**Phase**: 3.12 (GKE Infrastructure - Workload Identity Validation)
**Duration**: 10 minutes
**Type**: Validation
**Status**: Ready for Execution

---

## Execution Tool

**Use WARP for this phase** - kubectl and GCloud commands.

---

## Objective

Validate Workload Identity feature is enabled in GKE cluster. **Note**: This validates the **feature flag only**, not IAM bindings. IAM bindings will be configured in Phase 6 (ArgoCD deployment).

## Prerequisites

✅ Phase 3.11 completed (Connect Gateway configured)
✅ kubectl access to cluster
✅ Workload Identity enabled in module (Phase 3.8)

---

## Step 1: Verify Workload Identity Pool

```bash
gcloud container clusters describe pcc-gke-devops-nonprod \
  --region=us-east4 \
  --project=pcc-prj-devops-nonprod \
  --format="value(workloadIdentityConfig.workloadPool)"
```

**Expected Output**:
```
pcc-prj-devops-nonprod.svc.id.goog
```

✅ Workload Identity pool configured

---

## Step 2: Check Cluster Workload Identity Status

```bash
kubectl get nodes -o jsonpath='{.items[0].status.nodeInfo.kubeletVersion}'
```

**Expected**: Version 1.28+ (supports Workload Identity)

```bash
kubectl get mutatingwebhookconfigurations
```

**Expected Output**: Should include `pod-ready.common-webhooks.networking.gke.io`

✅ Workload Identity webhooks active

---

## Step 3: Test Workload Identity (Feature Flag Only)

Create a test pod to verify Workload Identity infrastructure:

```bash
kubectl run test-workload-identity \
  --image=google/cloud-sdk:slim \
  --restart=Never \
  --command -- sleep 3600
```

Wait for pod to start:
```bash
kubectl wait --for=condition=Ready pod/test-workload-identity --timeout=60s
```

Check pod environment:
```bash
kubectl exec test-workload-identity -- env | grep GOOGLE
```

**Expected Output**:
```
GOOGLE_APPLICATION_CREDENTIALS=/var/run/secrets/workload-identity/token
```

**Note**: Token path exists but will return auth error without IAM bindings. This is **expected** and correct.

---

## Step 4: Verify Metadata Server Availability

```bash
kubectl exec test-workload-identity -- curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/
```

**Expected Output**:
```
default/
```

✅ Metadata server accessible from pods

**Important**: Accessing GCP APIs will fail without IAM bindings. This is **expected** at this phase.

---

## Step 5: Validate ServiceAccount Annotation Support

Create a test ServiceAccount with Workload Identity annotation:

```bash
kubectl create serviceaccount test-wi-sa

kubectl annotate serviceaccount test-wi-sa \
  iam.gke.io/gcp-service-account=test-sa@pcc-prj-devops-nonprod.iam.gserviceaccount.com
```

Verify annotation:
```bash
kubectl get serviceaccount test-wi-sa -o yaml
```

**Expected Output**:
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  annotations:
    iam.gke.io/gcp-service-account: test-sa@pcc-prj-devops-nonprod.iam.gserviceaccount.com
  name: test-wi-sa
  namespace: default
```

✅ Workload Identity annotation supported

---

## Step 6: Cleanup Test Resources

```bash
kubectl delete pod test-workload-identity
kubectl delete serviceaccount test-wi-sa
```

---

## Validation Checklist

- [ ] Workload Identity pool: `pcc-prj-devops-nonprod.svc.id.goog`
- [ ] Kubelet version 1.28+
- [ ] Workload Identity webhooks active
- [ ] Test pod can access metadata server
- [ ] `GOOGLE_APPLICATION_CREDENTIALS` env var present
- [ ] ServiceAccount annotations supported
- [ ] Test resources cleaned up

---

## What We Validated

✅ **Feature Flag Enabled**: Workload Identity infrastructure is active
✅ **Metadata Server**: Pods can reach GCP metadata server
✅ **Annotation Support**: Kubernetes supports Workload Identity annotations

---

## What We Did NOT Validate

❌ **IAM Bindings**: Not configured yet (Phase 6)
❌ **GCP API Access**: Will fail without IAM bindings (expected)
❌ **Pod Authentication**: Cannot authenticate to GCP yet (expected)

**Why**: IAM bindings are service-specific and will be created when deploying ArgoCD in Phase 6.

---

## Expected Behavior Without IAM Bindings

If you test GCP API access now:

```bash
kubectl exec test-workload-identity -- gcloud auth list
```

**Expected Error**:
```
ERROR: (gcloud.auth.list) Failed to retrieve credentials
```

**This is CORRECT**. IAM bindings will be added in Phase 6.

---

## Workload Identity Pattern (ADR-005)

**Phase 3 (Current)**:
- ✅ Enable Workload Identity feature flag
- ✅ Configure cluster with Workload Identity pool
- ✅ Verify infrastructure ready

**Phase 6 (Future)**:
- 🔵 Create GCP Service Accounts
- 🔵 Create IAM bindings (KSA ↔ GSA) using `iam-member` module
- 🔵 Annotate Kubernetes ServiceAccounts
- 🔵 Test pod-level GCP authentication

---

## Phase 3 Completion

**Phase 3 Complete**: GKE DevOps NonProd cluster fully validated
- ✅ Cluster running in Autopilot mode
- ✅ Connect Gateway configured
- ✅ Workload Identity enabled

**Next Steps**: Phase 4 will configure ArgoCD and CI/CD pipelines

---

## References

- **Workload Identity**: https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity
- **ADR-005**: Workload Identity Pattern
- **GKE Metadata Server**: https://cloud.google.com/kubernetes-engine/docs/concepts/workload-identity#metadata_server

---

## Time Estimate

- **Verify pool**: 2 minutes
- **Check cluster status**: 2 minutes
- **Test pod**: 4 minutes
- **ServiceAccount test**: 2 minutes
- **Cleanup**: 1 minute
- **Total**: 10 minutes

---

**Status**: Ready for execution
**Next**: Phase 4 - Configure ArgoCD and CI/CD (TBD)
