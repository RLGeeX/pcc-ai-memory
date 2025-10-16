# Apigee X TLS Certificate Management and Traffic Routing - Terraform Specification

**Project:** PortCo Connect (PCC) - Apigee X Integration
**Environment:** All (devtest, dev, staging, prod)
**Last Updated:** 2025-10-16
**Version:** 1.0

---

## Executive Summary

This document provides comprehensive Terraform specifications for TLS certificate management and traffic routing to Apigee X on Google Cloud Platform. It complements the Apigee X Networking Infrastructure specification and focuses on the northbound connectivity layer: how external clients reach Apigee via HTTPS Load Balancers.

**Critical Components:**
- TLS certificate management (Google-managed and custom certificates)
- External HTTPS Load Balancer configuration
- DNS record management for environment group hostnames
- SSL policy configuration for security compliance
- Integration with Cloud Armor (optional DDoS protection)

**Document Dependencies:**
- Must be read in conjunction with `@docs/apigee-x-networking-specification.md`
- Assumes VPC peering, Apigee instances, and environment groups already configured

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [TLS Certificate Management](#tls-certificate-management)
3. [External HTTPS Load Balancer Configuration](#external-https-load-balancer-configuration)
4. [DNS Configuration](#dns-configuration)
5. [Environment Group Hostname Patterns](#environment-group-hostname-patterns)
6. [SSL Policy and Security Best Practices](#ssl-policy-and-security-best-practices)
7. [Cloud Armor Integration (Optional)](#cloud-armor-integration-optional)
8. [Complete Terraform Examples](#complete-terraform-examples)
9. [Multi-Environment Deployment Patterns](#multi-environment-deployment-patterns)
10. [Monitoring and Observability](#monitoring-and-observability)
11. [Troubleshooting](#troubleshooting)
12. [Migration and Rollback Procedures](#migration-and-rollback-procedures)
13. [Cost Optimization](#cost-optimization)
14. [References](#references)

---

## Architecture Overview

### High-Level Traffic Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                    External Clients (Internet)                   │
│                  (api-devtest.portcon.com)                      │
└─────────────────────┬───────────────────────────────────────────┘
                      │ HTTPS (TLS 1.2/1.3)
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│               Cloud DNS (A Records)                              │
│   api-devtest.portcon.com → 34.117.x.x (LB IP)                 │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│           External HTTPS Load Balancer (Global L7)              │
│                                                                  │
│  ┌────────────────────────────────────────────────────┐        │
│  │  Frontend (HTTPS on port 443)                      │        │
│  │  - SSL Certificate (Google-managed or custom)      │        │
│  │  - SSL Policy (TLS 1.2+ enforcement)              │        │
│  │  - HTTP to HTTPS redirect                          │        │
│  └────────────────┬───────────────────────────────────┘        │
│                   │                                              │
│  ┌────────────────▼───────────────────────────────────┐        │
│  │  URL Map (Hostname-based Routing)                  │        │
│  │  - api-devtest.portcon.com → Backend Service       │        │
│  └────────────────┬───────────────────────────────────┘        │
│                   │                                              │
│  ┌────────────────▼───────────────────────────────────┐        │
│  │  Backend Service                                    │        │
│  │  - Protocol: HTTPS                                  │        │
│  │  - Session Affinity: GENERATED_COOKIE (optional)   │        │
│  │  - Health Check: HTTPS on /healthz/ingress         │        │
│  └────────────────┬───────────────────────────────────┘        │
│                   │                                              │
│  ┌────────────────▼───────────────────────────────────┐        │
│  │  Network Endpoint Group (NEG)                      │        │
│  │  - Type: INTERNET_IP_PORT                          │        │
│  │  - Endpoints: Apigee instance IPs                  │        │
│  └────────────────────────────────────────────────────┘        │
└─────────────────────┬───────────────────────────────────────────┘
                      │ HTTPS (443)
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Apigee X Runtime Instance                       │
│                  (us-central1)                                   │
│                                                                  │
│  ┌────────────────────────────────────────────────────┐        │
│  │  Environment Group: pcc-api-devtest                │        │
│  │  Hostnames: api-devtest.portcon.com                │        │
│  └────────────────┬───────────────────────────────────┘        │
│                   │                                              │
│  ┌────────────────▼───────────────────────────────────┐        │
│  │  Environment: devtest                              │        │
│  │  Attached API Proxies                              │        │
│  └────────────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────────┘
```

### Key Components

1. **DNS Records**: Map environment group hostnames to load balancer IP addresses
2. **SSL Certificates**: Secure HTTPS traffic with TLS certificates
3. **External HTTPS Load Balancer**: Global Layer 7 load balancer with SSL termination
4. **Network Endpoint Groups (NEG)**: Point to Apigee instance IP addresses
5. **Backend Service**: Configure health checks and session affinity
6. **URL Map**: Route traffic based on hostname to appropriate backend services
7. **SSL Policy**: Enforce minimum TLS version and cipher suites

---

## TLS Certificate Management

### Certificate Options Comparison

| Feature | Google-Managed Certificates | Custom Certificates |
|---------|---------------------------|---------------------|
| **Cost** | Free | Varies (free with Let's Encrypt, paid with commercial CA) |
| **Renewal** | Automatic (every 90 days) | Manual or scripted (depends on solution) |
| **Provisioning Time** | 15-30 minutes | Immediate (if already issued) |
| **Domain Validation** | DNS or HTTP challenge (automatic) | Manual DNS/HTTP validation |
| **Wildcard Support** | ❌ No | ✅ Yes |
| **Multi-Domain (SAN)** | ✅ Yes (up to 100 domains) | ✅ Yes |
| **EV Certificates** | ❌ No | ✅ Yes |
| **Certificate Transparency** | ✅ Logged automatically | ✅ Logged (if CA supports) |
| **Terraform Support** | ✅ Native | ✅ Via google_compute_ssl_certificate |
| **Best For** | Production (single/multiple hostnames) | Wildcard certs, EV certs, existing PKI |

### Recommendation

**For PCC:**
- **Google-Managed Certificates** for all environments (devtest, dev, staging, prod)
- Automatic renewal eliminates operational overhead
- No cost for certificates
- Integrates seamlessly with Cloud Load Balancing

**Exception Cases:**
- If wildcard certificate is required (`*.portcon.com`), use custom certificate
- If EV certificate is required for compliance, use custom certificate

---

### Google-Managed Certificates

#### Terraform Configuration

```hcl
# Google-managed SSL certificate for Apigee environment group
resource "google_compute_managed_ssl_certificate" "apigee_cert" {
  name    = "pcc-apigee-cert-${var.environment}"
  project = var.project_id

  managed {
    domains = var.environment_group_hostnames
  }

  lifecycle {
    create_before_destroy = true
  }
}
```

**Key Configuration Points:**

1. **Domain List**: Must match environment group hostnames exactly
2. **Lifecycle Policy**: Use `create_before_destroy` for zero-downtime certificate rotation
3. **Provisioning**: Certificates are issued only after load balancer is created and DNS is configured
4. **Validation**: Google validates domain ownership via HTTP challenge on `/.well-known/acme-challenge/`

**Provisioning Process:**

```
1. Create google_compute_managed_ssl_certificate resource
2. Create load balancer with certificate attached
3. DNS records point to load balancer IP
4. Google validates domain ownership (HTTP challenge)
5. Certificate issued (15-30 minutes)
6. Certificate status: ACTIVE
```

**Certificate Status Monitoring:**

```hcl
output "certificate_status" {
  description = "Status of managed SSL certificate"
  value       = google_compute_managed_ssl_certificate.apigee_cert.certificate_status
}
```

**Possible Status Values:**
- `PROVISIONING`: Certificate being issued
- `ACTIVE`: Certificate issued and active
- `RENEWAL_FAILED`: Renewal failed (check domain validation)
- `FAILED`: Certificate issuance failed

---

### Custom Certificates

#### Use Case: Wildcard Certificate

If you need `*.portcon.com` or have existing certificates:

```hcl
# Custom SSL certificate (wildcard or EV certificate)
resource "google_compute_ssl_certificate" "apigee_custom_cert" {
  name_prefix = "pcc-apigee-custom-cert-${var.environment}-"
  project     = var.project_id

  certificate = file("${path.module}/certs/certificate.pem")
  private_key = file("${path.module}/certs/private-key.pem")

  lifecycle {
    create_before_destroy = true
  }
}
```

**Certificate File Requirements:**

1. **Certificate File** (`certificate.pem`):
   - Must be PEM-encoded
   - Include full certificate chain (leaf cert + intermediate CAs)
   - Root CA certificate is optional but recommended

2. **Private Key File** (`private-key.pem`):
   - Must be PEM-encoded RSA or ECDSA private key
   - Unencrypted (no passphrase)
   - Store securely in Secret Manager (see below)

**Security Best Practice: Use Secret Manager**

```hcl
# Store certificate and key in Secret Manager
resource "google_secret_manager_secret" "tls_certificate" {
  secret_id = "pcc-apigee-tls-cert-${var.environment}"
  project   = var.project_id

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "tls_certificate_version" {
  secret      = google_secret_manager_secret.tls_certificate.id
  secret_data = file("${path.module}/certs/certificate.pem")
}

resource "google_secret_manager_secret" "tls_private_key" {
  secret_id = "pcc-apigee-tls-key-${var.environment}"
  project   = var.project_id

  replication {
    automatic = true
  }
}

resource "google_secret_manager_secret_version" "tls_private_key_version" {
  secret      = google_secret_manager_secret.tls_private_key.id
  secret_data = file("${path.module}/certs/private-key.pem")
}

# Retrieve from Secret Manager in Terraform
data "google_secret_manager_secret_version" "tls_cert" {
  secret  = google_secret_manager_secret.tls_certificate.id
  project = var.project_id
}

data "google_secret_manager_secret_version" "tls_key" {
  secret  = google_secret_manager_secret.tls_private_key.id
  project = var.project_id
}

# Use in SSL certificate resource
resource "google_compute_ssl_certificate" "apigee_custom_cert" {
  name_prefix = "pcc-apigee-custom-cert-${var.environment}-"
  project     = var.project_id

  certificate = data.google_secret_manager_secret_version.tls_cert.secret_data
  private_key = data.google_secret_manager_secret_version.tls_key.secret_data

  lifecycle {
    create_before_destroy = true
  }
}
```

**Certificate Renewal Automation:**

For custom certificates, implement automated renewal:

```hcl
# Cloud Function to renew certificate (e.g., via Let's Encrypt ACME API)
resource "google_cloudfunctions2_function" "cert_renewal" {
  name     = "pcc-apigee-cert-renewal-${var.environment}"
  location = var.region
  project  = var.project_id

  build_config {
    runtime     = "python311"
    entry_point = "renew_certificate"
    source {
      storage_source {
        bucket = google_storage_bucket.function_source.name
        object = google_storage_bucket_object.function_source.name
      }
    }
  }

  service_config {
    max_instance_count = 1
    available_memory   = "256M"
    timeout_seconds    = 300
    environment_variables = {
      PROJECT_ID      = var.project_id
      ENVIRONMENT     = var.environment
      SECRET_CERT_ID  = google_secret_manager_secret.tls_certificate.secret_id
      SECRET_KEY_ID   = google_secret_manager_secret.tls_private_key.secret_id
    }
  }
}

# Cloud Scheduler to trigger renewal 30 days before expiry
resource "google_cloud_scheduler_job" "cert_renewal_schedule" {
  name             = "pcc-apigee-cert-renewal-${var.environment}"
  schedule         = "0 3 1 * *" # 3 AM on 1st day of each month
  time_zone        = "America/New_York"
  attempt_deadline = "320s"
  project          = var.project_id
  region           = var.region

  http_target {
    http_method = "POST"
    uri         = google_cloudfunctions2_function.cert_renewal.service_config[0].uri
    oidc_token {
      service_account_email = google_service_account.cert_renewal.email
    }
  }
}
```

---

## External HTTPS Load Balancer Configuration

### Global vs Regional Load Balancers

**For Apigee X: Use Global External HTTPS Load Balancer**

| Feature | Global Load Balancer | Regional Load Balancer |
|---------|---------------------|----------------------|
| **Anycast IP** | ✅ Yes (single global IP) | ❌ No (regional IP) |
| **Multi-Region Routing** | ✅ Yes (automatic failover) | ❌ No (single region) |
| **SSL Termination** | ✅ Yes | ✅ Yes |
| **Cloud CDN** | ✅ Yes | ❌ No |
| **Cloud Armor** | ✅ Yes | ⚠️ Limited (EXTERNAL_MANAGED only) |
| **Terraform Resource** | `google_compute_global_forwarding_rule` | `google_compute_forwarding_rule` |
| **Best For** | Production Apigee (multi-region HA) | Single-region dev/test |

**Recommendation for PCC:**
- **Global Load Balancer** for all environments (future-proof for multi-region)
- Provides single global IP address for simplified DNS management

---

### Complete Load Balancer Terraform Configuration

#### Step 1: Health Check

```hcl
# Health check for Apigee runtime
resource "google_compute_health_check" "apigee_health_check" {
  name                = "pcc-apigee-health-check-${var.environment}"
  project             = var.project_id
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  https_health_check {
    port         = 443
    request_path = "/healthz/ingress"
    host         = var.environment_group_hostnames[0]
  }
}
```

**Health Check Path:**
- Apigee X default health check path: `/healthz/ingress`
- Returns HTTP 200 when runtime is healthy
- Configure `host` header to match environment group hostname

---

#### Step 2: Backend Service

```hcl
# Backend service pointing to Apigee NEG
resource "google_compute_backend_service" "apigee_backend" {
  name                    = "pcc-apigee-backend-${var.environment}"
  project                 = var.project_id
  protocol                = "HTTPS"
  port_name               = "https"
  timeout_sec             = 30
  enable_cdn              = false # Enable if using Apigee for API caching
  session_affinity        = "GENERATED_COOKIE" # Optional: for sticky sessions
  affinity_cookie_ttl_sec = 3600

  backend {
    group           = google_compute_network_endpoint_group.apigee_neg.id
    balancing_mode  = "RATE"
    max_rate_per_endpoint = 100 # Adjust based on expected traffic
  }

  health_checks = [google_compute_health_check.apigee_health_check.id]

  log_config {
    enable      = true
    sample_rate = 1.0 # Log 100% of requests (adjust for cost optimization)
  }

  security_policy = var.enable_cloud_armor ? google_compute_security_policy.apigee_armor[0].id : null
}
```

**Key Parameters:**

1. **protocol = "HTTPS"**: Backend communication to Apigee is HTTPS
2. **session_affinity**: Optional sticky sessions (useful for stateful APIs)
3. **enable_cdn**: Set to `true` if using Apigee for API response caching
4. **log_config**: Enable for observability (can adjust sample_rate for cost)
5. **security_policy**: Optional Cloud Armor for DDoS/WAF protection

---

#### Step 3: Network Endpoint Group (NEG)

```hcl
# Network Endpoint Group for Apigee instance
resource "google_compute_network_endpoint_group" "apigee_neg" {
  name    = "pcc-apigee-neg-${var.environment}"
  project = var.project_id
  network = data.google_compute_network.apigee_vpc.id
  zone    = "${var.apigee_instance_region}-a"

  network_endpoint_type = "INTERNET_IP_PORT"
}

# Add Apigee instance host as endpoint
resource "google_compute_network_endpoint" "apigee_endpoint" {
  network_endpoint_group = google_compute_network_endpoint_group.apigee_neg.name
  project                = var.project_id
  zone                   = google_compute_network_endpoint_group.apigee_neg.zone

  ip_address = google_apigee_instance.apigee_instance.host
  port       = 443
}
```

**Critical Configuration:**

- **network_endpoint_type = "INTERNET_IP_PORT"**: Required for Apigee (not GCE_VM_IP_PORT)
- **ip_address**: Use `google_apigee_instance.apigee_instance.host` (Apigee runtime IP)
- **port = 443**: Apigee accepts HTTPS traffic on port 443

**Apigee Instance Host:**

The `google_apigee_instance` resource provides a `host` attribute:
```
Output example: 34.110.234.123.apigee.io
```

This is the IP address of the Apigee runtime instance.

---

#### Step 4: URL Map (Hostname-based Routing)

```hcl
# URL map for hostname-based routing
resource "google_compute_url_map" "apigee_url_map" {
  name            = "pcc-apigee-url-map-${var.environment}"
  project         = var.project_id
  default_service = google_compute_backend_service.apigee_backend.id

  host_rule {
    hosts        = var.environment_group_hostnames
    path_matcher = "apigee-paths"
  }

  path_matcher {
    name            = "apigee-paths"
    default_service = google_compute_backend_service.apigee_backend.id

    path_rule {
      paths   = ["/*"]
      service = google_compute_backend_service.apigee_backend.id
    }
  }
}
```

**Routing Logic:**

1. Match requests for hostnames in `var.environment_group_hostnames`
2. Route all paths (`/*`) to Apigee backend service
3. Default service is also Apigee backend (catch-all)

---

#### Step 5: HTTPS Target Proxy

```hcl
# HTTPS target proxy with SSL certificate
resource "google_compute_target_https_proxy" "apigee_https_proxy" {
  name             = "pcc-apigee-https-proxy-${var.environment}"
  project          = var.project_id
  url_map          = google_compute_url_map.apigee_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.apigee_cert.id]
  ssl_policy       = google_compute_ssl_policy.modern_tls.id
}
```

**Key Parameters:**

- **ssl_certificates**: List of SSL certificate IDs (can attach multiple)
- **ssl_policy**: Reference to SSL policy (TLS version, ciphers)

---

#### Step 6: Global Forwarding Rule (External IP)

```hcl
# Reserve global static IP address
resource "google_compute_global_address" "apigee_external_ip" {
  name    = "pcc-apigee-external-ip-${var.environment}"
  project = var.project_id
}

# Global forwarding rule for HTTPS traffic
resource "google_compute_global_forwarding_rule" "apigee_https" {
  name                  = "pcc-apigee-https-forwarding-rule-${var.environment}"
  project               = var.project_id
  ip_address            = google_compute_global_address.apigee_external_ip.address
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.apigee_https_proxy.id
}
```

**Forwarding Rule Configuration:**

- **load_balancing_scheme = "EXTERNAL_MANAGED"**: Required for global external load balancer
- **port_range = "443"**: HTTPS traffic
- **ip_address**: Static IP address (for DNS records)

---

#### Step 7: HTTP to HTTPS Redirect (Optional but Recommended)

```hcl
# HTTP target proxy for redirect
resource "google_compute_target_http_proxy" "apigee_http_redirect" {
  name    = "pcc-apigee-http-redirect-${var.environment}"
  project = var.project_id
  url_map = google_compute_url_map.apigee_http_redirect_map.id
}

# URL map for HTTP to HTTPS redirect
resource "google_compute_url_map" "apigee_http_redirect_map" {
  name    = "pcc-apigee-http-redirect-map-${var.environment}"
  project = var.project_id

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

# HTTP forwarding rule (port 80)
resource "google_compute_global_forwarding_rule" "apigee_http_redirect" {
  name                  = "pcc-apigee-http-redirect-${var.environment}"
  project               = var.project_id
  ip_address            = google_compute_global_address.apigee_external_ip.address
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.apigee_http_redirect.id
}
```

**Redirect Behavior:**

- HTTP requests on port 80 → 301 redirect to HTTPS
- Preserves query parameters and path
- Recommended for security (force HTTPS)

---

## DNS Configuration

### DNS Record Requirements

For each environment group hostname, create an A record pointing to the load balancer IP.

**Example DNS Configuration:**

| Hostname | Record Type | Value | TTL |
|----------|------------|-------|-----|
| api-devtest.portcon.com | A | 34.117.x.x | 300 |
| api-dev.portcon.com | A | 35.186.x.x | 300 |
| api-staging.portcon.com | A | 34.120.x.x | 300 |
| api.portcon.com | A | 35.201.x.x | 300 |
| api-prod.portcon.com | A | 35.201.x.x | 300 |

**TTL Recommendations:**
- **Dev/Test**: 300 seconds (5 minutes) for faster iteration
- **Production**: 3600 seconds (1 hour) for stability

---

### Cloud DNS Configuration (Terraform)

#### Option 1: Cloud DNS Managed Zone

If `portcon.com` is managed in Cloud DNS:

```hcl
# Reference existing Cloud DNS managed zone
data "google_dns_managed_zone" "portcon_zone" {
  name    = "portcon-com"
  project = var.dns_project_id
}

# A record for environment group hostname
resource "google_dns_record_set" "apigee_hostname" {
  name         = "${var.environment_hostname_prefix}.portcon.com."
  type         = "A"
  ttl          = var.dns_ttl
  managed_zone = data.google_dns_managed_zone.portcon_zone.name
  project      = var.dns_project_id

  rrdatas = [google_compute_global_address.apigee_external_ip.address]
}
```

**Variables:**

```hcl
variable "environment_hostname_prefix" {
  description = "Hostname prefix for environment (e.g., api-devtest, api, api-prod)"
  type        = string
}

variable "dns_ttl" {
  description = "DNS TTL in seconds"
  type        = number
  default     = 300
}

variable "dns_project_id" {
  description = "GCP project ID where DNS zone is managed"
  type        = string
}
```

---

#### Option 2: External DNS Provider Integration

If `portcon.com` is managed outside GCP (e.g., Cloudflare, Route53):

**Manual DNS Configuration:**

1. Note the load balancer IP address from Terraform output
2. Create A record in external DNS provider:
   ```
   Name: api-devtest
   Type: A
   Value: 34.117.x.x
   TTL: 300
   ```

**Automated DNS with External Provider:**

Use provider-specific Terraform resources:

```hcl
# Example: Cloudflare DNS record
resource "cloudflare_record" "apigee_hostname" {
  zone_id = var.cloudflare_zone_id
  name    = var.environment_hostname_prefix
  type    = "A"
  value   = google_compute_global_address.apigee_external_ip.address
  ttl     = 300
  proxied = false # Set to true for Cloudflare CDN/WAF
}
```

---

### A Records vs CNAME Records

| Record Type | Use Case | Advantages | Disadvantages |
|------------|----------|-----------|---------------|
| **A Record** | Direct IP mapping | Fast resolution, no extra DNS lookup | Requires IP change if LB IP changes |
| **CNAME** | Alias to another hostname | Flexible (can change underlying IP) | Not allowed for apex domains (e.g., portcon.com) |

**Recommendation for PCC:**

- **A Records** for all Apigee hostnames
- Use static IP addresses via `google_compute_global_address`
- CNAME records are not supported for apex domains (e.g., `api.portcon.com` must use A record)

**CNAME Alternative (if needed):**

If you need to alias multiple hostnames to a single load balancer:

```hcl
# Primary A record
resource "google_dns_record_set" "apigee_primary" {
  name         = "api.portcon.com."
  type         = "A"
  ttl          = 300
  managed_zone = data.google_dns_managed_zone.portcon_zone.name
  project      = var.dns_project_id

  rrdatas = [google_compute_global_address.apigee_external_ip.address]
}

# CNAME alias (subdomain only)
resource "google_dns_record_set" "apigee_alias" {
  name         = "api-prod.portcon.com."
  type         = "CNAME"
  ttl          = 300
  managed_zone = data.google_dns_managed_zone.portcon_zone.name
  project      = var.dns_project_id

  rrdatas = ["api.portcon.com."]
}
```

---

## Environment Group Hostname Patterns

### Hostname Requirements

Per the project requirements, configure hostnames as follows:

| Environment | Primary Hostname | Additional Hostnames | Environment Group Name |
|------------|-----------------|---------------------|----------------------|
| **devtest** | api-devtest.portcon.com | - | pcc-api-devtest |
| **dev** | api-dev.portcon.com | - | pcc-api-dev |
| **staging** | api-staging.portcon.com | - | pcc-api-staging |
| **prod** | api.portcon.com | api-prod.portcon.com | pcc-api-prod |

### Apigee Environment Group Configuration

```hcl
# Environment group for devtest
resource "google_apigee_envgroup" "devtest" {
  name     = "pcc-api-devtest"
  org_id   = google_apigee_organization.apigee_org.id
  hostnames = [
    "api-devtest.portcon.com"
  ]
}

# Environment group for dev
resource "google_apigee_envgroup" "dev" {
  name     = "pcc-api-dev"
  org_id   = google_apigee_organization.apigee_org.id
  hostnames = [
    "api-dev.portcon.com"
  ]
}

# Environment group for staging
resource "google_apigee_envgroup" "staging" {
  name     = "pcc-api-staging"
  org_id   = google_apigee_organization.apigee_org.id
  hostnames = [
    "api-staging.portcon.com"
  ]
}

# Environment group for prod (multiple hostnames)
resource "google_apigee_envgroup" "prod" {
  name     = "pcc-api-prod"
  org_id   = google_apigee_organization.apigee_org.id
  hostnames = [
    "api.portcon.com",
    "api-prod.portcon.com"
  ]
}
```

**Multiple Hostnames per Environment Group:**

- Production has 2 hostnames: `api.portcon.com` (primary) and `api-prod.portcon.com` (explicit)
- Both hostnames route to the same Apigee environment (prod)
- Useful for migration scenarios or different client integrations

---

### Hostname to Environment Mapping

```hcl
# Attach environment to environment group
resource "google_apigee_envgroup_attachment" "devtest_attachment" {
  envgroup_id = google_apigee_envgroup.devtest.id
  environment = google_apigee_environment.devtest.name
}

resource "google_apigee_envgroup_attachment" "dev_attachment" {
  envgroup_id = google_apigee_envgroup.dev.id
  environment = google_apigee_environment.dev.name
}

resource "google_apigee_envgroup_attachment" "staging_attachment" {
  envgroup_id = google_apigee_envgroup.staging.id
  environment = google_apigee_environment.staging.name
}

resource "google_apigee_envgroup_attachment" "prod_attachment" {
  envgroup_id = google_apigee_envgroup.prod.id
  environment = google_apigee_environment.prod.name
}
```

**Traffic Routing:**

```
Client Request: https://api-devtest.portcon.com/users/v1/profile
                     ↓
Load Balancer: Hostname matches api-devtest.portcon.com
                     ↓
Apigee Runtime: Routes to environment group "pcc-api-devtest"
                     ↓
Environment: devtest
                     ↓
API Proxy: /users/v1/profile → Backend (GKE)
```

---

## SSL Policy and Security Best Practices

### SSL Policy Configuration

Define SSL policy to enforce TLS version and cipher suites:

```hcl
# Modern TLS policy (TLS 1.2+)
resource "google_compute_ssl_policy" "modern_tls" {
  name            = "pcc-apigee-modern-tls-${var.environment}"
  project         = var.project_id
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}
```

**SSL Policy Profiles:**

| Profile | Min TLS Version | Cipher Suites | Use Case |
|---------|----------------|---------------|----------|
| **MODERN** | TLS 1.2 | Strong ciphers only (no RC4, 3DES) | **Recommended for production** |
| **COMPATIBLE** | TLS 1.0 | Includes weak ciphers for legacy clients | Legacy support only |
| **RESTRICTED** | TLS 1.2 | Strongest ciphers (PFS required) | High-security environments |
| **CUSTOM** | User-defined | User-defined cipher list | Advanced use cases |

**Recommendation for PCC:**

- **MODERN profile** for all environments
- Minimum TLS 1.2 (consider TLS 1.3 only for future)

---

### Recommended TLS Policy (Production)

```hcl
resource "google_compute_ssl_policy" "production_tls" {
  name            = "pcc-apigee-production-tls"
  project         = var.project_id
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"

  # Optional: Further restrict cipher suites
  custom_features = [
    "TLS_ECDHE_RSA_WITH_AES_128_GCM_SHA256",
    "TLS_ECDHE_RSA_WITH_AES_256_GCM_SHA384",
    "TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256"
  ]
}
```

**Cipher Suite Selection:**

- **ECDHE**: Elliptic Curve Diffie-Hellman Ephemeral (Perfect Forward Secrecy)
- **AES-GCM**: Authenticated encryption (prevents tampering)
- **ChaCha20-Poly1305**: Modern alternative to AES (better performance on mobile)

---

### Minimum TLS Version: 1.2 vs 1.3

| Feature | TLS 1.2 | TLS 1.3 |
|---------|---------|---------|
| **Security** | Strong (if modern ciphers used) | Stronger (removed weak ciphers) |
| **Performance** | 2 round trips for handshake | 1 round trip (0-RTT optional) |
| **Compatibility** | ✅ Widely supported | ⚠️ Requires modern clients (2018+) |
| **Cipher Negotiation** | Server chooses | Client chooses (simplified) |
| **Recommendation** | ✅ Use for production (2025) | ⏳ Plan migration for 2026 |

**Recommendation for PCC:**

- **TLS 1.2** as minimum for now (broad compatibility)
- **Monitor client TLS versions** using load balancer logs
- **Plan migration to TLS 1.3-only** in 2026 (after 95%+ client support)

---

### HSTS Configuration

**HTTP Strict Transport Security (HSTS)** enforces HTTPS on client side:

```hcl
# HSTS policy in Apigee API Proxy (not Load Balancer)
# Add via AssignMessage policy in Apigee proxy
```

**Apigee AssignMessage Policy (XML):**

```xml
<AssignMessage name="Add-HSTS-Header">
  <AssignTo createNew="false" transport="http" type="response"/>
  <Set>
    <Headers>
      <Header name="Strict-Transport-Security">max-age=31536000; includeSubDomains; preload</Header>
    </Headers>
  </Set>
</AssignMessage>
```

**HSTS Parameters:**

- `max-age=31536000`: 1 year (recommended minimum)
- `includeSubDomains`: Apply to all subdomains
- `preload`: Submit to HSTS preload list (browsers)

**HSTS Preload Submission:**

After validating HSTS in production, submit to preload list:
- https://hstspreload.org/
- Ensures browsers always use HTTPS (even first visit)

---

## Cloud Armor Integration (Optional)

Cloud Armor provides DDoS protection and Web Application Firewall (WAF) capabilities.

### When to Use Cloud Armor

**Use Cases:**
- Protection against DDoS attacks (Layer 3/4/7)
- Rate limiting per client IP
- Geo-blocking (allow/deny by country)
- OWASP Top 10 protection (SQL injection, XSS)
- Bot management

**Cost Consideration:**
- **Cloud Armor Standard**: ~$0.75/policy/month + $0.75/1M requests
- **Cloud Armor Managed Protection Plus**: ~$3,000/month (advanced DDoS)

**Recommendation for PCC:**

- **Enable for production** (api.portcon.com)
- **Optional for dev/staging** (cost vs risk)

---

### Cloud Armor Security Policy

```hcl
# Cloud Armor security policy
resource "google_compute_security_policy" "apigee_armor" {
  count   = var.enable_cloud_armor ? 1 : 0
  name    = "pcc-apigee-armor-${var.environment}"
  project = var.project_id

  # Default rule: Allow all traffic
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default rule: allow all"
  }

  # Rate limiting: 100 requests per minute per IP
  rule {
    action   = "rate_based_ban"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
      ban_duration_sec = 600 # 10-minute ban
    }
    description = "Rate limit: 100 req/min per IP"
  }

  # Block specific countries (example: North Korea, Iran)
  rule {
    action   = "deny(403)"
    priority = 2000
    match {
      expr {
        expression = "origin.region_code == 'KP' || origin.region_code == 'IR'"
      }
    }
    description = "Block traffic from specific countries"
  }

  # OWASP ModSecurity Core Rule Set (CRS)
  rule {
    action   = "deny(403)"
    priority = 3000
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-stable')"
      }
    }
    description = "OWASP: Block XSS attacks"
  }

  rule {
    action   = "deny(403)"
    priority = 3001
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('sqli-stable')"
      }
    }
    description = "OWASP: Block SQL injection"
  }

  # Advanced DDoS protection (Adaptive Protection)
  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = true
    }
  }
}
```

**Key Rules:**

1. **Rate Limiting**: 100 requests/minute per IP (adjust based on traffic patterns)
2. **Geo-blocking**: Block specific countries (compliance/security)
3. **OWASP Protection**: Pre-configured rules for XSS, SQLi, LFI, RCE
4. **Adaptive Protection**: Machine learning-based DDoS detection

---

### Attach Cloud Armor to Backend Service

```hcl
resource "google_compute_backend_service" "apigee_backend" {
  # ... other config ...

  security_policy = var.enable_cloud_armor ? google_compute_security_policy.apigee_armor[0].id : null
}
```

---

## Complete Terraform Examples

### Example 1: Minimal Configuration (Google-Managed Certificate)

```hcl
# versions.tf
terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

# variables.tf
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (devtest, dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "GCP region"
  type        = string
  default     = "us-central1"
}

variable "environment_group_hostnames" {
  description = "List of hostnames for environment group"
  type        = list(string)
  default     = ["api-devtest.portcon.com"]
}

# main.tf
data "google_compute_network" "apigee_vpc" {
  name    = "pcc-apigee-vpc-${var.environment}"
  project = var.project_id
}

data "google_apigee_organization" "org" {
  org_id = var.project_id
}

data "google_apigee_instance" "instance" {
  org_id = data.google_apigee_organization.org.id
  name   = "pcc-instance-${var.environment}"
}

# 1. SSL Certificate
resource "google_compute_managed_ssl_certificate" "apigee_cert" {
  name    = "pcc-apigee-cert-${var.environment}"
  project = var.project_id

  managed {
    domains = var.environment_group_hostnames
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 2. Health Check
resource "google_compute_health_check" "apigee_health" {
  name                = "pcc-apigee-health-${var.environment}"
  project             = var.project_id
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  https_health_check {
    port         = 443
    request_path = "/healthz/ingress"
    host         = var.environment_group_hostnames[0]
  }
}

# 3. Network Endpoint Group
resource "google_compute_network_endpoint_group" "apigee_neg" {
  name    = "pcc-apigee-neg-${var.environment}"
  project = var.project_id
  network = data.google_compute_network.apigee_vpc.id
  zone    = "${var.region}-a"

  network_endpoint_type = "INTERNET_IP_PORT"
}

resource "google_compute_network_endpoint" "apigee_endpoint" {
  network_endpoint_group = google_compute_network_endpoint_group.apigee_neg.name
  project                = var.project_id
  zone                   = google_compute_network_endpoint_group.apigee_neg.zone

  ip_address = data.google_apigee_instance.instance.host
  port       = 443
}

# 4. Backend Service
resource "google_compute_backend_service" "apigee_backend" {
  name        = "pcc-apigee-backend-${var.environment}"
  project     = var.project_id
  protocol    = "HTTPS"
  port_name   = "https"
  timeout_sec = 30

  backend {
    group          = google_compute_network_endpoint_group.apigee_neg.id
    balancing_mode = "RATE"
    max_rate_per_endpoint = 100
  }

  health_checks = [google_compute_health_check.apigee_health.id]

  log_config {
    enable      = true
    sample_rate = 1.0
  }
}

# 5. URL Map
resource "google_compute_url_map" "apigee_url_map" {
  name            = "pcc-apigee-url-map-${var.environment}"
  project         = var.project_id
  default_service = google_compute_backend_service.apigee_backend.id
}

# 6. SSL Policy
resource "google_compute_ssl_policy" "modern_tls" {
  name            = "pcc-apigee-modern-tls-${var.environment}"
  project         = var.project_id
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

# 7. HTTPS Target Proxy
resource "google_compute_target_https_proxy" "apigee_https_proxy" {
  name             = "pcc-apigee-https-proxy-${var.environment}"
  project          = var.project_id
  url_map          = google_compute_url_map.apigee_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.apigee_cert.id]
  ssl_policy       = google_compute_ssl_policy.modern_tls.id
}

# 8. Global Static IP
resource "google_compute_global_address" "apigee_external_ip" {
  name    = "pcc-apigee-external-ip-${var.environment}"
  project = var.project_id
}

# 9. HTTPS Forwarding Rule
resource "google_compute_global_forwarding_rule" "apigee_https" {
  name                  = "pcc-apigee-https-${var.environment}"
  project               = var.project_id
  ip_address            = google_compute_global_address.apigee_external_ip.address
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.apigee_https_proxy.id
}

# 10. HTTP to HTTPS Redirect
resource "google_compute_url_map" "apigee_http_redirect" {
  name    = "pcc-apigee-http-redirect-${var.environment}"
  project = var.project_id

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "apigee_http_redirect" {
  name    = "pcc-apigee-http-redirect-${var.environment}"
  project = var.project_id
  url_map = google_compute_url_map.apigee_http_redirect.id
}

resource "google_compute_global_forwarding_rule" "apigee_http_redirect" {
  name                  = "pcc-apigee-http-redirect-${var.environment}"
  project               = var.project_id
  ip_address            = google_compute_global_address.apigee_external_ip.address
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.apigee_http_redirect.id
}

# outputs.tf
output "load_balancer_ip" {
  description = "External IP address of load balancer"
  value       = google_compute_global_address.apigee_external_ip.address
}

output "certificate_status" {
  description = "Status of SSL certificate"
  value       = google_compute_managed_ssl_certificate.apigee_cert.certificate_status
}

output "apigee_hostnames" {
  description = "Hostnames configured for Apigee"
  value       = var.environment_group_hostnames
}
```

---

### Example 2: Production Configuration with Cloud Armor

See Appendix A for full production configuration including Cloud Armor.

---

## Multi-Environment Deployment Patterns

### Pattern 1: Separate Apigee Organizations per Environment

**Architecture:**

- 4 separate GCP projects (devtest, dev, staging, prod)
- 4 separate Apigee organizations (one per project)
- 4 separate load balancers (one per project)

**Pros:**
- Complete isolation between environments
- Independent scaling and configuration
- No risk of cross-environment traffic

**Cons:**
- Higher operational complexity (4x resources to manage)
- Higher cost (4x load balancers, 4x Apigee instances)

**Terraform Structure:**

```
pcc-foundation-infra/
└── terraform/
    └── environments/
        ├── devtest/
        │   └── main.tf (calls apigee-traffic module)
        ├── dev/
        │   └── main.tf
        ├── staging/
        │   └── main.tf
        └── prod/
            └── main.tf
```

**Module Invocation:**

```hcl
# environments/devtest/main.tf
module "apigee_traffic" {
  source = "../../modules/apigee-traffic-routing"

  project_id                 = "pcc-prj-apigee-devtest"
  environment                = "devtest"
  region                     = "us-central1"
  environment_group_hostnames = ["api-devtest.portcon.com"]
  enable_cloud_armor         = false
  dns_project_id             = "pcc-prj-dns"
}
```

---

### Pattern 2: Shared Apigee Organization with Multiple Environments

**Architecture:**

- 1 Apigee organization (e.g., in `pcc-prj-apigee-shared`)
- Multiple Apigee environments (devtest, dev, staging, prod)
- 4 separate load balancers (one per environment)
- Each load balancer routes to same Apigee instance but different environment groups

**Pros:**
- Lower cost (1 Apigee organization)
- Simplified management (single Apigee console)
- Shared API proxy deployment pipeline

**Cons:**
- Less isolation (all environments in same org)
- Shared quota limits
- Potential security risk (lateral movement)

**Not Recommended for PCC** (per requirements: separate organizations)

---

## Monitoring and Observability

### Load Balancer Metrics

**Key Metrics to Monitor:**

1. **Request Count**: Total requests per second
2. **Latency**: p50, p95, p99 response times
3. **Error Rate**: 4xx, 5xx error percentages
4. **Backend Latency**: Time spent in Apigee
5. **Certificate Status**: Certificate expiration alerts

**Cloud Monitoring Dashboard:**

```hcl
resource "google_monitoring_dashboard" "apigee_lb_dashboard" {
  dashboard_json = jsonencode({
    displayName = "PCC Apigee Load Balancer - ${var.environment}"
    mosaicLayout = {
      columns = 12
      tiles = [
        {
          width  = 6
          height = 4
          widget = {
            title = "Request Rate"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"https_lb_rule\" AND resource.labels.forwarding_rule_name=\"pcc-apigee-https-${var.environment}\" AND metric.type=\"loadbalancing.googleapis.com/https/request_count\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_RATE"
                    }
                  }
                }
              }]
            }
          }
        },
        {
          width  = 6
          height = 4
          widget = {
            title = "Latency (p95)"
            xyChart = {
              dataSets = [{
                timeSeriesQuery = {
                  timeSeriesFilter = {
                    filter = "resource.type=\"https_lb_rule\" AND metric.type=\"loadbalancing.googleapis.com/https/total_latencies\""
                    aggregation = {
                      alignmentPeriod  = "60s"
                      perSeriesAligner = "ALIGN_DELTA"
                      crossSeriesReducer = "REDUCE_PERCENTILE_95"
                    }
                  }
                }
              }]
            }
          }
        }
      ]
    }
  })
}
```

---

### SSL Certificate Expiration Alerts

```hcl
resource "google_monitoring_alert_policy" "cert_expiration" {
  display_name = "SSL Certificate Expiration - ${var.environment}"
  combiner     = "OR"

  conditions {
    display_name = "Certificate expires in 30 days"
    condition_threshold {
      filter          = "resource.type=\"https_lb_rule\" AND metric.type=\"loadbalancing.googleapis.com/https/frontend_tcp_rtt\""
      duration        = "0s"
      comparison      = "COMPARISON_GT"
      threshold_value = 0
    }
  }

  notification_channels = [var.alert_notification_channel]

  alert_strategy {
    auto_close = "2592000s" # 30 days
  }
}
```

**Manual Certificate Monitoring:**

For custom certificates, monitor expiration via external tools:

```bash
# Check certificate expiration
openssl s_client -connect api-devtest.portcon.com:443 -servername api-devtest.portcon.com </dev/null 2>/dev/null | openssl x509 -noout -dates

# Example output:
# notBefore=Jan  1 00:00:00 2025 GMT
# notAfter=Apr  1 23:59:59 2025 GMT
```

---

### Load Balancer Logs

Enable Cloud Logging for load balancer traffic:

```hcl
resource "google_compute_backend_service" "apigee_backend" {
  # ... other config ...

  log_config {
    enable      = true
    sample_rate = 1.0 # Adjust for cost (0.01 = 1% sampling)
  }
}
```

**Log Query Examples:**

```sql
-- View all 5xx errors
resource.type="https_lb_rule"
httpRequest.status>=500

-- View slow requests (>2s)
resource.type="https_lb_rule"
httpRequest.latency.seconds>2

-- View requests blocked by Cloud Armor
resource.type="https_lb_rule"
jsonPayload.enforcedSecurityPolicy.name!=""
```

---

## Troubleshooting

### Common Issues

#### Issue 1: SSL Certificate Stuck in PROVISIONING

**Symptoms:**

```
Certificate Status: PROVISIONING (stuck for >30 minutes)
```

**Cause:** Domain validation failed (DNS not configured or HTTP challenge blocked)

**Diagnosis:**

```bash
# Check DNS resolution
nslookup api-devtest.portcon.com

# Check if domain resolves to load balancer IP
dig api-devtest.portcon.com +short

# Test HTTP challenge path
curl -v http://api-devtest.portcon.com/.well-known/acme-challenge/test
```

**Solution:**

1. Verify DNS A record points to load balancer IP
2. Ensure HTTP forwarding rule (port 80) exists for domain validation
3. Check firewall rules allow HTTP traffic to load balancer
4. Wait up to 60 minutes for certificate issuance

---

#### Issue 2: 502 Bad Gateway from Load Balancer

**Symptoms:**

```
HTTP/1.1 502 Bad Gateway
```

**Cause:** Backend (Apigee) not reachable or failing health checks

**Diagnosis:**

```bash
# Check backend service health
gcloud compute backend-services get-health pcc-apigee-backend-devtest \
  --global --project=pcc-prj-apigee-devtest

# Expected output:
# status: HEALTHY
```

**Possible Causes:**

1. Apigee instance not ready (still provisioning)
2. Network endpoint group IP incorrect
3. Health check path incorrect (`/healthz/ingress`)
4. Health check hostname not matching environment group hostname

**Solution:**

```bash
# Verify Apigee instance host
gcloud apigee instances describe pcc-instance-devtest \
  --organization=pcc-prj-apigee-devtest

# Check NEG endpoints
gcloud compute network-endpoint-groups describe pcc-apigee-neg-devtest \
  --zone=us-central1-a

# Test health check manually
curl -v https://<apigee-instance-ip>/healthz/ingress \
  -H "Host: api-devtest.portcon.com"
```

---

#### Issue 3: HTTPS Works but HTTP to HTTPS Redirect Not Working

**Symptoms:**

```
HTTP requests return connection refused or timeout
```

**Cause:** HTTP forwarding rule missing or misconfigured

**Solution:**

Verify HTTP forwarding rule exists:

```bash
gcloud compute forwarding-rules list \
  --filter="name:pcc-apigee-http-redirect" \
  --global
```

Ensure it points to HTTP target proxy with redirect URL map.

---

#### Issue 4: Cloud Armor Blocking Legitimate Traffic

**Symptoms:**

```
HTTP/1.1 403 Forbidden
```

**Cause:** Cloud Armor rule blocking IP or request pattern

**Diagnosis:**

Check Cloud Armor logs:

```sql
resource.type="http_load_balancer"
jsonPayload.enforcedSecurityPolicy.name="pcc-apigee-armor-prod"
jsonPayload.enforcedSecurityPolicy.outcome="DENY"
```

**Solution:**

1. Identify blocked IP in logs
2. Add IP to allowlist in Cloud Armor policy:

```hcl
resource "google_compute_security_policy" "apigee_armor" {
  # ... existing rules ...

  rule {
    action   = "allow"
    priority = 500
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["203.0.113.0/24"] # Allowlisted IP range
      }
    }
    description = "Allow traffic from trusted partner"
  }
}
```

---

## Migration and Rollback Procedures

### Certificate Migration (Google-Managed to Custom)

**Scenario:** Migrating from Google-managed certificate to custom wildcard certificate

**Steps:**

1. **Obtain Custom Certificate**

```bash
# Example: Let's Encrypt via Certbot
certbot certonly --manual --preferred-challenges dns \
  -d *.portcon.com -d portcon.com
```

2. **Upload Certificate to Secret Manager**

```bash
gcloud secrets create pcc-apigee-tls-cert-prod \
  --replication-policy=automatic \
  --data-file=/etc/letsencrypt/live/portcon.com/fullchain.pem

gcloud secrets create pcc-apigee-tls-key-prod \
  --replication-policy=automatic \
  --data-file=/etc/letsencrypt/live/portcon.com/privkey.pem
```

3. **Update Terraform Configuration**

```hcl
# Replace google_compute_managed_ssl_certificate with custom certificate
resource "google_compute_ssl_certificate" "apigee_custom_cert" {
  name_prefix = "pcc-apigee-custom-cert-prod-"
  project     = var.project_id

  certificate = data.google_secret_manager_secret_version.tls_cert.secret_data
  private_key = data.google_secret_manager_secret_version.tls_key.secret_data

  lifecycle {
    create_before_destroy = true
  }
}

resource "google_compute_target_https_proxy" "apigee_https_proxy" {
  # Update to use custom certificate
  ssl_certificates = [google_compute_ssl_certificate.apigee_custom_cert.id]
  # ... other config ...
}
```

4. **Apply Terraform**

```bash
terraform plan -out=migration.tfplan
terraform apply migration.tfplan
```

**Rollback:**

If custom certificate fails, revert to Google-managed certificate:

```bash
terraform apply -auto-approve -replace=google_compute_target_https_proxy.apigee_https_proxy
```

---

### Load Balancer Configuration Rollback

**Scenario:** New load balancer configuration causes issues

**Rollback Strategy:**

1. **Terraform State Backup**

```bash
terraform state pull > terraform.tfstate.backup
```

2. **Revert to Previous Configuration**

```bash
git checkout HEAD~1 -- terraform/
terraform apply -auto-approve
```

3. **DNS TTL Consideration**

- If DNS was changed, wait for TTL expiry (300-3600 seconds)
- Consider lowering DNS TTL before major changes

---

## Cost Optimization

### Cost Breakdown (Approximate Monthly Costs)

| Component | Configuration | Estimated Cost |
|-----------|---------------|----------------|
| **External HTTPS Load Balancer** | 1 global LB, 5 forwarding rules | ~$18/month + data charges |
| **SSL Certificates** | Google-managed (1 cert) | $0 |
| **SSL Certificates** | Custom (manual renewal) | $0 - $200/year (depends on CA) |
| **Cloud Armor** | 1 security policy, 1M requests | ~$35/month |
| **Cloud CDN** (optional) | 1 TB egress | ~$80/month |
| **Cloud Logging** | 100% sampling, 10M requests/day | ~$50/month |
| **DNS (Cloud DNS)** | 5 A records, 100M queries | ~$0.40/month |
| **Total (without Cloud Armor)** | | **~$70/month** |
| **Total (with Cloud Armor)** | | **~$105/month** |

**Data Transfer Costs:**

- Egress to internet: $0.085/GB (us-central1)
- Ingress: Free
- Cloud CDN cache hit: $0.02/GB (cheaper than egress)

---

### Cost Optimization Tips

1. **Enable Cloud CDN for Cacheable APIs:**

```hcl
resource "google_compute_backend_service" "apigee_backend" {
  enable_cdn = true # Enable for cacheable GET APIs

  cdn_policy {
    cache_mode  = "CACHE_ALL_STATIC"
    default_ttl = 3600
    max_ttl     = 86400
  }
}
```

2. **Reduce Load Balancer Log Sampling:**

```hcl
log_config {
  enable      = true
  sample_rate = 0.1 # Log 10% of requests (reduce from 100%)
}
```

3. **Use Cloud Armor Only for Production:**

```hcl
variable "enable_cloud_armor" {
  type    = bool
  default = false # Set to true only for prod
}
```

4. **Optimize DNS TTL:**

- Development: 300 seconds (fast iteration)
- Production: 3600 seconds (reduce query costs)

5. **Right-Size Health Check Intervals:**

```hcl
check_interval_sec = 30 # Increase from 10s to reduce health check traffic
```

---

## References

### Official Documentation

- [Cloud Load Balancing Overview](https://cloud.google.com/load-balancing/docs)
- [SSL Certificates for Load Balancers](https://cloud.google.com/load-balancing/docs/ssl-certificates)
- [Google-Managed SSL Certificates](https://cloud.google.com/load-balancing/docs/ssl-certificates/google-managed-certs)
- [SSL Policies](https://cloud.google.com/load-balancing/docs/ssl-policies-concepts)
- [Cloud Armor Security Policies](https://cloud.google.com/armor/docs/security-policy-concepts)
- [Apigee X Environment Groups](https://cloud.google.com/apigee/docs/api-platform/fundamentals/environments-overview#environment-groups)

### Terraform Resources

- [google_compute_managed_ssl_certificate](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_managed_ssl_certificate)
- [google_compute_ssl_certificate](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_ssl_certificate)
- [google_compute_ssl_policy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_ssl_policy)
- [google_compute_global_forwarding_rule](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_global_forwarding_rule)
- [google_compute_target_https_proxy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_target_https_proxy)
- [google_compute_backend_service](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_backend_service)
- [google_compute_security_policy](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_security_policy)
- [google_dns_record_set](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/dns_record_set)

### Community Resources

- [Apigee X Load Balancing Best Practices](https://cloud.google.com/apigee/docs/api-platform/get-started/load-balancing)
- [TLS Best Practices for GCP](https://cloud.google.com/load-balancing/docs/ssl-policies-concepts#tls-best-practices)
- [Cloud Armor Rate Limiting Examples](https://cloud.google.com/armor/docs/rate-limiting-overview)

### PCC Project References

- `@docs/apigee-x-networking-specification.md`: Apigee networking infrastructure (VPC, NAT, instances)
- `@docs/security-iam-blueprint.md`: Security and IAM best practices
- `@core/pcc-tf-library/.claude/docs/terraform-patterns.md`: Terraform patterns

---

## Appendix A: Production Configuration with Cloud Armor

### Complete Production Example

```hcl
# terraform/modules/apigee-traffic-routing/main.tf

# 1. SSL Certificate (Google-managed)
resource "google_compute_managed_ssl_certificate" "apigee_cert" {
  name    = "pcc-apigee-cert-${var.environment}"
  project = var.project_id

  managed {
    domains = var.environment_group_hostnames
  }

  lifecycle {
    create_before_destroy = true
  }
}

# 2. SSL Policy (TLS 1.2+)
resource "google_compute_ssl_policy" "production_tls" {
  name            = "pcc-apigee-production-tls-${var.environment}"
  project         = var.project_id
  profile         = "MODERN"
  min_tls_version = "TLS_1_2"
}

# 3. Health Check
resource "google_compute_health_check" "apigee_health" {
  name                = "pcc-apigee-health-${var.environment}"
  project             = var.project_id
  check_interval_sec  = 10
  timeout_sec         = 5
  healthy_threshold   = 2
  unhealthy_threshold = 3

  https_health_check {
    port         = 443
    request_path = "/healthz/ingress"
    host         = var.environment_group_hostnames[0]
  }
}

# 4. Cloud Armor Security Policy
resource "google_compute_security_policy" "apigee_armor" {
  count   = var.enable_cloud_armor ? 1 : 0
  name    = "pcc-apigee-armor-${var.environment}"
  project = var.project_id

  # Default: Allow all
  rule {
    action   = "allow"
    priority = 2147483647
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    description = "Default allow rule"
  }

  # Rate limiting
  rule {
    action   = "rate_based_ban"
    priority = 1000
    match {
      versioned_expr = "SRC_IPS_V1"
      config {
        src_ip_ranges = ["*"]
      }
    }
    rate_limit_options {
      conform_action = "allow"
      exceed_action  = "deny(429)"
      enforce_on_key = "IP"
      rate_limit_threshold {
        count        = 100
        interval_sec = 60
      }
      ban_duration_sec = 600
    }
    description = "Rate limit: 100 req/min per IP"
  }

  # OWASP protection
  rule {
    action   = "deny(403)"
    priority = 3000
    match {
      expr {
        expression = "evaluatePreconfiguredExpr('xss-stable') || evaluatePreconfiguredExpr('sqli-stable')"
      }
    }
    description = "OWASP protection"
  }

  # Adaptive DDoS protection
  adaptive_protection_config {
    layer_7_ddos_defense_config {
      enable = true
    }
  }
}

# 5. Network Endpoint Group
resource "google_compute_network_endpoint_group" "apigee_neg" {
  name    = "pcc-apigee-neg-${var.environment}"
  project = var.project_id
  network = data.google_compute_network.apigee_vpc.id
  zone    = "${var.region}-a"

  network_endpoint_type = "INTERNET_IP_PORT"
}

resource "google_compute_network_endpoint" "apigee_endpoint" {
  network_endpoint_group = google_compute_network_endpoint_group.apigee_neg.name
  project                = var.project_id
  zone                   = google_compute_network_endpoint_group.apigee_neg.zone

  ip_address = data.google_apigee_instance.instance.host
  port       = 443
}

# 6. Backend Service
resource "google_compute_backend_service" "apigee_backend" {
  name                    = "pcc-apigee-backend-${var.environment}"
  project                 = var.project_id
  protocol                = "HTTPS"
  port_name               = "https"
  timeout_sec             = 30
  session_affinity        = "GENERATED_COOKIE"
  affinity_cookie_ttl_sec = 3600

  backend {
    group                 = google_compute_network_endpoint_group.apigee_neg.id
    balancing_mode        = "RATE"
    max_rate_per_endpoint = 100
  }

  health_checks = [google_compute_health_check.apigee_health.id]

  log_config {
    enable      = true
    sample_rate = 1.0
  }

  security_policy = var.enable_cloud_armor ? google_compute_security_policy.apigee_armor[0].id : null
}

# 7. URL Map
resource "google_compute_url_map" "apigee_url_map" {
  name            = "pcc-apigee-url-map-${var.environment}"
  project         = var.project_id
  default_service = google_compute_backend_service.apigee_backend.id

  host_rule {
    hosts        = var.environment_group_hostnames
    path_matcher = "apigee-paths"
  }

  path_matcher {
    name            = "apigee-paths"
    default_service = google_compute_backend_service.apigee_backend.id
  }
}

# 8. HTTPS Target Proxy
resource "google_compute_target_https_proxy" "apigee_https_proxy" {
  name             = "pcc-apigee-https-proxy-${var.environment}"
  project          = var.project_id
  url_map          = google_compute_url_map.apigee_url_map.id
  ssl_certificates = [google_compute_managed_ssl_certificate.apigee_cert.id]
  ssl_policy       = google_compute_ssl_policy.production_tls.id
}

# 9. Global Static IP
resource "google_compute_global_address" "apigee_external_ip" {
  name    = "pcc-apigee-external-ip-${var.environment}"
  project = var.project_id
}

# 10. HTTPS Forwarding Rule
resource "google_compute_global_forwarding_rule" "apigee_https" {
  name                  = "pcc-apigee-https-${var.environment}"
  project               = var.project_id
  ip_address            = google_compute_global_address.apigee_external_ip.address
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "443"
  target                = google_compute_target_https_proxy.apigee_https_proxy.id
}

# 11. HTTP to HTTPS Redirect
resource "google_compute_url_map" "apigee_http_redirect" {
  name    = "pcc-apigee-http-redirect-${var.environment}"
  project = var.project_id

  default_url_redirect {
    https_redirect         = true
    redirect_response_code = "MOVED_PERMANENTLY_DEFAULT"
    strip_query            = false
  }
}

resource "google_compute_target_http_proxy" "apigee_http_redirect" {
  name    = "pcc-apigee-http-redirect-${var.environment}"
  project = var.project_id
  url_map = google_compute_url_map.apigee_http_redirect.id
}

resource "google_compute_global_forwarding_rule" "apigee_http_redirect" {
  name                  = "pcc-apigee-http-redirect-${var.environment}"
  project               = var.project_id
  ip_address            = google_compute_global_address.apigee_external_ip.address
  ip_protocol           = "TCP"
  load_balancing_scheme = "EXTERNAL_MANAGED"
  port_range            = "80"
  target                = google_compute_target_http_proxy.apigee_http_redirect.id
}

# 12. DNS Records (Cloud DNS)
resource "google_dns_record_set" "apigee_hostnames" {
  count        = length(var.environment_group_hostnames)
  name         = "${var.environment_group_hostnames[count.index]}."
  type         = "A"
  ttl          = var.dns_ttl
  managed_zone = data.google_dns_managed_zone.portcon_zone.name
  project      = var.dns_project_id

  rrdatas = [google_compute_global_address.apigee_external_ip.address]
}

# Data sources
data "google_compute_network" "apigee_vpc" {
  name    = "pcc-apigee-vpc-${var.environment}"
  project = var.project_id
}

data "google_apigee_instance" "instance" {
  org_id = var.project_id
  name   = "pcc-instance-${var.environment}"
}

data "google_dns_managed_zone" "portcon_zone" {
  name    = "portcon-com"
  project = var.dns_project_id
}

# Outputs
output "load_balancer_ip" {
  description = "External IP address of load balancer"
  value       = google_compute_global_address.apigee_external_ip.address
}

output "certificate_status" {
  description = "Status of SSL certificate"
  value       = google_compute_managed_ssl_certificate.apigee_cert.certificate_status
}

output "apigee_hostnames" {
  description = "Hostnames configured for Apigee"
  value       = var.environment_group_hostnames
}
```

---

**END OF SPECIFICATION**

**Document Version:** 1.0
**Last Updated:** 2025-10-16
**Authors:** PCC Cloud Architecture Team
**Status:** Ready for Implementation

**Next Steps:**

1. Review with DevOps team
2. Create Terraform module in `pcc-foundation-infra/terraform/modules/apigee-traffic-routing`
3. Deploy to devtest environment first
4. Validate SSL certificate provisioning
5. Test traffic routing
6. Document any adjustments
7. Roll out to dev, staging, prod sequentially
