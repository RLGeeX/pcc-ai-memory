# Phase 1.5: Create Health Check Module

**Phase**: 1.5 (VPN Infrastructure - Generic Module)
**Duration**: 15-20 minutes
**Type**: Implementation
**Tool**: Claude Code (CC)
**Status**: Ready for Execution

---

## Objective

Create reusable Health Check module in `pcc-tf-library` for TCP/HTTP/HTTPS/HTTP2/SSL/GRPC health checks used by MIGs and load balancers. Module is generic and not specific to WireGuard VPN.

## Prerequisites

✅ `pcc-tf-library` repository available
✅ Understanding of GCP health check types and auto-healing

---

## Module Structure

**Location**: `pcc-tf-library/modules/health-check/`

**Files to Create**:
1. `versions.tf` - Provider requirements
2. `variables.tf` - Input parameters
3. `outputs.tf` - Exported values
4. `main.tf` - Health check resource

---

## Step 1: Create versions.tf

**File**: `pcc-tf-library/modules/health-check/versions.tf`

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

## Step 2: Create variables.tf

**File**: `pcc-tf-library/modules/health-check/variables.tf`

```hcl
variable "project_id" {
  description = "GCP project ID where health check will be created"
  type        = string
}

variable "name" {
  description = "Name of the health check"
  type        = string
}

variable "type" {
  description = "Type of health check (tcp, http, https, http2, ssl, grpc)"
  type        = string
  default     = "tcp"

  validation {
    condition     = contains(["tcp", "http", "https", "http2", "ssl", "grpc"], var.type)
    error_message = "Type must be one of: tcp, http, https, http2, ssl, grpc"
  }
}

variable "check_interval_sec" {
  description = "How often to run the health check (seconds)"
  type        = number
  default     = 5
}

variable "timeout_sec" {
  description = "How long to wait before claiming failure (seconds)"
  type        = number
  default     = 5
}

variable "healthy_threshold" {
  description = "Consecutive successes required to mark healthy"
  type        = number
  default     = 2
}

variable "unhealthy_threshold" {
  description = "Consecutive failures required to mark unhealthy"
  type        = number
  default     = 2
}

variable "port" {
  description = "Port number for the health check"
  type        = number
}

variable "request_path" {
  description = "Request path for HTTP/HTTPS health checks"
  type        = string
  default     = "/"
}

variable "description" {
  description = "Description of the health check's purpose"
  type        = string
  default     = ""
}

variable "labels" {
  description = "Resource labels"
  type        = map(string)
  default     = {}
}
```

---

## Step 3: Create outputs.tf

**File**: `pcc-tf-library/modules/health-check/outputs.tf`

```hcl
output "self_link" {
  description = "The self_link of the health check"
  value       = google_compute_health_check.health_check.self_link
}

output "id" {
  description = "The ID of the health check"
  value       = google_compute_health_check.health_check.id
}

output "name" {
  description = "The name of the health check"
  value       = google_compute_health_check.health_check.name
}
```

---

## Step 4: Create main.tf

**File**: `pcc-tf-library/modules/health-check/main.tf`

```hcl
resource "google_compute_health_check" "health_check" {
  project     = var.project_id
  name        = var.name
  description = var.description

  check_interval_sec  = var.check_interval_sec
  timeout_sec         = var.timeout_sec
  healthy_threshold   = var.healthy_threshold
  unhealthy_threshold = var.unhealthy_threshold

  labels = var.labels

  dynamic "tcp_health_check" {
    for_each = var.type == "tcp" ? [1] : []
    content {
      port = var.port
    }
  }

  dynamic "http_health_check" {
    for_each = var.type == "http" ? [1] : []
    content {
      port         = var.port
      request_path = var.request_path
    }
  }

  dynamic "https_health_check" {
    for_each = var.type == "https" ? [1] : []
    content {
      port         = var.port
      request_path = var.request_path
    }
  }

  dynamic "http2_health_check" {
    for_each = var.type == "http2" ? [1] : []
    content {
      port         = var.port
      request_path = var.request_path
    }
  }

  dynamic "ssl_health_check" {
    for_each = var.type == "ssl" ? [1] : []
    content {
      port = var.port
    }
  }

  dynamic "grpc_health_check" {
    for_each = var.type == "grpc" ? [1] : []
    content {
      port = var.port
    }
  }
}
```

---

## Validation Checklist

- [ ] Directory created: `pcc-tf-library/modules/health-check/`
- [ ] `versions.tf` created with provider ~> 5.0
- [ ] `variables.tf` created with 10 input variables
- [ ] `outputs.tf` created with 3 outputs
- [ ] `main.tf` created with health check resource
- [ ] All 6 health check types supported via dynamic blocks
- [ ] Type validation enforces valid health check types
- [ ] Request path defaults to "/" for HTTP checks
- [ ] No syntax errors

---

## Module Interface

**Required Inputs**:
- `project_id` - GCP project
- `name` - Health check name
- `port` - Port to check

**Key Optional Inputs**:
- `type` - Health check type (default: tcp)
- `check_interval_sec` - Frequency (default: 5)
- `timeout_sec` - Timeout (default: 5)
- `healthy_threshold` - Successes to mark healthy (default: 2)
- `unhealthy_threshold` - Failures to mark unhealthy (default: 2)
- `request_path` - HTTP path (default: /)

**Outputs**:
- `self_link` - For use in MIG/load balancer
- `id` - Resource identifier
- `name` - Health check name

---

## Usage Example

```hcl
module "wireguard_health_check" {
  source = "../../modules/health-check"
  
  project_id   = "pcc-prj-devops-nonprod"
  name         = "wireguard-health-check"
  description  = "Health check for WireGuard VPN auto-healing"
  type         = "http"
  port         = 8080
  request_path = "/health"

  check_interval_sec  = 5
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 2

  labels = {
    terraform   = "true"
    component   = "wireguard-vpn"
    environment = "nonprod"
  }
}

# Note: WireGuard VPN uses HTTP health check on port 8080
# The startup script runs a simple HTTP server returning "OK"
```

---

## Design Considerations

### Health Check Types
- **TCP**: Simple port availability check (fastest, least specific)
- **HTTP/HTTPS/HTTP2**: Check application-level endpoint (more reliable)
- **SSL**: TLS handshake validation
- **GRPC**: gRPC health checking protocol

### WireGuard VPN Use Case
- Uses **HTTP health check** on port 8080
- Startup script runs simple HTTP server returning "OK"
- Validates WireGuard process is running via endpoint logic
- More reliable than TCP check on port 51820 (UDP)

### Timing Configuration
- **check_interval_sec**: How often to probe (default 5s)
- **timeout_sec**: Max wait for response (default 5s)
- **healthy_threshold**: Consecutive successes (default 2 = 10s to recover)
- **unhealthy_threshold**: Consecutive failures (default 2 = 10s to mark down)

### Auto-Healing Impact
- MIG uses health check to trigger instance replacement
- **initial_delay_sec** (set in MIG module) prevents premature checks during boot
- Failed instances replaced automatically within ~2-3 minutes

### Regional vs Global
- This module creates **regional** health checks
- For global load balancers, use `google_compute_global_health_check` instead
- WireGuard VPN uses regional (tied to us-east4 MIG)

---

## Next Phase Dependencies

**Phase 1.6** will create load-balancer module (uses this health check)

**Phase 1.2** MIG module already references health check for auto-healing

**Phase 2.1** will compose this module in `wireguard-vpn.tf`

---

## Time Estimate

- **Create directory**: 1 minute
- **Create versions.tf**: 2 minutes
- **Create variables.tf**: 4-5 minutes (10 variables with validation)
- **Create outputs.tf**: 2 minutes (3 outputs)
- **Create main.tf**: 5-6 minutes (6 dynamic blocks for health check types)
- **Review/validate**: 2-3 minutes
- **Total**: 15-20 minutes

---

**Status**: Ready for execution by CC
**Next**: Phase 1.6 - Create Load Balancer Module
