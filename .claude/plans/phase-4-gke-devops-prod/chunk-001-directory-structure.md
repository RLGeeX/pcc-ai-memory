# Chunk 1: Create Directory Structure and Backend Config

**Status:** pending
**Dependencies:** none
**Complexity:** simple
**Estimated Time:** 10-15 minutes
**Tasks:** 2
**Phase:** Configuration
**Story:** STORY-4.1
**Jira:** PCC-272

---

## Task 1: Create Production Environment Directory Structure

**Agent:** terraform-specialist
**Files:**
- Create: `infra/pcc-devops-infra/environments/prod/`
- Create: `infra/pcc-devops-infra/environments/prod/.gitkeep`

**Step 1: Create prod environment directory**

```bash
cd ~/pcc/infra/pcc-devops-infra
mkdir -p environments/prod
touch environments/prod/.gitkeep
```

**Step 2: Verify directory structure**

```bash
tree environments/
```

Expected output:
```
environments/
├── nonprod/
│   ├── backend.tf
│   ├── gke.tf
│   ├── iam.tf
│   ├── outputs.tf
│   ├── providers.tf
│   ├── terraform.tfvars
│   └── variables.tf
└── prod/
    └── .gitkeep
```

---

## Task 2: Create Backend Configuration

**Agent:** terraform-specialist
**Files:**
- Create: `infra/pcc-devops-infra/environments/prod/backend.tf`

**Step 1: Write backend configuration**

File: `infra/pcc-devops-infra/environments/prod/backend.tf`

```hcl
terraform {
  backend "gcs" {
    bucket = "pcc-tf-state-prod"
    prefix = "devops-infra/prod"
  }
}
```

**Step 2: Validate file syntax**

```bash
cd environments/prod
terraform fmt backend.tf
```

Expected: File formatted (no changes or formatting applied)

**Step 3: Commit**

```bash
git add environments/prod/backend.tf environments/prod/.gitkeep
git commit -m "feat(infra): add prod environment structure and backend config for Phase 4"
```

---

## Chunk Complete Checklist

- [ ] Directory structure created
- [ ] Backend config file created with correct GCS bucket
- [ ] Files formatted with terraform fmt
- [ ] Changes committed to git
- [ ] Ready for chunk 2 (providers.tf)
