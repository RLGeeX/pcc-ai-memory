# Apigee X Networking Infrastructure - Terraform Specification

**Project:** PortCo Connect (PCC) - Apigee X Integration
**Environment:** dev-test
**Last Updated:** 2025-10-16
**Version:** 1.0

---

## Executive Summary

This document provides comprehensive Terraform specifications for deploying Apigee X networking infrastructure on Google Cloud Platform. Based on the Codex review, the Phase 1 plan was missing critical networking components that are **mandatory** for Apigee X functionality. This specification addresses those gaps with production-ready patterns following GCP best practices.

**Critical Finding:** Apigee X will not function without proper VPC peering, service networking, and regional networking infrastructure. These components must be provisioned before Apigee organization/instance creation.

---

## Table of Contents

1. [Architecture Overview](#architecture-overview)
2. [Networking Options](#networking-options)
3. [Resource Provisioning Order](#resource-provisioning-order)
4. [VPC and Subnet Requirements](#vpc-and-subnet-requirements)
5. [Service Networking and VPC Peering](#service-networking-and-vpc-peering)
6. [Apigee Instance Configuration](#apigee-instance-configuration)
7. [Cloud NAT for Outbound Connectivity](#cloud-nat-for-outbound-connectivity)
8. [Environment Groups and Host Aliases](#environment-groups-and-host-aliases)
9. [Apigee to GKE Connectivity](#apigee-to-gke-connectivity)
10. [IAM Permissions](#iam-permissions)
11. [IP Address Planning](#ip-address-planning)
12. [Terraform Module Structure](#terraform-module-structure)
13. [Complete Terraform Examples](#complete-terraform-examples)
14. [Integration with Existing GKE Infrastructure](#integration-with-existing-gke-infrastructure)
15. [Cost Optimization](#cost-optimization)
16. [Security Considerations](#security-considerations)
17. [Troubleshooting](#troubleshooting)
18. [References](#references)

---

## Architecture Overview

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Internet / Clients                        │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│              External HTTPS Load Balancer (L7)                   │
│              (Environment Group Hostname Routing)                │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                  Apigee X Runtime (Instance)                     │
│                  Region: us-east4                             │
│                  CIDR: 10.87.8.0/22 (/22 + /28)                 │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      │ VPC Peering via Service Networking
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                     Customer VPC Network                         │
│                  (pcc-apigee-vpc-devtest)                       │
│                                                                  │
│  ┌────────────────────────────────────────────────────┐        │
│  │  Subnet: apigee-reserved-range                     │        │
│  │  CIDR: 10.87.0.0/16 (allocated for VPC peering)   │        │
│  │  Purpose: VPC_PEERING (Service Networking)        │        │
│  └────────────────────────────────────────────────────┘        │
│                                                                  │
│  ┌────────────────────────────────────────────────────┐        │
│  │  Cloud Router + Cloud NAT                          │        │
│  │  (Outbound internet connectivity)                  │        │
│  └────────────────────────────────────────────────────┘        │
│                                                                  │
└─────────────────────┬───────────────────────────────────────────┘
                      │
                      │ Private Service Connect (PSC)
                      │ or Direct Peering (if in same VPC)
                      ▼
┌─────────────────────────────────────────────────────────────────┐
│                     GKE Cluster (Backend)                        │
│                  Cluster: pcc-gke-cluster                        │
│                  VPC: [existing GKE VPC]                        │
│                                                                  │
│  ┌────────────────────────────────────────────────────┐        │
│  │  Internal Load Balancer (ILB)                      │        │
│  │  + Network Endpoint Groups (NEGs)                  │        │
│  │  Private IP: 10.x.x.x                             │        │
│  └────────────────────────────────────────────────────┘        │
│                                                                  │
│  ┌────────────────────────────────────────────────────┐        │
│  │  .NET Microservices                                │        │
│  │  (pcc-user-api, pcc-auth-api, etc.)               │        │
│  └────────────────────────────────────────────────────┘        │
└─────────────────────────────────────────────────────────────────┘
```

### Key Components

1. **Apigee VPC Network**: Dedicated VPC for Apigee X infrastructure
2. **Service Networking Connection**: Automated VPC peering between customer VPC and Apigee-managed VPC
3. **Apigee Organization**: Top-level Apigee resource (one per GCP project)
4. **Apigee Instance**: Regional runtime deployment requiring /22 + /28 CIDR ranges
5. **Apigee Environment**: Logical grouping of API proxies (e.g., devtest, staging, prod)
6. **Environment Group**: Maps hostnames to environments for traffic routing
7. **Cloud NAT**: Provides outbound internet connectivity for Apigee runtime
8. **Backend Connectivity**: Private Service Connect or VPC peering to GKE

---

## Networking Options

Apigee X offers two networking models:

### Option 1: VPC Peering (Recommended for PCC)

**Characteristics:**
- Requires dedicated IP ranges (/22 + /28) in customer VPC
- Uses Service Networking for automated VPC peering
- Apigee runtime gets private IPs from allocated range
- Enables direct connectivity to backends in peered VPC

**Use Cases:**
- Private backend services in same VPC
- Existing VPC infrastructure
- Predictable IP addressing requirements

**Limitations:**
- VPC peering is non-transitive (cannot reach backends beyond one hop)
- Requires careful IP range planning to avoid conflicts
- IP ranges cannot be changed after instance creation

### Option 2: Non-VPC Peering (Private Service Connect)

**Characteristics:**
- No dedicated IP ranges required
- Uses Private Service Connect (PSC) endpoints
- More flexible for multi-VPC architectures

**Use Cases:**
- Multi-cloud or multi-VPC backends
- Avoiding VPC peering transitivity limitations
- Simplified IP management

**Recommendation for PCC:**
Use **VPC Peering** initially for simplicity since GKE backends are in the same GCP project. Migrate to PSC later if multi-region or cross-project connectivity is needed.

---

## Resource Provisioning Order

**Critical:** Resources must be created in this exact sequence to satisfy dependencies.

```
1. Enable APIs
   ├── apigee.googleapis.com
   ├── servicenetworking.googleapis.com
   ├── compute.googleapis.com
   └── dns.googleapis.com

2. Create VPC Network
   └── google_compute_network

3. Reserve IP Address Ranges
   ├── google_compute_global_address (/16 for Service Networking)
   └── google_compute_global_address (additional ranges as needed)

4. Create Service Networking Connection
   └── google_service_networking_connection
       (Establishes VPC peering to Apigee)

5. Configure Encryption (Optional but Recommended)
   ├── google_kms_key_ring
   ├── google_kms_crypto_key
   ├── google_project_service_identity (Apigee SA)
   └── google_kms_crypto_key_iam_member

6. Create Apigee Organization
   └── google_apigee_organization
       (Depends on Service Networking Connection + KMS)

7. Create Apigee Instance
   └── google_apigee_instance
       (Requires /22 IP range, takes 20-30 minutes)

8. Configure Cloud NAT
   ├── google_compute_router
   └── google_compute_router_nat

9. Create Apigee Environment
   └── google_apigee_environment

10. Create Environment Group
    └── google_apigee_environment_group

11. Attach Environment to Group
    └── google_apigee_envgroup_attachment

12. Configure NAT Addresses (Optional)
    └── google_apigee_nat_address
```

**Wait Times:**
- Apigee Organization: 5-10 minutes
- Apigee Instance: 20-30 minutes (per region)
- Service Networking Connection: 2-5 minutes

---

## VPC and Subnet Requirements

### VPC Network Configuration

```hcl
resource "google_compute_network" "apigee_network" {
  name                    = "pcc-apigee-vpc-${var.environment}"
  project                 = var.project_id
  auto_create_subnetworks = false
  description             = "Dedicated VPC for Apigee X infrastructure (${var.environment})"
}
```

**Key Configuration:**
- `auto_create_subnetworks = false`: Manual subnet control for better IP management
- Name convention: `pcc-apigee-vpc-{environment}`

### Reserved IP Ranges for Service Networking

Apigee requires a **global address range** with `purpose = "VPC_PEERING"` for Service Networking.

```hcl
# Primary range for VPC peering (required)
resource "google_compute_global_address" "apigee_range" {
  name          = "apigee-vpc-peering-range-${var.environment}"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16  # /16 provides 65,536 IPs
  network       = google_compute_network.apigee_network.id
  description   = "Reserved IP range for Apigee VPC peering (${var.environment})"
}
```

**Critical Parameters:**
- `purpose = "VPC_PEERING"`: Required for Service Networking
- `address_type = "INTERNAL"`: Private IP space
- `prefix_length = 16`: Recommended for dev-test (adjust for production)
- `network`: Must reference the VPC where Apigee will be deployed

**IP Range Sizing:**
- `/16` (65,536 IPs): Recommended for multi-region Apigee deployments
- `/21` (2,048 IPs): Minimum for single-region with growth
- `/22` (1,024 IPs): Minimum for proof-of-concept

---

## Service Networking and VPC Peering

### Service Networking Connection

Service Networking automates VPC peering between the customer VPC and Google-managed Apigee VPC.

```hcl
resource "google_service_networking_connection" "apigee_vpc_connection" {
  network                 = google_compute_network.apigee_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.apigee_range.name]

  # Prevent accidental deletion
  deletion_policy = "ABANDON"
}
```

**Key Behaviors:**
- Creates a VPC peering connection named `servicenetworking-googleapis-com`
- Automatically configures routes between customer VPC and Apigee VPC
- `deletion_policy = "ABANDON"`: Prevents Terraform from deleting the peering when resource is destroyed (Google manages lifecycle)

**Verification:**
```bash
# List VPC peerings
gcloud compute networks peerings list --network=pcc-apigee-vpc-devtest

# Expected output shows:
# - servicenetworking-googleapis-com (ACTIVE)
```

### VPC Peering Considerations

**Limitations:**
- **Non-Transitive**: Apigee cannot reach resources in VPCs peered to your VPC (only one hop)
- **Single Connection**: Only one Service Networking connection per VPC
- **Immutable Ranges**: IP ranges cannot be changed after Service Networking connection is established

**Workarounds for Transitivity:**
- Use Private Service Connect (PSC) for multi-VPC backends
- Deploy backends in the same VPC as Apigee
- Use Shared VPC architecture

---

## Apigee Instance Configuration

### Apigee Organization

The organization is the top-level Apigee resource (one per GCP project).

```hcl
resource "google_apigee_organization" "apigee_org" {
  display_name                         = "PCC Apigee Organization (${var.environment})"
  description                          = "Apigee organization for PortCo Connect ${var.environment} environment"
  project_id                           = var.project_id
  analytics_region                     = var.apigee_analytics_region  # e.g., "us-east4"
  runtime_type                         = "CLOUD"
  billing_type                         = "EVALUATION"  # or "SUBSCRIPTION" for production

  # VPC Peering configuration
  authorized_network                   = google_compute_network.apigee_network.id

  # Encryption at rest (optional but recommended)
  runtime_database_encryption_key_name = google_kms_crypto_key.apigee_db_key.id

  # Dependency: Must wait for Service Networking + KMS
  depends_on = [
    google_service_networking_connection.apigee_vpc_connection,
    google_kms_crypto_key_iam_member.apigee_sa_keyuser,
  ]
}
```

**Key Parameters:**
- `analytics_region`: Where analytics data is stored (must match instance region for single-region deployments)
- `runtime_type = "CLOUD"`: Required for Apigee X (not hybrid)
- `billing_type`:
  - `EVALUATION`: Free trial (limited to 90 days, no SLA)
  - `SUBSCRIPTION`: Production (requires contract)
- `authorized_network`: Enables VPC peering
- `runtime_database_encryption_key_name`: Optional CMEK for compliance

**Immutable Fields:**
- Cannot change `analytics_region` after creation
- Cannot switch between VPC peering and non-VPC peering modes

### Apigee Instance (Runtime Deployment)

Apigee instances are regional deployments of the runtime plane.

```hcl
resource "google_apigee_instance" "apigee_instance" {
  name                     = "pcc-apigee-instance-${var.environment}"
  location                 = var.apigee_instance_region  # e.g., "us-east4"
  description              = "Apigee runtime instance for ${var.environment} (us-east4)"
  display_name             = "PCC Instance (${var.environment})"
  org_id                   = google_apigee_organization.apigee_org.id

  # IP range allocation (REQUIRED for VPC peering mode)
  # Option 1: Specify exact CIDR
  ip_range = "10.87.8.0/22"  # Must be /22, from the /16 peering range

  # Option 2: Let Google auto-allocate from peering range
  # peering_cidr_range = "SLASH_22"

  # Disk encryption (optional)
  disk_encryption_key_name = google_kms_crypto_key.apigee_disk_key.id

  # Consumer accept list (optional, for PSC)
  # consumer_accept_list = ["PROJECT_ID_1", "PROJECT_ID_2"]
}
```

**Critical IP Range Requirements:**

1. **Exact CIDR (`ip_range`):**
   - Must be a `/22` block (1,024 IPs)
   - Must be within the `/16` range allocated in `google_compute_global_address`
   - Example: If peering range is `10.87.0.0/16`, instance can use `10.87.8.0/22`
   - **Immutable**: Cannot be changed after instance creation

2. **Auto-Allocation (`peering_cidr_range`):**
   - Use `"SLASH_22"` to let Google auto-assign
   - Simplifies management but less control over IP layout

3. **Additional /28 Range:**
   - Apigee also requires a `/28` range (16 IPs) for troubleshooting access
   - Automatically allocated by Google from the peering range
   - Not explicitly configured in Terraform

**Instance Sizing:**
- Evaluation: 1-2 nodes (limited capacity)
- Production: 3+ nodes (HA configuration)

**Provisioning Time:** 20-30 minutes per instance

---

## Cloud NAT for Outbound Connectivity

Apigee runtime requires internet access for:
- Calling external APIs (target backends)
- Certificate validation (HTTPS targets)
- Integration with third-party services

### Cloud Router

```hcl
resource "google_compute_router" "apigee_router" {
  name    = "pcc-apigee-router-${var.environment}"
  project = var.project_id
  region  = var.apigee_instance_region
  network = google_compute_network.apigee_network.id

  description = "Cloud Router for Apigee NAT (${var.environment})"

  bgp {
    asn = 64514  # Private ASN
  }
}
```

### Cloud NAT Gateway

```hcl
resource "google_compute_router_nat" "apigee_nat" {
  name    = "pcc-apigee-nat-${var.environment}"
  project = var.project_id
  router  = google_compute_router.apigee_router.name
  region  = var.apigee_instance_region

  nat_ip_allocate_option             = "AUTO_ONLY"  # or MANUAL_ONLY with specific IPs
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"  # or "TRANSLATIONS_ONLY", "ALL"
  }

  # Min/max ports per VM (optional)
  min_ports_per_vm = 64
  max_ports_per_vm = 512

  # Connection draining timeout
  icmp_idle_timeout_sec              = 30
  tcp_established_idle_timeout_sec   = 1200
  tcp_transitory_idle_timeout_sec    = 30
  tcp_time_wait_timeout_sec          = 120
  udp_idle_timeout_sec               = 30
}
```

**NAT IP Allocation Options:**

1. **AUTO_ONLY** (Recommended):
   - Google automatically allocates ephemeral IPs
   - Simpler management, lower cost
   - IPs may change during updates

2. **MANUAL_ONLY**:
   - Use specific static IPs (for IP allowlisting by external APIs)
   - Requires `google_compute_address` resources
   - Higher predictability, slightly higher cost

**Example with Manual IPs:**

```hcl
# Reserve static IPs for NAT
resource "google_compute_address" "apigee_nat_ips" {
  count        = 2  # Number of NAT IPs
  name         = "pcc-apigee-nat-ip-${count.index + 1}-${var.environment}"
  project      = var.project_id
  region       = var.apigee_instance_region
  address_type = "EXTERNAL"
}

resource "google_compute_router_nat" "apigee_nat" {
  name    = "pcc-apigee-nat-${var.environment}"
  # ... other config ...

  nat_ip_allocate_option = "MANUAL_ONLY"
  nat_ips                = google_compute_address.apigee_nat_ips[*].self_link
}
```

### Apigee NAT Address (Optional)

For advanced NAT control (e.g., IP allowlisting on external APIs):

```hcl
resource "google_apigee_nat_address" "apigee_static_nat" {
  name        = "pcc-apigee-nat-static-${var.environment}"
  instance_id = google_apigee_instance.apigee_instance.id
  activate    = true  # Immediately activate this NAT IP
}
```

**Use Cases:**
- Third-party APIs requiring IP allowlisting
- Compliance requirements for static egress IPs
- Advanced traffic auditing

---

## Environment Groups and Host Aliases

Environment Groups map external hostnames to Apigee environments for traffic routing.

### Apigee Environment

```hcl
resource "google_apigee_environment" "devtest_env" {
  org_id       = google_apigee_organization.apigee_org.id
  name         = "devtest"
  display_name = "DevTest Environment"
  description  = "Development and testing environment for PCC APIs"

  # Client IP resolution (optional)
  client_ip_resolution_config {
    header_index_algorithm {
      ip_header_name  = "X-Forwarded-For"
      ip_header_index = 1
    }
  }

  # Node configuration (optional)
  node_config {
    min_node_count = 2
    max_node_count = 4
  }
}
```

### Attach Environment to Instance

```hcl
resource "google_apigee_instance_attachment" "devtest_attachment" {
  instance_id = google_apigee_instance.apigee_instance.id
  environment = google_apigee_environment.devtest_env.name
}
```

**Critical:** Each environment must be attached to at least one instance before it can handle traffic.

### Environment Group (Hostname Routing)

```hcl
resource "google_apigee_envgroup" "api_group" {
  name     = "pcc-api-devtest"
  org_id   = google_apigee_organization.apigee_org.id
  hostnames = [
    "api-devtest.portcon.com",
    "api-devtest.pcc.internal"
  ]
}
```

**Hostname Requirements:**
- Must be fully qualified domain names (FQDNs)
- Requires DNS A/CNAME records pointing to load balancer
- Each hostname can only belong to one environment group

### Attach Environment to Group

```hcl
resource "google_apigee_envgroup_attachment" "devtest_group_attachment" {
  envgroup_id = google_apigee_envgroup.api_group.id
  environment = google_apigee_environment.devtest_env.name
}
```

**Traffic Flow:**
```
Client → DNS (api-devtest.portcon.com)
       → Load Balancer IP
       → Apigee Runtime
       → Environment Group (pcc-api-devtest)
       → Environment (devtest)
       → API Proxy → Backend
```

---

## Apigee to GKE Connectivity

Apigee needs private connectivity to GKE backend microservices.

### Option 1: Same VPC (Direct Peering) - Simplest

If GKE cluster is in the same VPC as Apigee:

```hcl
# GKE cluster in Apigee VPC
resource "google_container_cluster" "gke_cluster" {
  name     = "pcc-gke-cluster-${var.environment}"
  location = var.gke_region
  network  = google_compute_network.apigee_network.self_link
  subnetwork = google_compute_subnetwork.gke_subnet.self_link

  # ... other GKE config ...
}

# Apigee can directly reach ILB in same VPC
resource "google_compute_forwarding_rule" "gke_ilb" {
  name                  = "pcc-gke-ilb-${var.environment}"
  region                = var.gke_region
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.gke_backend.id
  network               = google_compute_network.apigee_network.self_link
  subnetwork            = google_compute_subnetwork.gke_subnet.self_link
  ip_address            = "10.87.128.10"  # Private IP
  ports                 = ["80", "443"]
}
```

**Apigee Target Configuration:**
```xml
<TargetEndpoint name="gke-backend">
  <HTTPTargetConnection>
    <URL>http://10.87.128.10/api/v1</URL>
  </HTTPTargetConnection>
</TargetEndpoint>
```

### Option 2: Separate VPCs (VPC Peering)

If GKE is in a different VPC:

```hcl
# Peer Apigee VPC with GKE VPC
resource "google_compute_network_peering" "apigee_to_gke" {
  name         = "apigee-to-gke-${var.environment}"
  network      = google_compute_network.apigee_network.self_link
  peer_network = google_compute_network.gke_network.self_link

  export_custom_routes = true
  import_custom_routes = true
}

resource "google_compute_network_peering" "gke_to_apigee" {
  name         = "gke-to-apigee-${var.environment}"
  network      = google_compute_network.gke_network.self_link
  peer_network = google_compute_network.apigee_network.self_link

  export_custom_routes = true
  import_custom_routes = true
}
```

**Limitation:** Cannot chain more than one peering hop (VPC peering is non-transitive).

### Option 3: Private Service Connect (PSC) - Most Flexible

For multi-VPC or cross-project backends:

**Step 1: Create PSC Service Attachment (in GKE VPC)**

```hcl
# NAT subnet required for PSC
resource "google_compute_subnetwork" "psc_nat_subnet" {
  name          = "psc-nat-subnet-${var.environment}"
  ip_cidr_range = "10.88.0.0/24"
  region        = var.gke_region
  network       = google_compute_network.gke_network.id
  purpose       = "PRIVATE_SERVICE_CONNECT"
}

# Service attachment to GKE ILB
resource "google_compute_service_attachment" "gke_psc_service" {
  name                  = "pcc-gke-psc-service-${var.environment}"
  region                = var.gke_region
  target_service        = google_compute_forwarding_rule.gke_ilb.self_link
  connection_preference = "ACCEPT_AUTOMATIC"

  nat_subnets = [google_compute_subnetwork.psc_nat_subnet.id]

  consumer_accept_lists {
    project_id_or_num = var.project_id
    connection_limit  = 10
  }
}
```

**Step 2: Create PSC Endpoint Attachment (in Apigee)**

```hcl
resource "google_apigee_endpoint_attachment" "gke_psc_endpoint" {
  org_id               = google_apigee_organization.apigee_org.id
  endpoint_attachment_id = "pcc-gke-psc-${var.environment}"
  location             = var.apigee_instance_region
  service_attachment   = google_compute_service_attachment.gke_psc_service.id
}
```

**Apigee Target Configuration:**
```xml
<TargetEndpoint name="gke-psc-backend">
  <HTTPTargetConnection>
    <URL>http://{psc-endpoint-ip}/api/v1</URL>
  </HTTPTargetConnection>
</TargetEndpoint>
```

**Advantages of PSC:**
- No VPC peering transitivity limitations
- Works across projects and organizations
- Supports cross-region connectivity
- Better isolation and security

### Recommended Approach for PCC Phase 1

Use **Option 1 (Same VPC)** initially for simplicity:

1. Deploy GKE in a subnet of the Apigee VPC
2. Use Internal Load Balancer (ILB) with private IP
3. Apigee targets the ILB IP directly
4. Migrate to PSC in Phase 2 if multi-region is needed

---

## IAM Permissions

### Required Roles for Terraform Execution

The service account or user running Terraform must have:

```hcl
# Predefined roles (recommended)
roles = [
  "roles/apigee.admin",                      # Manage Apigee resources
  "roles/compute.networkAdmin",              # Manage VPC, subnets, NAT
  "roles/servicenetworking.networksAdmin",   # Create Service Networking connections
  "roles/iam.serviceAccountAdmin",           # Manage service accounts
  "roles/cloudkms.admin",                    # Manage KMS keys (if using CMEK)
]
```

### Fine-Grained Custom Role (Alternative)

```hcl
resource "google_project_iam_custom_role" "apigee_provisioner" {
  role_id     = "apigeeProvisioner"
  title       = "Apigee Provisioner"
  description = "Custom role for provisioning Apigee infrastructure"

  permissions = [
    # Apigee
    "apigee.organizations.create",
    "apigee.organizations.get",
    "apigee.organizations.update",
    "apigee.instances.create",
    "apigee.instances.get",
    "apigee.instances.update",
    "apigee.environments.create",
    "apigee.environments.get",
    "apigee.envgroups.create",
    "apigee.envgroups.get",
    "apigee.envgroups.update",

    # Compute (VPC, NAT)
    "compute.networks.create",
    "compute.networks.get",
    "compute.networks.update",
    "compute.globalAddresses.create",
    "compute.globalAddresses.get",
    "compute.routers.create",
    "compute.routers.get",
    "compute.routers.update",

    # Service Networking
    "servicenetworking.services.addPeering",
    "servicenetworking.services.get",

    # KMS (if CMEK)
    "cloudkms.keyRings.create",
    "cloudkms.keyRings.get",
    "cloudkms.cryptoKeys.create",
    "cloudkms.cryptoKeys.get",
    "cloudkms.cryptoKeys.getIamPolicy",
    "cloudkms.cryptoKeys.setIamPolicy",
  ]
}
```

### Apigee Service Account Permissions

Apigee's service account needs KMS permissions for CMEK:

```hcl
# Retrieve Apigee service account
data "google_project_service_identity" "apigee_sa" {
  provider = google-beta
  project  = var.project_id
  service  = "apigee.googleapis.com"
}

# Grant KMS encrypter/decrypter role
resource "google_kms_crypto_key_iam_member" "apigee_sa_keyuser" {
  crypto_key_id = google_kms_crypto_key.apigee_db_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_project_service_identity.apigee_sa.email}"
}
```

---

## IP Address Planning

### IP Range Allocation Strategy

**Total IP Space Required:**

1. **Service Networking Peering Range**: `/16` (65,536 IPs)
   - Example: `10.87.0.0/16`
   - Used for: Automated VPC peering to Apigee-managed VPC

2. **Apigee Instance Runtime Range**: `/22` (1,024 IPs per instance)
   - Example: `10.87.8.0/22` (within the /16 range)
   - Used for: Apigee runtime pods and internal services

3. **Apigee Troubleshooting Range**: `/28` (16 IPs per instance)
   - Automatically allocated by Google from peering range
   - Used for: Support access to runtime instances

4. **GKE Subnet** (if in same VPC): `/20` or larger
   - Example: `10.87.128.0/20` (4,096 IPs)
   - Used for: GKE nodes and pods

5. **PSC NAT Subnet** (if using PSC): `/24` (256 IPs)
   - Example: `10.88.0.0/24`
   - Used for: PSC service attachment NAT

### Example IP Plan for PCC dev-test

```
VPC: pcc-apigee-vpc-devtest (10.87.0.0/16 + 10.88.0.0/16)

Subnet Allocations:
├── Service Networking Range:  10.87.0.0/16    (reserved for Apigee peering)
│   ├── Apigee Instance Range: 10.87.8.0/22   (1,024 IPs for runtime)
│   └── Auto-allocated /28:    10.87.12.0/28  (Google-managed)
│
├── GKE Cluster Subnet:        10.87.128.0/20  (4,096 IPs for GKE)
│   ├── Nodes:                 ~50 IPs
│   └── Pods (secondary range): 10.87.144.0/20 (4,096 pod IPs)
│
└── PSC NAT Subnet:            10.88.0.0/24    (256 IPs for PSC)

Reserved for Future:           10.88.1.0/24 - 10.88.255.0/24
```

### Avoiding IP Conflicts

**Check for conflicts with:**
1. Existing GKE cluster IP ranges
2. On-premises networks (if hybrid connectivity)
3. Other GCP VPCs (if peering planned)
4. Standard private IP blocks (avoid common ranges like `192.168.0.0/16`, `172.16.0.0/12`)

**Verification Command:**
```bash
# List all subnets in project
gcloud compute networks subnets list --project=$PROJECT_ID

# Check IP range overlap
gcloud compute networks subnets describe SUBNET_NAME \
  --region=REGION \
  --format="value(ipCidrRange)"
```

---

## Terraform Module Structure

### Recommended Module Organization

```
pcc-foundation-infra/
└── terraform/
    └── modules/
        └── apigee-networking/
            ├── README.md
            ├── versions.tf
            ├── main.tf
            ├── variables.tf
            ├── outputs.tf
            ├── vpc.tf                  # VPC and global addresses
            ├── service-networking.tf   # Service Networking connection
            ├── kms.tf                  # KMS keys for CMEK (optional)
            ├── apigee-org.tf          # Apigee organization
            ├── apigee-instance.tf     # Apigee instance
            ├── apigee-environment.tf  # Environments and groups
            ├── cloud-nat.tf           # Cloud Router + NAT
            └── iam.tf                 # IAM bindings
```

### Module Interface

**Input Variables (variables.tf):**

```hcl
variable "project_id" {
  description = "GCP project ID"
  type        = string
}

variable "environment" {
  description = "Environment name (e.g., devtest, staging, prod)"
  type        = string
}

variable "apigee_instance_region" {
  description = "GCP region for Apigee instance"
  type        = string
  default     = "us-east4"
}

variable "apigee_analytics_region" {
  description = "Region for Apigee analytics data"
  type        = string
  default     = "us-east4"
}

variable "peering_range_cidr" {
  description = "CIDR range for VPC peering (must be /16 or larger)"
  type        = string
  default     = "10.87.0.0/16"
}

variable "instance_ip_range" {
  description = "Specific /22 CIDR for Apigee instance (within peering range)"
  type        = string
  default     = "10.87.8.0/22"
}

variable "enable_cmek" {
  description = "Enable CMEK encryption for Apigee"
  type        = bool
  default     = false
}

variable "apigee_environments" {
  description = "List of Apigee environments to create"
  type = list(object({
    name         = string
    display_name = string
    description  = string
  }))
  default = [
    {
      name         = "devtest"
      display_name = "DevTest Environment"
      description  = "Development and testing environment"
    }
  ]
}

variable "environment_group_hostnames" {
  description = "List of hostnames for the environment group"
  type        = list(string)
  default     = ["api-devtest.portcon.com"]
}
```

**Outputs (outputs.tf):**

```hcl
output "apigee_organization_id" {
  description = "Apigee organization ID"
  value       = google_apigee_organization.apigee_org.id
}

output "apigee_organization_name" {
  description = "Apigee organization name"
  value       = google_apigee_organization.apigee_org.name
}

output "apigee_instance_id" {
  description = "Apigee instance ID"
  value       = google_apigee_instance.apigee_instance.id
}

output "apigee_instance_host" {
  description = "Apigee instance hostname for API calls"
  value       = google_apigee_instance.apigee_instance.host
}

output "apigee_vpc_network" {
  description = "VPC network ID for Apigee"
  value       = google_compute_network.apigee_network.id
}

output "apigee_vpc_network_name" {
  description = "VPC network name"
  value       = google_compute_network.apigee_network.name
}

output "cloud_nat_ips" {
  description = "Cloud NAT external IP addresses"
  value       = google_compute_router_nat.apigee_nat.nat_ip_allocate_option == "MANUAL_ONLY" ? google_compute_address.apigee_nat_ips[*].address : []
}

output "environment_groups" {
  description = "Apigee environment groups and their hostnames"
  value = {
    for eg in google_apigee_envgroup.api_groups : eg.name => eg.hostnames
  }
}
```

---

## Complete Terraform Examples

### Minimal VPC Peering Configuration

```hcl
# versions.tf
terraform {
  required_version = ">= 1.6"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
    google-beta = {
      source  = "hashicorp/google-beta"
      version = "~> 5.0"
    }
  }
}

provider "google" {
  project = var.project_id
  region  = var.region
}

provider "google-beta" {
  project = var.project_id
  region  = var.region
}

# main.tf
data "google_client_config" "current" {}

# 1. VPC Network
resource "google_compute_network" "apigee_network" {
  name                    = "pcc-apigee-vpc-${var.environment}"
  project                 = var.project_id
  auto_create_subnetworks = false
}

# 2. Reserve IP Range for Service Networking
resource "google_compute_global_address" "apigee_range" {
  name          = "apigee-vpc-peering-range-${var.environment}"
  project       = var.project_id
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.apigee_network.id
}

# 3. Service Networking Connection (VPC Peering)
resource "google_service_networking_connection" "apigee_vpc_connection" {
  network                 = google_compute_network.apigee_network.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.apigee_range.name]
  deletion_policy         = "ABANDON"
}

# 4. Apigee Organization
resource "google_apigee_organization" "apigee_org" {
  analytics_region   = var.apigee_analytics_region
  project_id         = var.project_id
  authorized_network = google_compute_network.apigee_network.id

  depends_on = [google_service_networking_connection.apigee_vpc_connection]
}

# 5. Apigee Instance
resource "google_apigee_instance" "apigee_instance" {
  name     = "pcc-instance-${var.environment}"
  location = var.apigee_instance_region
  org_id   = google_apigee_organization.apigee_org.id
  ip_range = "10.87.8.0/22"
}

# 6. Cloud Router
resource "google_compute_router" "apigee_router" {
  name    = "pcc-apigee-router-${var.environment}"
  project = var.project_id
  region  = var.apigee_instance_region
  network = google_compute_network.apigee_network.id

  bgp {
    asn = 64514
  }
}

# 7. Cloud NAT
resource "google_compute_router_nat" "apigee_nat" {
  name                               = "pcc-apigee-nat-${var.environment}"
  project                            = var.project_id
  router                             = google_compute_router.apigee_router.name
  region                             = var.apigee_instance_region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# 8. Apigee Environment
resource "google_apigee_environment" "devtest_env" {
  org_id       = google_apigee_organization.apigee_org.id
  name         = "devtest"
  display_name = "DevTest Environment"
}

# 9. Attach Environment to Instance
resource "google_apigee_instance_attachment" "devtest_attachment" {
  instance_id = google_apigee_instance.apigee_instance.id
  environment = google_apigee_environment.devtest_env.name
}

# 10. Environment Group
resource "google_apigee_envgroup" "api_group" {
  name      = "pcc-api-devtest"
  org_id    = google_apigee_organization.apigee_org.id
  hostnames = ["api-devtest.portcon.com"]
}

# 11. Attach Environment to Group
resource "google_apigee_envgroup_attachment" "devtest_group_attachment" {
  envgroup_id = google_apigee_envgroup.api_group.id
  environment = google_apigee_environment.devtest_env.name
}
```

### Production-Ready Configuration with CMEK

See [Complete CMEK Example in Appendix](#appendix-a-complete-cmek-configuration) for full production setup including encryption.

---

## Integration with Existing GKE Infrastructure

### Scenario: GKE Cluster in Separate VPC

**Current State:**
- GKE cluster: `pcc-gke-cluster` in VPC `pcc-gke-vpc`
- GKE subnet: `10.10.0.0/20`

**Integration Steps:**

1. **VPC Peering** (Apigee VPC ↔ GKE VPC):

```hcl
resource "google_compute_network_peering" "apigee_to_gke" {
  name         = "apigee-to-gke-${var.environment}"
  network      = google_compute_network.apigee_network.self_link
  peer_network = data.google_compute_network.gke_network.self_link

  export_custom_routes = true
  import_custom_routes = true
}

resource "google_compute_network_peering" "gke_to_apigee" {
  name         = "gke-to-apigee-${var.environment}"
  network      = data.google_compute_network.gke_network.self_link
  peer_network = google_compute_network.apigee_network.self_link

  export_custom_routes = true
  import_custom_routes = true
}
```

2. **Deploy Internal Load Balancer in GKE VPC:**

```hcl
# Backend service for GKE microservices
resource "google_compute_region_backend_service" "gke_backend" {
  name                  = "pcc-gke-backend-${var.environment}"
  region                = var.gke_region
  protocol              = "HTTP"
  load_balancing_scheme = "INTERNAL"
  health_checks         = [google_compute_region_health_check.gke_health.id]

  backend {
    group = google_compute_region_network_endpoint_group.gke_neg.id
  }
}

# Network Endpoint Group pointing to GKE services
resource "google_compute_region_network_endpoint_group" "gke_neg" {
  name                  = "pcc-gke-neg-${var.environment}"
  region                = var.gke_region
  network               = data.google_compute_network.gke_network.id
  subnetwork            = data.google_compute_subnetwork.gke_subnet.id
  network_endpoint_type = "GCE_VM_IP_PORT"
}

# Internal Load Balancer
resource "google_compute_forwarding_rule" "gke_ilb" {
  name                  = "pcc-gke-ilb-${var.environment}"
  region                = var.gke_region
  load_balancing_scheme = "INTERNAL"
  backend_service       = google_compute_region_backend_service.gke_backend.id
  network               = data.google_compute_network.gke_network.self_link
  subnetwork            = data.google_compute_subnetwork.gke_subnet.self_link
  ip_address            = "10.10.128.10"  # Static private IP
  ports                 = ["80", "443"]
}
```

3. **Configure Firewall Rules:**

```hcl
# Allow Apigee to reach GKE ILB
resource "google_compute_firewall" "apigee_to_gke" {
  name    = "allow-apigee-to-gke-${var.environment}"
  network = data.google_compute_network.gke_network.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }

  source_ranges = ["10.87.0.0/16"]  # Apigee VPC range
  target_tags   = ["gke-node"]
}
```

4. **Update Apigee API Proxy Targets:**

```xml
<!-- Target endpoint in Apigee API proxy -->
<TargetEndpoint name="gke-backend">
  <HTTPTargetConnection>
    <URL>http://10.10.128.10</URL>  <!-- GKE ILB IP -->
  </HTTPTargetConnection>
</TargetEndpoint>
```

---

## Cost Optimization

### Cost Breakdown (Approximate Monthly Costs)

| Component | Configuration | Estimated Cost |
|-----------|---------------|----------------|
| Apigee Organization | Evaluation (90-day trial) | $0 |
| Apigee Instance | 2 nodes, us-east4 | ~$700 |
| VPC Network | Standard | $0 |
| Cloud NAT | Auto-allocated IPs, 1 region | ~$50 |
| VPC Peering | Data transfer | ~$0.01/GB |
| Cloud KMS | 1 key ring, 2 keys | ~$2 |
| **Total (Evaluation)** | | **~$750/month** |

### Production Pricing (Subscription)

- Apigee Subscription: $2,000 - $10,000+/month (contract required)
- Additional regions: ~$700/region/month
- High availability (3+ nodes): +50% to instance costs

### Cost Optimization Tips

1. **Use Evaluation for Dev/Test:**
   - Free for 90 days (no SLA)
   - Switch to subscription only for production

2. **Right-Size Instances:**
   - Start with 2 nodes (minimum HA)
   - Scale up based on traffic patterns

3. **Optimize NAT:**
   - Use `AUTO_ONLY` IP allocation (cheaper)
   - Monitor NAT usage with Cloud Monitoring

4. **Consolidate Regions:**
   - Single region for dev-test
   - Multi-region only for production

5. **Monitor Data Transfer:**
   - VPC peering incurs egress charges
   - Keep Apigee and backends in same region

6. **Clean Up Unused Resources:**
   - Delete test environments promptly
   - Remove unused NAT addresses

---

## Security Considerations

### Network Security

1. **VPC Firewall Rules:**

```hcl
# Deny all ingress by default (implicit in GCP)
# Allow only necessary traffic

# Allow HTTPS from internet to Apigee load balancer
resource "google_compute_firewall" "allow_https_to_apigee" {
  name    = "allow-https-to-apigee-${var.environment}"
  network = google_compute_network.apigee_network.name

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }

  source_ranges = ["0.0.0.0/0"]
  target_tags   = ["apigee-proxy"]
}

# Deny all egress to sensitive internal ranges
resource "google_compute_firewall" "deny_egress_to_sensitive" {
  name      = "deny-egress-sensitive-${var.environment}"
  network   = google_compute_network.apigee_network.name
  direction = "EGRESS"
  priority  = 1000

  deny {
    protocol = "all"
  }

  destination_ranges = [
    "10.0.0.0/8",     # Internal network
    "172.16.0.0/12",  # Private network
  ]
}
```

2. **Private Google Access:**

Enable for Cloud Storage and API access without internet:

```hcl
resource "google_compute_subnetwork" "apigee_subnet" {
  # ... other config ...
  private_ip_google_access = true
}
```

### Data Encryption

1. **Encryption in Transit:**
   - TLS 1.2+ enforced for all API traffic
   - Mutual TLS (mTLS) for backend communication (optional)

2. **Encryption at Rest (CMEK):**

```hcl
# KMS key for Apigee database
resource "google_kms_crypto_key" "apigee_db_key" {
  name     = "apigee-db-key-${var.environment}"
  key_ring = google_kms_key_ring.apigee_keyring.id

  lifecycle {
    prevent_destroy = true
  }

  rotation_period = "7776000s"  # 90 days
}

# KMS key for Apigee disk
resource "google_kms_crypto_key" "apigee_disk_key" {
  name     = "apigee-disk-key-${var.environment}"
  key_ring = google_kms_key_ring.apigee_keyring.id

  lifecycle {
    prevent_destroy = true
  }

  rotation_period = "7776000s"
}
```

### Access Control

1. **IAM Best Practices:**
   - Use service accounts with least privilege
   - Grant roles at resource level, not project level
   - Enable audit logging for all Apigee operations

2. **Workload Identity for GKE:**

If GKE pods need to call Apigee APIs:

```hcl
# Bind GKE service account to Google Cloud SA
resource "google_service_account_iam_member" "gke_to_apigee" {
  service_account_id = google_service_account.apigee_client.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.gke_namespace}/apigee-client]"
}
```

### Monitoring and Logging

```hcl
# Enable VPC Flow Logs
resource "google_compute_subnetwork" "apigee_subnet" {
  # ... other config ...

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

# Cloud NAT logging
resource "google_compute_router_nat" "apigee_nat" {
  # ... other config ...

  log_config {
    enable = true
    filter = "ALL"  # or "ERRORS_ONLY" for cost savings
  }
}
```

---

## Troubleshooting

### Common Issues

#### Issue 1: Service Networking Connection Fails

**Symptoms:**
```
Error: Error waiting for Create Service Networking Connection:
Error code 9, message: One or more users ... do not have permission
to use ... project(s) ...
```

**Cause:** Insufficient IAM permissions for Service Networking API.

**Solution:**
```bash
# Grant service networking admin role
gcloud projects add-iam-policy-binding $PROJECT_ID \
  --member="user:YOUR_EMAIL" \
  --role="roles/servicenetworking.networksAdmin"
```

#### Issue 2: Apigee Instance Fails with IP Range Error

**Symptoms:**
```
Error: Error creating Instance: googleapi: Error 400:
IP range "10.87.8.0/22" is invalid or not within the peering range.
```

**Cause:** Instance IP range not within the Service Networking peering range.

**Solution:**
- Ensure instance `/22` range is within the `/16` peering range
- Example: If peering is `10.87.0.0/16`, instance can be `10.87.0.0/22` to `10.87.252.0/22`

#### Issue 3: Apigee Cannot Reach GKE Backend

**Symptoms:**
- API proxies return 503 errors
- Cloud Logging shows "Connection refused" or "Network unreachable"

**Diagnosis:**
```bash
# Test connectivity from Apigee
# (requires temporary SSH to an Apigee node via support)

# Check VPC peering status
gcloud compute networks peerings list --network=pcc-apigee-vpc-devtest

# Check firewall rules
gcloud compute firewall-rules list \
  --filter="network:pcc-apigee-vpc-devtest" \
  --format="table(name,sourceRanges,allowed[])"
```

**Solutions:**
1. Verify VPC peering is `ACTIVE`
2. Check firewall rules allow Apigee CIDR (`10.87.0.0/16`) to reach GKE
3. Confirm ILB IP is correct in API proxy target endpoint

#### Issue 4: Cloud NAT Not Working

**Symptoms:**
- API proxies cannot reach external APIs
- Errors: "Name or service not known"

**Solutions:**
```bash
# Check NAT configuration
gcloud compute routers nats describe pcc-apigee-nat-devtest \
  --router=pcc-apigee-router-devtest \
  --region=us-east4

# Verify NAT logs
gcloud logging read "resource.type=nat_gateway" --limit 50
```

- Ensure `source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"`
- Verify Cloud Router is in same region as Apigee instance

#### Issue 5: Terraform Apply Timeout

**Symptoms:**
```
Error: timeout while waiting for state to become 'DONE'
(last state: 'PENDING', timeout: 20m0s)
```

**Cause:** Apigee instance provisioning takes 20-30 minutes.

**Solution:**
```hcl
# Increase timeout in Terraform
resource "google_apigee_instance" "apigee_instance" {
  # ... config ...

  timeouts {
    create = "45m"
    update = "45m"
    delete = "45m"
  }
}
```

---

## References

### Official Documentation

- [Apigee X Overview](https://cloud.google.com/apigee/docs)
- [Apigee Networking Options](https://cloud.google.com/apigee/docs/api-platform/get-started/networking-options)
- [Understanding Peering Ranges](https://cloud.google.com/apigee/docs/api-platform/system-administration/peering-ranges)
- [Southbound Networking Patterns](https://cloud.google.com/apigee/docs/api-platform/architecture/southbound-networking-patterns-endpoints)
- [Apigee X Provisioning Permissions](https://cloud.google.com/apigee/docs/api-platform/get-started/permissions)

### Terraform Resources

- [google_apigee_organization](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/apigee_organization)
- [google_apigee_instance](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/apigee_instance)
- [google_apigee_environment](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/apigee_environment)
- [google_apigee_envgroup](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/apigee_envgroup)
- [google_service_networking_connection](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/service_networking_connection)
- [google_compute_router_nat](https://registry.terraform.io/providers/hashicorp/google/latest/docs/resources/compute_router_nat)

### Community Resources

- [Apigee Terraform Modules (Official)](https://github.com/apigee/terraform-modules)
- [Apigee X Network Fundamentals (Medium)](https://medium.com/google-cloud/apigee-x-network-fundamentals-70ad3c096005)
- [Private Service Connect for Apigee X (Medium)](https://medium.com/google-cloud/apigee-x-network-connectivity-using-private-service-connect-psc-ac7eaa645900)

### PCC Project References

- `@notes/phase1-gcp-preflight-checklist.md`: GCP setup prerequisites
- `@core/pcc-tf-library/.claude/docs/terraform-patterns.md`: Terraform patterns
- `@infra/pcc-app-shared-infra/CLAUDE.md`: Shared infrastructure context

---

## Appendix A: Complete CMEK Configuration

### Full Production Setup with Encryption

```hcl
# KMS Key Ring
resource "google_kms_key_ring" "apigee_keyring" {
  name     = "pcc-apigee-keyring-${var.environment}"
  location = var.apigee_instance_region
  project  = var.project_id
}

# KMS Key for Database Encryption
resource "google_kms_crypto_key" "apigee_db_key" {
  name     = "apigee-db-key-${var.environment}"
  key_ring = google_kms_key_ring.apigee_keyring.id

  lifecycle {
    prevent_destroy = true
  }

  rotation_period = "7776000s"  # 90 days

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "SOFTWARE"  # or "HSM" for compliance
  }
}

# KMS Key for Disk Encryption
resource "google_kms_crypto_key" "apigee_disk_key" {
  name     = "apigee-disk-key-${var.environment}"
  key_ring = google_kms_key_ring.apigee_keyring.id

  lifecycle {
    prevent_destroy = true
  }

  rotation_period = "7776000s"

  version_template {
    algorithm        = "GOOGLE_SYMMETRIC_ENCRYPTION"
    protection_level = "SOFTWARE"
  }
}

# Retrieve Apigee Service Account
data "google_project_service_identity" "apigee_sa" {
  provider = google-beta
  project  = var.project_id
  service  = "apigee.googleapis.com"
}

# Grant Apigee SA access to DB key
resource "google_kms_crypto_key_iam_member" "apigee_sa_db_key" {
  crypto_key_id = google_kms_crypto_key.apigee_db_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_project_service_identity.apigee_sa.email}"
}

# Grant Apigee SA access to disk key
resource "google_kms_crypto_key_iam_member" "apigee_sa_disk_key" {
  crypto_key_id = google_kms_crypto_key.apigee_disk_key.id
  role          = "roles/cloudkms.cryptoKeyEncrypterDecrypter"
  member        = "serviceAccount:${data.google_project_service_identity.apigee_sa.email}"
}

# Apigee Organization with CMEK
resource "google_apigee_organization" "apigee_org" {
  analytics_region                     = var.apigee_analytics_region
  project_id                           = var.project_id
  authorized_network                   = google_compute_network.apigee_network.id
  runtime_database_encryption_key_name = google_kms_crypto_key.apigee_db_key.id

  depends_on = [
    google_service_networking_connection.apigee_vpc_connection,
    google_kms_crypto_key_iam_member.apigee_sa_db_key,
  ]
}

# Apigee Instance with Disk Encryption
resource "google_apigee_instance" "apigee_instance" {
  name                     = "pcc-instance-${var.environment}"
  location                 = var.apigee_instance_region
  org_id                   = google_apigee_organization.apigee_org.id
  ip_range                 = var.instance_ip_range
  disk_encryption_key_name = google_kms_crypto_key.apigee_disk_key.id
}
```

---

## Appendix B: Variables File Template

```hcl
# terraform.tfvars (example for dev-test)

project_id               = "pcc-project-devtest"
environment              = "devtest"
apigee_instance_region   = "us-east4"
apigee_analytics_region  = "us-east4"

# IP addressing
peering_range_cidr = "10.87.0.0/16"
instance_ip_range  = "10.87.8.0/22"

# Encryption
enable_cmek = false  # true for production

# Environments
apigee_environments = [
  {
    name         = "devtest"
    display_name = "DevTest Environment"
    description  = "Development and testing environment"
  }
]

# Hostnames
environment_group_hostnames = [
  "api-devtest.portcon.com",
  "api-devtest.pcc.internal"
]
```

---

**END OF SPECIFICATION**

**Document Version:** 1.0
**Last Updated:** 2025-10-16
**Authors:** PCC Cloud Architecture Team
**Status:** Ready for Implementation

**Next Steps:**
1. Review with Codex team
2. Create Terraform module in `pcc-foundation-infra/terraform/modules/apigee-networking`
3. Test in dev-test environment
4. Document any adjustments in Phase 1b notes
