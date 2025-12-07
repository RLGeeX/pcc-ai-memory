# Chunk 2: Create GCS Backup Bucket Module

**Status:** pending
**Dependencies:** chunk-001-copy-terraform-modules
**Complexity:** simple
**Estimated Time:** 15 minutes
**Tasks:** 2
**Phase:** Infrastructure Foundation
**Story:** STORY-701
**Jira:** PCC-282

---

## Task 1: Create GCS Backup Bucket Module

**Agent:** terraform-specialist

**Step 1: Create module directory**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra/modules
mkdir -p gcs-backup-bucket
```

**Step 2: Create main.tf**

File: `modules/gcs-backup-bucket/main.tf`

```hcl
resource "google_storage_bucket" "backup" {
  name          = var.bucket_name
  project       = var.project_id
  location      = var.region
  force_destroy = false  # Production protection

  uniform_bucket_level_access = true

  lifecycle_rule {
    condition {
      age = var.retention_days
    }
    action {
      type = "Delete"
    }
  }

  versioning {
    enabled = true
  }
}
```

**Step 3: Create variables.tf**

File: `modules/gcs-backup-bucket/variables.tf`

```hcl
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "bucket_name" {
  description = "GCS bucket name for backups"
  type        = string
}

variable "region" {
  description = "GCS bucket region"
  type        = string
  default     = "us-east4"
}

variable "retention_days" {
  description = "Backup retention in days"
  type        = number
  default     = 14
}
```

**Step 4: Create outputs.tf**

File: `modules/gcs-backup-bucket/outputs.tf`

```hcl
output "bucket_name" {
  description = "Name of the backup bucket"
  value       = google_storage_bucket.backup.name
}

output "bucket_url" {
  description = "URL of the backup bucket"
  value       = google_storage_bucket.backup.url
}
```

---

## Task 2: Validate and Commit Module

**Agent:** terraform-specialist

**Step 1: Validate module syntax**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra/modules/gcs-backup-bucket
terraform init
terraform validate
```

Expected: "Success! The configuration is valid."

**Step 2: Commit module**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra
git add modules/gcs-backup-bucket/
git commit -m "feat(phase-7): add GCS backup bucket module with 14-day retention"
```

---

## Chunk Complete Checklist

- [ ] gcs-backup-bucket module created
- [ ] 14-day retention lifecycle rule configured
- [ ] Versioning enabled
- [ ] force_destroy = false (production protection)
- [ ] Module validated
- [ ] Module committed to git
- [ ] Ready for chunk 3 (directory structure)
