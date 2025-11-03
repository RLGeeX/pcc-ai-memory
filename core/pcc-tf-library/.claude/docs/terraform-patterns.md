# Terraform Patterns and Examples

Detailed patterns and examples for Terraform projects.

## Modular Infrastructure
Use modules to organize resources logically and promote reuse across environments.

```hcl
# main.tf
module "web_server" {
  source        = "./modules/web_server"
  instance_type = var.instance_type
  ami           = var.ami
}

# modules/web_server/main.tf
resource "aws_instance" "web" {
  ami           = var.ami
  instance_type = var.instance_type
}

# variables.tf
variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t2.micro"
}
variable "ami" {
  description = "AMI ID for the EC2 instance"
  type        = string
}
```
- **Pattern**: Encapsulate related resources in modules; use variables for configuration.
- **Benefit**: Simplifies maintenance and supports multi-region deployments.

## State Management
```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "my-terraform-state"
    key            = "state/terraform.tfstate"
    region         = "us-east-1"
  }
}
```
- **Pattern**: Use remote backends (e.g., S3) for state storage to enable team collaboration.
- **Pitfall to Avoid**: Don’t store state files in the repository; use `.gitignore`.

## Environment Folder Pattern

**⚠️ REQUIRED PATTERN FOR ALL PCC INFRASTRUCTURE DEPLOYMENTS**

Use environment-specific folders for complete state isolation and CI/CD compatibility. See `@ADR-008` for full rationale.

### Standard Directory Structure

```
<repo-name>/
├── environments/
│   ├── devtest/           # Infrastructure testing
│   │   ├── backend.tf     # Unique GCS prefix: "<service>/devtest"
│   │   ├── providers.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   ├── *.tf           # Resource configs (main.tf, gke.tf, etc.)
│   │   └── outputs.tf
│   ├── dev/               # Development
│   ├── staging/           # Pre-production
│   └── prod/              # Production
└── README.md
```

**For deployments with nonprod/prod distinction only:**
```
environments/
├── nonprod/   # All non-production environments
└── prod/      # Production only
```

### Backend Configuration

Each environment MUST have unique GCS state prefix:

```hcl
# environments/devtest/backend.tf
terraform {
  backend "gcs" {
    bucket = "pcc-terraform-state"
    prefix = "app-shared-infra/devtest"  # Unique per environment
  }
}

# environments/prod/backend.tf
terraform {
  backend "gcs" {
    bucket = "pcc-terraform-state"
    prefix = "app-shared-infra/prod"  # Different prefix = different state
  }
}
```

### Module References

Reference modules from `pcc-tf-library` with version pinning:

```hcl
# environments/devtest/gke.tf
module "gke_cluster" {
  source = "git::https://github.com/portco-connect/pcc-tf-library.git//modules/gke-autopilot?ref=v0.1.0"

  project_id   = var.project_id
  cluster_name = "pcc-gke-devtest"
  region       = var.region
  # ... other vars
}

# Best Practice: Always use version tags (e.g., ref=v0.1.0) instead of ref=main
# This ensures:
# - Reproducible deployments
# - Protection from breaking changes
# - Easier rollbacks
# - Production stability
```

### CI/CD Deployment Pattern

```bash
# Simple, reliable deployment
cd environments/${ENVIRONMENT}
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

### Why This Pattern?

- ✅ **State Isolation**: Separate GCS prefixes prevent cross-environment corruption
- ✅ **Error Prevention**: Impossible to accidentally apply to wrong environment
- ✅ **CI/CD Simple**: Just `cd environments/$ENV && terraform apply`
- ✅ **Audit Trail**: Git history shows exact per-environment changes
- ✅ **Industry Standard**: Matches Google Cloud and HashiCorp recommendations

### Template

See `@.claude/quick-reference/terraform-environment-template/` for starter files.

**Reference**: ADR-008: Terraform Environment Folder Pattern

---

## Best Practices
- Pin provider versions in `versions.tf` (e.g., `google ~> 5.0`).
- Use `terraform fmt` for consistent formatting.
- Validate configurations with `terraform validate` and `tflint`.
- Document resources in `@.claude/docs/architecture.md`.
- **ALWAYS use environment folder pattern** for multi-environment deployments.