# Chunk 10: Validate Workload Identity Configuration

**Status:** pending
**Dependencies:** chunk-008-cluster-validation
**Complexity:** medium
**Estimated Time:** 20 minutes
**Tasks:** 3
**Phase:** Feature Validation
**Story:** STORY-4.7
**Jira:** PCC-305

---

## Task 1: Verify Workload Identity Pool Configuration

**Agent:** k8s-security

**Step 1: Check Workload Identity pool**

```bash
gcloud container clusters describe pcc-gke-devops-prod \
  --region=us-east4 \
  --project=pcc-prj-devops-prod \
  --format="value(workloadIdentityConfig.workloadPool)"
```

Expected: `pcc-prj-devops-prod.svc.id.goog`

**Step 2: Verify GKE metadata server enabled**

```bash
kubectl get daemonsets -n kube-system | grep metadata-proxy
```

Expected: `metadata-proxy-v0.x` daemonset running

---

## Task 2: Deploy Test Workload to Validate Workload Identity

**Agent:** k8s-security

**Step 1: Create test namespace**

```bash
kubectl create namespace wi-test
```

**Step 2: Create test Kubernetes ServiceAccount**

```bash
kubectl create serviceaccount wi-test-sa -n wi-test
```

**Step 3: Create test GCP ServiceAccount**

```bash
gcloud iam service-accounts create wi-test-sa \
  --display-name="Workload Identity Test SA" \
  --project=pcc-prj-devops-prod
```

**Step 4: Bind K8s SA to GCP SA**

```bash
gcloud iam service-accounts add-iam-policy-binding \
  wi-test-sa@pcc-prj-devops-prod.iam.gserviceaccount.com \
  --role=roles/iam.workloadIdentityUser \
  --member="serviceAccount:pcc-prj-devops-prod.svc.id.goog[wi-test/wi-test-sa]" \
  --project=pcc-prj-devops-prod
```

**Step 5: Annotate K8s ServiceAccount**

```bash
kubectl annotate serviceaccount wi-test-sa \
  -n wi-test \
  iam.gke.io/gcp-service-account=wi-test-sa@pcc-prj-devops-prod.iam.gserviceaccount.com
```

**Step 6: Deploy test pod**

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: wi-test-pod
  namespace: wi-test
spec:
  serviceAccountName: wi-test-sa
  containers:
  - name: workload-identity-test
    image: google/cloud-sdk:slim
    command: ["sleep", "3600"]
EOF
```

---

## Task 3: Validate Workload Identity Functionality

**Agent:** k8s-security

**Step 1: Wait for pod to be ready**

```bash
kubectl wait --for=condition=ready pod/wi-test-pod -n wi-test --timeout=60s
```

**Step 2: Test GCP credential access**

```bash
kubectl exec -it wi-test-pod -n wi-test -- gcloud auth list
```

Expected: Shows `wi-test-sa@pcc-prj-devops-prod.iam.gserviceaccount.com` as active account

**Step 3: Verify metadata server response**

```bash
kubectl exec -it wi-test-pod -n wi-test -- \
  curl -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email
```

Expected: `wi-test-sa@pcc-prj-devops-prod.iam.gserviceaccount.com`

**Step 4: Clean up test resources**

```bash
kubectl delete namespace wi-test
gcloud iam service-accounts delete wi-test-sa@pcc-prj-devops-prod.iam.gserviceaccount.com \
  --project=pcc-prj-devops-prod \
  --quiet
```

**Step 5: Document Workload Identity pattern**

Create `workload-identity-setup-guide.md`:
- GCP SA creation
- K8s SA creation
- IAM binding (workloadIdentityUser role)
- K8s SA annotation
- Validation steps
- Common issues and troubleshooting

---

## Chunk Complete Checklist

- [ ] Workload Identity pool verified
- [ ] Test workload deployed successfully
- [ ] GCP credentials accessible from pod
- [ ] Metadata server working correctly
- [ ] Test resources cleaned up
- [ ] Workload Identity pattern documented
- [ ] Ready for chunk 11 (documentation)

**Note:** Chunk 10 can run in parallel with chunk 9
