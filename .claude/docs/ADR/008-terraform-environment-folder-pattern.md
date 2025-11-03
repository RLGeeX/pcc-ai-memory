# ADR 008: Terraform Environment Folder Pattern

**Date**: 2025-10-25
**Status**: Accepted
**Decision Makers**: DevOps Lead, Platform Team
**Consulted**: Terraform Best Practices, Google Cloud Architecture Center, HashiCorp Terraform Documentation

## Context

As PortCo Connect (PCC) scales infrastructure across multiple environments (devtest, dev, staging, prod), we need a consistent terraform structure that:
1. **Prevents cross-environment state corruption** - Changes to one environment cannot affect another
2. **Enables CI/CD automation** - Pipelines can target specific environments reliably
3. **Maintains environment isolation** - Each environment has independent backend state
4. **Supports rapid deployment** - Clear directory structure for `terraform apply` commands
5. **Reduces human error** - Explicit environment separation prevents accidental changes

### Problem Statement

During Phase 2 (AlloyDB deployment), we encountered state management challenges when using single tfvars files with environment variables. This approach created risks:
- Shared state file could cause cross-environment changes
- CI/CD pipelines had complex logic to switch tfvars
- Human error risk when running terraform commands in wrong context
- Difficult to validate which environment was being modified

### Terraform State Management Options

**Option 1: Single Directory with Environment Variables**
```
terraform/
├── backend.tf (single state with ${var.environment} interpolation)
├── providers.tf
├── variables.tf
├── main.tf
├── devtest.tfvars
├── dev.tfvars
├── staging.tfvars
└── prod.tfvars
```
**Issues**:
- ❌ Single backend state file (corruption risk)
- ❌ Requires `-var-file` flag on every command
- ❌ Easy to accidentally apply wrong tfvars
- ❌ CI/CD complexity with variable switching
- ❌ Hard to verify target environment before apply

**Option 2: Environment Folders (Chosen)**
```
terraform/
├── environments/
│   ├── devtest/
│   │   ├── backend.tf (unique GCS prefix: "service-name/devtest")
│   │   ├── providers.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   ├── main.tf
│   │   └── outputs.tf
│   ├── dev/
│   │   ├── backend.tf (unique GCS prefix: "service-name/dev")
│   │   ├── providers.tf
│   │   ├── variables.tf
│   │   ├── terraform.tfvars
│   │   ├── main.tf
│   │   └── outputs.tf
│   └── prod/
│       ├── backend.tf (unique GCS prefix: "service-name/prod")
│       ├── providers.tf
│       ├── variables.tf
│       ├── terraform.tfvars
│       ├── main.tf
│       └── outputs.tf
└── modules/ (optional local modules if needed)
```
**Benefits**:
- ✅ Complete state isolation (separate GCS prefixes)
- ✅ No tfvars flag needed (`cd environments/$ENV && terraform apply`)
- ✅ Impossible to accidentally target wrong environment
- ✅ Simple CI/CD: `cd environments/${ENV} && terraform init && terraform apply`
- ✅ Clear visual separation in file explorer
- ✅ Each environment independently versionable

**Option 3: Terraform Workspaces**
```
terraform/
├── backend.tf (single state with workspaces)
├── providers.tf
├── variables.tf
├── main.tf
└── (use terraform workspace commands)
```
**Issues**:
- ❌ Shared backend (state corruption risk)
- ❌ Workspace names not enforced in code
- ❌ Easy to forget to switch workspace
- ❌ Workspaces hidden (not visible in directory structure)
- ❌ Google recommends against workspaces for environments

## Decision

We will use **Environment Folders** (Option 2) as the standard pattern for all PCC terraform deployments.

### Structure Requirements

Each infrastructure repository (`pcc-*-infra`) MUST follow this structure:

```
<repo-name>/
├── environments/
│   ├── devtest/           # Infrastructure testing environment
│   │   ├── backend.tf     # GCS backend with prefix: "<service>/devtest"
│   │   ├── providers.tf   # Provider configuration
│   │   ├── variables.tf   # Variable declarations (no defaults)
│   │   ├── terraform.tfvars  # Environment-specific values
│   │   ├── *.tf           # Resource configurations (main.tf, alloydb.tf, etc.)
│   │   └── outputs.tf     # Output declarations
│   ├── dev/               # Development environment
│   │   ├── backend.tf     # GCS backend with prefix: "<service>/dev"
│   │   └── [same files as devtest]
│   ├── staging/           # Pre-production environment
│   │   ├── backend.tf     # GCS backend with prefix: "<service>/staging"
│   │   └── [same files as devtest]
│   └── prod/              # Production environment
│       ├── backend.tf     # GCS backend with prefix: "<service>/prod"
│       └── [same files as devtest]
└── README.md              # Deployment instructions per environment
```

**Note**: Some deployments may only use nonprod/prod distinction (e.g., DevOps infrastructure with shared services). In this case, use:
```
environments/
├── nonprod/   # All non-production environments
└── prod/      # Production only
```

### Backend Configuration Standard

Each environment folder MUST have a `backend.tf` with unique GCS prefix:

**Example: `environments/devtest/backend.tf`**
```hcl
terraform {
  backend "gcs" {
    bucket = "pcc-terraform-state"  # Shared bucket
    prefix = "app-shared-infra/devtest"  # Unique prefix per environment
  }
}
```

**Example: `environments/prod/backend.tf`**
```hcl
terraform {
  backend "gcs" {
    bucket = "pcc-terraform-state"
    prefix = "app-shared-infra/prod"  # Different prefix = different state
  }
}
```

### CI/CD Pattern

Cloud Build pipelines or GitHub Actions MUST use this pattern:

```bash
cd environments/${ENVIRONMENT}
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

**Environment variable**: `ENVIRONMENT` ∈ {devtest, dev, staging, prod} or {nonprod, prod}

### File Duplication Strategy

**What to duplicate**:
- ✅ `backend.tf` - Required (different state prefix)
- ✅ `terraform.tfvars` - Required (different values)
- ✅ `providers.tf` - Optional (can be identical)
- ✅ `variables.tf` - Optional (can be identical)
- ✅ `*.tf` resource files - Optional (can be identical)

**How to manage duplication**:
- For identical files across environments, accept duplication for safety
- Use terraform modules in `core/pcc-tf-library` for shared logic
- Reference modules via Git source with version pinning
- Do NOT use symlinks (breaks terraform init)
- Consider terraform-docs to auto-generate variable docs

## Consequences

### Positive
1. **State Isolation**: Complete separation prevents cross-environment corruption
2. **Human Error Prevention**: Impossible to accidentally apply to wrong environment
3. **CI/CD Simplicity**: Simple `cd` command targets environment
4. **Audit Trail**: Git history shows exact changes per environment
5. **Disaster Recovery**: Each environment independently restorable
6. **Visual Clarity**: Directory structure shows all environments at glance
7. **Industry Standard**: Matches Google Cloud and HashiCorp recommendations

### Negative
1. **File Duplication**: Some files (providers.tf, variables.tf) duplicated across folders
2. **Sync Overhead**: Changes to resource configs may need copy-paste across environments
3. **Disk Space**: Slightly larger repository size
4. **Initial Setup**: More work to create all environment folders

### Mitigation for Negatives
- Use terraform modules for shared logic (reduces duplication)
- Accept duplication for safety (disk space is cheap, mistakes are expensive)
- Use scripts to sync identical files if needed (advanced)
- Document standard files in quick-reference template

## Implementation Examples

### Phase 2: AlloyDB Shared Infrastructure

**Repository**: `infra/pcc-app-shared-infra`

**Structure**:
```
pcc-app-shared-infra/
└── terraform/
    └── environments/
        ├── devtest/
        │   ├── backend.tf (prefix: "app-shared-infra/devtest")
        │   ├── alloydb.tf (calls pcc-tf-library/modules/alloydb-cluster)
        │   └── terraform.tfvars (project_id = "pcc-prj-app-devtest")
        ├── dev/
        ├── staging/
        └── prod/
```

**Deployment Command**:
```bash
cd terraform/environments/devtest
terraform init && terraform apply
```

### Phase 3: DevOps NonProd GKE Cluster

**Repository**: `infra/pcc-devops-infra`

**Structure**:
```
pcc-devops-infra/
└── environments/
    ├── nonprod/
    │   ├── backend.tf (prefix: "devops-infra/nonprod")
    │   ├── gke.tf (calls pcc-tf-library/modules/gke-autopilot)
    │   └── terraform.tfvars (project_id = "pcc-prj-devops-nonprod")
    └── prod/
        ├── backend.tf (prefix: "devops-infra/prod")
        ├── gke.tf
        └── terraform.tfvars (project_id = "pcc-prj-devops-prod")
```

**Deployment Command**:
```bash
cd environments/nonprod
terraform init && terraform apply
```

## Alternatives Considered

### Alternative 1: Terragrunt
- **Pro**: DRY configuration, reduces duplication
- **Con**: Additional tool dependency
- **Con**: Learning curve for team
- **Con**: Debugging complexity
- **Decision**: Rejected for simplicity; may revisit if duplication becomes painful

### Alternative 2: Git Branches per Environment
- **Pro**: Full separation in version control
- **Con**: Merge conflicts between environment configs
- **Con**: Difficult to compare environments
- **Con**: Branch-based deployment anti-pattern
- **Decision**: Rejected; folders provide better visibility

### Alternative 3: Separate Repositories per Environment
- **Pro**: Maximum isolation
- **Con**: Extreme operational overhead
- **Con**: Cannot track environment config evolution together
- **Con**: Module updates require N repo updates
- **Decision**: Rejected; too complex for team size

## References

- [Terraform Recommended Practices - Google Cloud](https://cloud.google.com/docs/terraform/best-practices-for-terraform)
- [Managing Multiple Environments - HashiCorp Learn](https://learn.hashicorp.com/tutorials/terraform/organize-configuration)
- ADR-007: Four Environment Architecture
- Phase 2 Implementation: `pcc-app-shared-infra` AlloyDB deployment
- Phase 3 Planning: `pcc-devops-infra` GKE deployment

## Decision Log

| Date | Change | Reason |
|------|--------|--------|
| 2025-10-25 | Initial decision | Established during Phase 2/3 planning to prevent state corruption |

---

**Status**: Accepted and implemented in Phase 2 (AlloyDB) and Phase 3 (GKE DevOps)
