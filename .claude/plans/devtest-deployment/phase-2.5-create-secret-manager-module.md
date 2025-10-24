# Phase 2.5: Create Secret Manager Module

**Phase**: 2.5 (Secret Management - Generic Module)
**Duration**: 20-30 minutes
**Type**: Implementation
**Status**: Ready for Execution

---

## Execution Tool

**Use Claude Code for this phase** - Creating terraform module files only, no CLI commands.

---

## Objective

Create reusable Secret Manager module in `pcc-tf-library` for storing sensitive data (database credentials, API keys, certificates). Module is generic and not specific to AlloyDB.

## Prerequisites

✅ Phase 0 completed (`secretmanager.googleapis.com` enabled)
✅ `pcc-tf-library` repository available
✅ Understanding of Secret Manager concepts (secrets vs versions)

---

## Module Structure

**Location**: `pcc-tf-library/modules/secret-manager/`

**Files to Create**:
1. `versions.tf` - Provider requirements
2. `variables.tf` - Input parameters
3. `outputs.tf` - Exported values
4. `main.tf` - Secret and version resources

---

## Step 1: Create Module Directory

```bash
cd ~/pcc/core/pcc-tf-library
mkdir -p modules/secret-manager
cd modules/secret-manager
```

---

## Step 2: Create versions.tf

**File**: `pcc-tf-library/modules/secret-manager/versions.tf`

```hcl
terraform {
  required_version = ">= 1.5.0"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}
```

---

## Step 3: Create variables.tf

**File**: `pcc-tf-library/modules/secret-manager/variables.tf`

```hcl
variable "project_id" {
  description = "GCP project ID where secret will be created"
  type        = string
}

variable "secret_id" {
  description = "Unique identifier for the secret"
  type        = string

  validation {
    condition     = can(regex("^[a-zA-Z0-9_-]{1,255}$", var.secret_id))
    error_message = "Secret ID must contain only letters, numbers, hyphens, underscores, max 255 chars"
  }
}

variable "secret_data" {
  description = "The secret data to store (will be base64 encoded automatically)"
  type        = string
  sensitive   = true
}

variable "labels" {
  description = "Labels to apply to the secret"
  type        = map(string)
  default     = {}
}

variable "replication_policy" {
  description = "Replication policy: 'automatic' or specific regions"
  type        = string
  default     = "automatic"

  validation {
    condition     = contains(["automatic", "user-managed"], var.replication_policy)
    error_message = "Replication policy must be 'automatic' or 'user-managed'"
  }
}

variable "replication_locations" {
  description = "List of regions for user-managed replication (required if replication_policy = 'user-managed')"
  type        = list(string)
  default     = []
}

variable "rotation_period" {
  description = "Secret rotation period in seconds (e.g., 2592000 = 30 days). Set to null to disable"
  type        = number
  default     = 2592000 # 30 days

  validation {
    condition     = var.rotation_period == null || (var.rotation_period >= 86400 && var.rotation_period <= 31536000)
    error_message = "Rotation period must be between 1 day (86400s) and 365 days (31536000s)"
  }
}

variable "next_rotation_time" {
  description = "Timestamp for next rotation (RFC3339 format). Calculated automatically if null"
  type        = string
  default     = null
}

variable "topics" {
  description = "List of Pub/Sub topic IDs for rotation notifications"
  type        = list(string)
  default     = []
}

variable "expire_time" {
  description = "Timestamp when secret expires (RFC3339 format). Set to null for no expiration"
  type        = string
  default     = null
}

variable "ttl" {
  description = "Time-to-live for secret (e.g., '3600s'). Alternative to expire_time"
  type        = string
  default     = null
}

variable "version_aliases" {
  description = "Map of alias names to version numbers"
  type        = map(string)
  default     = {}
}
```

---

## Step 4: Create outputs.tf

**File**: `pcc-tf-library/modules/secret-manager/outputs.tf`

```hcl
output "secret_id" {
  description = "The ID of the secret"
  value       = google_secret_manager_secret.secret.secret_id
}

output "secret_name" {
  description = "The fully-qualified name of the secret"
  value       = google_secret_manager_secret.secret.name
}

output "secret_version_id" {
  description = "The ID of the secret version"
  value       = google_secret_manager_secret_version.secret_version.id
}

output "secret_version_name" {
  description = "The fully-qualified name of the secret version"
  value       = google_secret_manager_secret_version.secret_version.name
}

output "secret_create_time" {
  description = "Timestamp when secret was created"
  value       = google_secret_manager_secret.secret.create_time
}

output "secret_rotation_config" {
  description = "Secret rotation configuration"
  value       = google_secret_manager_secret.secret.rotation
}
```

---

## Step 5: Create main.tf

**File**: `pcc-tf-library/modules/secret-manager/main.tf`

```hcl
# Secret Manager Secret (metadata)
resource "google_secret_manager_secret" "secret" {
  project   = var.project_id
  secret_id = var.secret_id

  labels = merge(
    var.labels,
    {
      managed_by = "terraform"
    }
  )

  # Replication policy
  replication {
    dynamic "auto" {
      for_each = var.replication_policy == "automatic" ? [1] : []
      content {}
    }

    dynamic "user_managed" {
      for_each = var.replication_policy == "user-managed" ? [1] : []
      content {
        dynamic "replicas" {
          for_each = var.replication_locations
          content {
            location = replicas.value
          }
        }
      }
    }
  }

  # Optional: Rotation configuration
  dynamic "rotation" {
    for_each = var.rotation_period != null ? [1] : []
    content {
      rotation_period    = "${var.rotation_period}s"
      next_rotation_time = var.next_rotation_time

      dynamic "topic" {
        for_each = var.topics
        content {
          topic = topic.value
        }
      }
    }
  }

  # Optional: Expiration
  expire_time = var.expire_time
  ttl         = var.ttl

  # Optional: Version aliases
  dynamic "version_aliases" {
    for_each = var.version_aliases
    content {
      alias   = version_aliases.key
      version = version_aliases.value
    }
  }
}

# Secret Manager Secret Version (actual data)
resource "google_secret_manager_secret_version" "secret_version" {
  secret      = google_secret_manager_secret.secret.id
  secret_data = var.secret_data

  depends_on = [google_secret_manager_secret.secret]
}
```

---

## Validation Checklist

- [ ] Directory created: `pcc-tf-library/modules/secret-manager/`
- [ ] `versions.tf` created with provider ~> 5.0
- [ ] `variables.tf` created with 12 input variables
- [ ] `outputs.tf` created with 6 outputs
- [ ] `main.tf` created with secret + version resources
- [ ] Rotation configuration is optional (dynamic block)
- [ ] Replication supports both automatic and user-managed
- [ ] Secret data marked as sensitive
- [ ] No syntax errors (manual review)

---

## Module Interface

**Required Inputs**:
- `project_id` - Where to create secret
- `secret_id` - Unique identifier
- `secret_data` - Actual secret value (sensitive)

**Optional Inputs**:
- `labels` - For organization
- `replication_policy` - automatic (default) or user-managed
- `replication_locations` - If user-managed
- `rotation_period` - Seconds between rotations (default: 30 days)
- `topics` - Pub/Sub for rotation notifications
- `expire_time` / `ttl` - Secret expiration
- `version_aliases` - Named versions

**Outputs**:
- `secret_id` - For IAM bindings
- `secret_name` - Full resource name
- `secret_version_id` - Latest version ID
- `secret_version_name` - Latest version name
- `secret_create_time` - Audit trail
- `secret_rotation_config` - Rotation settings

---

## Usage Example

```hcl
module "database_password" {
  source = "../../modules/secret-manager"

  project_id  = "pcc-prj-app-devtest"
  secret_id   = "alloydb-devtest-password"
  secret_data = "P@ssw0rd123!" # In practice, use var.password

  labels = {
    purpose     = "database-credentials"
    environment = "devtest"
  }

  # Automatic rotation every 90 days
  rotation_period = 7776000 # 90 days in seconds

  # Automatic replication (multi-region)
  replication_policy = "automatic"
}
```

---

## Replication Strategies

### Automatic (Recommended for Devtest)
```hcl
replication_policy = "automatic"
```
- Google manages replication
- Multi-region redundancy
- Simplest setup
- **Use for**: Devtest, most production scenarios

### User-Managed (Production High Availability)
```hcl
replication_policy     = "user-managed"
replication_locations  = ["us-east4", "us-central1", "us-west1"]
```
- Explicit region control
- Compliance requirements (data locality)
- **Use for**: Regulated data, specific DR requirements

---

## Rotation Configuration

### Enable Rotation
```hcl
rotation_period    = 2592000  # 30 days
topics             = ["projects/my-project/topics/secret-rotation"]
```

### Disable Rotation
```hcl
rotation_period = null
```

**Best Practices**:
- Database passwords: 30-90 days
- API keys: 60-180 days
- Service account keys: 90 days (or use Workload Identity)

---

## Security Considerations

1. **Secret Data Sensitivity**:
   - Variable marked `sensitive = true`
   - Never logged or displayed
   - Encrypted at rest automatically

2. **Access Control** (Phase 2.6):
   - Grant `roles/secretmanager.secretAccessor` to applications
   - Grant `roles/secretmanager.admin` to DevOps only
   - Use groups, not individual users

3. **Rotation**:
   - Enable for production secrets
   - Configure Pub/Sub notifications
   - Application must handle credential refresh

4. **Audit Logging**:
   - Secret access logged automatically
   - Review Cloud Logging for anomalies

---

## Next Phase Dependencies

**Phase 2.5** will:
- Call this module to create AlloyDB password secret
- Pass database connection string as secret_data

**Phase 2.6** will:
- Add IAM bindings to grant secret access
- Use `secret_id` output for bindings

**Phase 2.7** will:
- Reference secret in Flyway configuration
- Fetch secret at runtime for migrations

---

## Troubleshooting

### Issue: "Secret already exists"
**Resolution**: Secret IDs must be unique per project. Delete or import existing:
```bash
terraform import google_secret_manager_secret.secret projects/PROJECT_ID/secrets/SECRET_ID
```

### Issue: "Invalid rotation_period"
**Resolution**: Must be in seconds, between 1-365 days
```
Valid: 2592000 (30 days), 7776000 (90 days)
Invalid: 30 (too small), 40000000 (too large)
```

### Issue: "Replication locations required"
**Resolution**: If `replication_policy = "user-managed"`, must specify locations
```hcl
replication_locations = ["us-east4"]  # At least one
```

---

## References

- **Secret Manager**: https://cloud.google.com/secret-manager/docs
- **Rotation**: https://cloud.google.com/secret-manager/docs/rotation
- **IAM Roles**: https://cloud.google.com/secret-manager/docs/access-control

---

## Time Estimate

- **Create directory**: 1 minute
- **Create versions.tf**: 2 minutes
- **Create variables.tf**: 10-12 minutes (12 variables with validation)
- **Create outputs.tf**: 4-5 minutes (6 outputs)
- **Create main.tf**: 8-10 minutes (secret + version + dynamic blocks)
- **Review/validate**: 3-5 minutes
- **Total**: 20-30 minutes

---

**Status**: Ready for execution
**Next**: Phase 2.5 - Implement Secret Manager Call for AlloyDB Credentials
