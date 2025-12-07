# Chunk 3: Create Production Directory Structure

**Status:** pending
**Dependencies:** chunk-002-gcs-backup-module
**Complexity:** simple
**Estimated Time:** 10 minutes
**Tasks:** 2
**Phase:** Infrastructure Foundation
**Story:** STORY-702
**Jira:** PCC-283

---

## Task 1: Create Environment Directory Structure

**Agent:** terraform-specialist

**Step 1: Create directories**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra
mkdir -p environments/prod/{helm,scripts,docs}
```

**Step 2: Create backend.tf**

File: `environments/prod/backend.tf`

```hcl
terraform {
  backend "gcs" {
    bucket = "pcc-tf-state-prod"
    prefix = "argocd-infra/prod"
  }

  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}
```

**Step 3: Create provider.tf**

File: `environments/prod/provider.tf`

```hcl
provider "google" {
  project = var.project_id
  region  = var.region
}
```

---

## Task 2: Create Variables File

**Agent:** terraform-specialist

**Step 1: Create variables.tf**

File: `environments/prod/variables.tf`

```hcl
variable "project_id" {
  description = "Production project ID"
  type        = string
  default     = "pcc-prj-devops-prod"
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-east4"
}

variable "cluster_name" {
  description = "GKE cluster name"
  type        = string
  default     = "pcc-gke-devops-prod"
}

variable "domain" {
  description = "ArgoCD domain"
  type        = string
  default     = "argocd-prod.portcon.com"
}
```

**Step 2: Commit configuration**

```bash
git add environments/prod/
git commit -m "feat(phase-7): create prod environment directory structure"
```

---

## Chunk Complete Checklist

- [ ] Directory structure created (environments/prod, helm, scripts, docs)
- [ ] backend.tf configured with GCS state
- [ ] provider.tf created
- [ ] variables.tf with production defaults
- [ ] Configuration committed
- [ ] Ready for chunk 4 (main config)
