# Chunk 6: Initialize Terraform and Validate Configuration

**Status:** pending
**Dependencies:** chunk-005-iam-config
**Complexity:** simple
**Estimated Time:** 10 minutes
**Tasks:** 3
**Phase:** Validation & Deployment
**Story:** STORY-4.3
**Jira:** PCC-277

---

## Task 1: Initialize Terraform State

**Agent:** terraform-specialist

**Step 1: Run terraform init**

```bash
cd ~/pcc/infra/pcc-devops-infra/environments/prod
terraform init -upgrade
```

Expected output:
```
Initializing the backend...
Successfully configured the backend "gcs"!
...
Terraform has been successfully initialized!
```

**Step 2: Verify backend state location**

```bash
# Check state bucket and prefix
grep -A 2 'backend "gcs"' backend.tf
```

Expected:
```
backend "gcs" {
  bucket = "pcc-tf-state-prod"
  prefix = "devops-infra/prod"
}
```

---

## Task 2: Validate Terraform Configuration

**Agent:** terraform-specialist

**Step 1: Run terraform validate**

```bash
terraform validate
```

Expected: `Success! The configuration is valid.`

**Step 2: Check formatting**

```bash
terraform fmt -check -recursive
```

Expected: No output (all files already formatted)

---

## Task 3: Generate and Review Terraform Plan

**Agent:** terraform-specialist

**Step 1: Generate plan**

```bash
terraform plan -out=tfplan
```

Expected resources:
- `google_container_cluster.cluster` (create)
- `google_gke_hub_membership.cluster` (create)
- `google_project_iam_member` resources (2: gatewayAdmin, clusterViewer) (create)

**Step 2: Review plan for deletion protection**

```bash
terraform show tfplan | grep deletion_protection
```

Expected: `deletion_protection = true` (because environment = "prod")

**Step 3: Save plan output for approval**

```bash
terraform show tfplan > tfplan.txt
```

**Step 4: Document plan review**

Create checklist:
- [ ] ~3-4 resources to be created (cluster, hub membership, 2 IAM bindings)
- [ ] Deletion protection enabled (prod environment)
- [ ] No unexpected deletions or modifications
- [ ] Cluster name is pcc-gke-devops-prod
- [ ] Region is us-east4
- [ ] Release channel is STABLE
- [ ] Workload Identity enabled
- [ ] Connect Gateway enabled

---

## Chunk Complete Checklist

- [ ] Terraform initialized with GCS backend
- [ ] Configuration validated successfully
- [ ] Plan generated and reviewed
- [ ] Deletion protection confirmed enabled
- [ ] Plan saved for approval and audit
- [ ] No unexpected resource changes
- [ ] Ready for chunk 7 (terraform apply)
