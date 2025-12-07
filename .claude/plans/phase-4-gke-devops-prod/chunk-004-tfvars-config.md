# Chunk 4: Create Terraform Variables Values

**Status:** pending
**Dependencies:** chunk-003-main-config
**Complexity:** simple
**Estimated Time:** 10 minutes
**Tasks:** 2
**Phase:** Configuration
**Story:** STORY-4.1
**Jira:** PCC-275

---

## Task 1: Create Terraform.tfvars with Production Values

**Agent:** terraform-specialist
**Files:**
- Create: `infra/pcc-devops-infra/environments/prod/terraform.tfvars`

**Step 1: Write terraform.tfvars with prod values**

File: `infra/pcc-devops-infra/environments/prod/terraform.tfvars`

```hcl
# Production GKE DevOps Cluster Configuration
project_id           = "pcc-prj-devops-prod"
region               = "us-east4"
network_project_id   = "pcc-prj-network-prod"
vpc_network_name     = "pcc-vpc-prod"
gke_subnet_name      = "pcc-prj-devops-prod"
```

**Step 2: Validate configuration values**

Review checklist:
- [ ] project_id is pcc-prj-devops-prod (not nonprod)
- [ ] network_project_id is pcc-prj-network-prod
- [ ] vpc_network_name is pcc-vpc-prod
- [ ] gke_subnet_name matches actual subnet name in shared VPC
- [ ] region is us-east4

**Step 3: Format and commit**

```bash
cd ~/pcc/infra/pcc-devops-infra/environments/prod
terraform fmt terraform.tfvars
git add terraform.tfvars
git commit -m "feat(infra): add terraform.tfvars with prod values"
```

---

## Task 2: Verify Configuration Completeness

**Agent:** terraform-specialist

**Step 1: Check all required files exist**

```bash
cd ~/pcc/infra/pcc-devops-infra/environments/prod
ls -1
```

Expected output:
```
backend.tf
gke.tf
outputs.tf
providers.tf
terraform.tfvars
variables.tf
```

**Step 2: Verify file contents match nonprod structure**

```bash
# Compare with nonprod (should have same files, different values)
diff -q ../nonprod/ ../prod/ --exclude=terraform.tfvars --exclude=iam.tf
```

Expected: Files should have similar structure

---

## Chunk Complete Checklist

- [ ] terraform.tfvars created with correct prod values
- [ ] All project IDs point to prod projects
- [ ] Network configuration references prod shared VPC
- [ ] All required configuration files present
- [ ] Files formatted and committed
- [ ] Ready for chunk 5 (IAM configuration)
