# Chunk 9: Configure and Validate Connect Gateway Access

**Status:** pending
**Dependencies:** chunk-008-cluster-validation
**Complexity:** medium
**Estimated Time:** 15 minutes
**Tasks:** 2
**Phase:** Feature Validation
**Story:** STORY-4.6
**Jira:** PCC-280

---

## Task 1: Generate Connect Gateway Kubeconfig

**Agent:** k8s-architect

**Step 1: Generate kubeconfig using Fleet membership**

```bash
gcloud container fleet memberships get-credentials pcc-gke-devops-prod \
  --project=pcc-prj-devops-prod
```

Expected output:
```
Fetching cluster endpoint and auth data.
kubeconfig entry generated for pcc-gke-devops-prod.
```

**Step 2: Verify kubeconfig context**

```bash
kubectl config current-context
```

Expected: `connectgateway_pcc-prj-devops-prod_global_pcc-gke-devops-prod`

**Step 3: Verify kubeconfig uses Connect Gateway**

```bash
kubectl config view --minify | grep server
```

Expected: Server URL contains `connectgateway.googleapis.com` (not direct cluster endpoint)

---

## Task 2: Validate Connect Gateway Access

**Agent:** k8s-architect

**Step 1: Test cluster info access**

```bash
kubectl cluster-info
```

Expected output showing Kubernetes control plane and CoreDNS endpoints

**Step 2: Test namespace listing**

```bash
kubectl get namespaces
```

Expected: Default namespaces (default, kube-system, kube-public, kube-node-lease)

**Step 3: Test IAM authorization**

```bash
# Should succeed with DevOps group IAM binding
kubectl get nodes

# Should succeed with clusterViewer role
kubectl get pods -A --field-selector=metadata.namespace!=kube-system
```

Expected: Commands succeed with appropriate permissions

**Step 4: Document access procedure**

Create `connect-gateway-access-guide.md`:
- Kubeconfig generation command
- Prerequisites (gcloud auth, IAM group membership)
- Verification steps
- Common kubectl commands
- Troubleshooting tips

---

## Chunk Complete Checklist

- [ ] Kubeconfig generated using Connect Gateway
- [ ] Connect Gateway endpoint verified (not direct endpoint)
- [ ] kubectl access validated with test commands
- [ ] IAM authorization working correctly
- [ ] Access procedure documented
- [ ] Ready for chunk 10 (Workload Identity validation)

**Note:** Chunk 9 can run in parallel with chunk 10
