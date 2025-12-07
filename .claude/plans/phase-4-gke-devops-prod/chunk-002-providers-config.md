# Chunk 2: Create Providers Configuration

**Status:** pending
**Dependencies:** chunk-001-directory-structure
**Complexity:** simple
**Estimated Time:** 10 minutes
**Tasks:** 2
**Phase:** Configuration
**Story:** STORY-4.1
**Jira:** PCC-273

---

## Task 1: Create Providers Configuration

**Agent:** terraform-specialist
**Files:**
- Create: `infra/pcc-devops-infra/environments/prod/providers.tf`

**Step 1: Write providers configuration**

File: `infra/pcc-devops-infra/environments/prod/providers.tf`

```hcl
terraform {
  required_version = ">= 1.6.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 6.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}
```

**Step 2: Format and validate**

```bash
cd ~/pcc/infra/pcc-devops-infra/environments/prod
terraform fmt providers.tf
```

Expected: File formatted correctly

---

## Task 2: Create Variables File

**Agent:** terraform-specialist
**Files:**
- Create: `infra/pcc-devops-infra/environments/prod/variables.tf`

**Step 1: Write variables configuration**

File: `infra/pcc-devops-infra/environments/prod/variables.tf`

```hcl
variable "project_id" {
  description = "GCP project ID for DevOps prod environment"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-east4"
}

variable "network_project_id" {
  description = "GCP project ID hosting the shared VPC network"
  type        = string
}

variable "vpc_network_name" {
  description = "Name of the shared VPC network"
  type        = string
}

variable "gke_subnet_name" {
  description = "Name of the GKE subnet in the shared VPC"
  type        = string
}
```

**Step 2: Format, validate, and commit**

```bash
terraform fmt variables.tf
git add providers.tf variables.tf
git commit -m "feat(infra): add providers and variables config for prod environment"
```

---

## Chunk Complete Checklist

- [ ] Providers configuration created with Terraform >= 1.6.0
- [ ] Google provider version ~> 6.0 specified
- [ ] Variables file created with all required variables
- [ ] Files formatted with terraform fmt
- [ ] Changes committed to git
- [ ] Ready for chunk 3 (main.tf)
