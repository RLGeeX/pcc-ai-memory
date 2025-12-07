# Chunk 5: Configure IAM Bindings for Connect Gateway

**Status:** pending
**Dependencies:** chunk-004-tfvars-config
**Complexity:** simple
**Estimated Time:** 15 minutes
**Tasks:** 2
**Phase:** Configuration
**Story:** STORY-4.2
**Jira:** PCC-276

---

## Task 1: Create IAM Configuration File

**Agent:** terraform-specialist
**Files:**
- Create: `infra/pcc-devops-infra/environments/prod/iam.tf`

**Step 1: Write IAM configuration for Connect Gateway access**

File: `infra/pcc-devops-infra/environments/prod/iam.tf`

```hcl
# IAM bindings for GKE Connect Gateway access - DevOps team
module "connect_gateway_iam" {
  source = "git@github-pcc:PORTCoCONNECT/pcc-tf-library.git//modules/iam-member?ref=v0.1.0"

  project = var.project_id

  # DevOps team members need Connect Gateway access
  members = [
    "group:gcp-devops@pcconnect.ai",
  ]

  # Required roles for Connect Gateway kubectl access
  roles = [
    "roles/gkehub.gatewayAdmin",  # Connect Gateway access
    "roles/container.clusterViewer",  # View cluster metadata
  ]
}
```

**Step 2: Format configuration**

```bash
cd ~/pcc/infra/pcc-devops-infra/environments/prod
terraform fmt iam.tf
```

Expected: File formatted correctly

---

## Task 2: Validate and Commit IAM Configuration

**Agent:** terraform-specialist

**Step 1: Verify IAM configuration correctness**

Review checklist:
- [ ] Group email is correct: gcp-devops@pcconnect.ai
- [ ] gatewayAdmin role grants Connect Gateway access
- [ ] clusterViewer role grants read-only cluster access
- [ ] Non-authoritative IAM binding (won't affect other members)

**Step 2: Commit IAM configuration**

```bash
git add iam.tf
git commit -m "feat(infra): add IAM bindings for Connect Gateway access in prod

- Grant gcp-devops@pcconnect.ai group Connect Gateway access
- Roles: gkehub.gatewayAdmin, container.clusterViewer
- Non-authoritative bindings via iam-member module"
```

**Step 3: Verify all configuration files ready**

```bash
git status
```

Expected: Working directory clean, all Phase 4.1-4.2 files committed

---

## Chunk Complete Checklist

- [ ] IAM configuration created with Connect Gateway roles
- [ ] DevOps team group configured for cluster access
- [ ] Non-authoritative IAM bindings used
- [ ] Files formatted and committed
- [ ] Configuration phase complete (chunks 1-5)
- [ ] Ready for chunk 6 (terraform validation)
