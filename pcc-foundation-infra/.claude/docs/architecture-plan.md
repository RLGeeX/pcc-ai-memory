# PCC GCP Foundation Infrastructure Architecture Plan

## Executive Summary

This document defines the complete infrastructure architecture for the PCC (PCConnect) Google Cloud Platform foundation. The architecture establishes a secure, scalable, and cost-optimized multi-environment setup following GCP best practices for enterprise deployments.

**Key Objectives:**
- Establish foundational GCP resource hierarchy with clean project naming
- Implement Shared VPC architecture for network isolation and centralized management
- Deploy dual-region configuration (us-east4 primary, us-central1 DR)
- Enable GKE-ready infrastructure for DevOps projects with dedicated subnet allocations
- Implement centralized logging, monitoring, and security controls
- Support future partner folder expansion without initial deployment

**Estimated Timeline:** 4-6 weeks for initial deployment
**Estimated Monthly Cost:** $2,500-$4,000 (baseline without workloads)

---

## 1. Organization Details

**Organization ID:** 146990108557
**Billing Account:** 01AFEA-2B972B-00C55F
**Domain:** pcconnect.ai
**Terraform Service Account:** pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com
**State Storage:** NEW GCS bucket (to be created): `pcc-tfstate-foundation-us-east4`

---

## 2. Folder Hierarchy

### 2.1 Folder Structure

```
pcconnect.ai (Organization)
└── pcc-fldr (Root Folder)
    ├── pcc-fldr-si (Shared Infrastructure)
    │   ├── pcc-fldr-devops
    │   ├── pcc-fldr-systems
    │   └── pcc-fldr-network
    ├── pcc-fldr-app (Application)
    └── pcc-fldr-data (Data)
```

**Folder Design Rationale:**
- **pcc-fldr-si:** Contains all shared infrastructure components (logging, networking, DevOps tooling)
- **pcc-fldr-app:** Isolates application workload projects for clear separation of concerns
- **pcc-fldr-data:** Dedicated folder for data platform services (BigQuery, Cloud SQL, etc.)
- **Partner folders (pcc-fldr-pe-#####):** NOT included in initial deployment, prepared for future expansion

### 2.2 Folder-Level Policies

Each folder will have:
- **Org Policy Constraints:** Enforce security and compliance (skip default network, require OS Login, restrict service account key creation)
- **IAM Bindings:** Role-based access control aligned with principle of least privilege
- **Budget Alerts:** Configured at folder level for cost governance

---

## 3. Project Inventory

### 3.1 Shared Infrastructure Projects (pcc-fldr-si)

#### 3.1.1 Central Logging & Monitoring
- **Project ID:** pcc-prj-logging-monitoring
- **Purpose:** Centralized log sink and monitoring workspace for entire organization
- **Services:**
  - Cloud Logging (org-level log sink)
  - Cloud Monitoring (workspace)
  - BigQuery (log analytics dataset)
  - Pub/Sub (log streaming)
- **Location:** us-east4
- **Parent Folder:** pcc-fldr-si (direct child)

#### 3.1.2 Network Projects (pcc-fldr-network)

**Production Network Host Project:**
- **Project ID:** pcc-prj-network-prod
- **Purpose:** Shared VPC host for production environment
- **Services:** Compute Engine API, VPC, Cloud DNS, Cloud NAT, Cloud Router
- **VPC:** pcc-vpc-prod-shared
- **Shared VPC Enabled:** Yes

**Non-Production Network Host Project:**
- **Project ID:** pcc-prj-network-nonprod
- **Purpose:** Shared VPC host for non-production environments
- **Services:** Compute Engine API, VPC, Cloud DNS, Cloud NAT, Cloud Router
- **VPC:** pcc-vpc-nonprod-shared
- **Shared VPC Enabled:** Yes

#### 3.1.3 DevOps Projects (pcc-fldr-devops)

**Production DevOps:**
- **Project ID:** pcc-prj-devops-prod
- **Purpose:** CI/CD tooling, Artifact Registry, GKE cluster for production deployments
- **Services:**
  - Cloud Build
  - Artifact Registry
  - Google Kubernetes Engine (GKE)
  - Secret Manager
  - Cloud Source Repositories
- **Shared VPC Attachment:** pcc-prj-network-prod
- **GKE Subnet Allocation:** Yes (dedicated subnets in us-east4)

**Non-Production DevOps:**
- **Project ID:** pcc-prj-devops-nonprod
- **Purpose:** CI/CD tooling, Artifact Registry, GKE cluster for dev/test deployments
- **Services:**
  - Cloud Build
  - Artifact Registry
  - Google Kubernetes Engine (GKE)
  - Secret Manager
  - Cloud Source Repositories
- **Shared VPC Attachment:** pcc-prj-network-nonprod
- **GKE Subnet Allocation:** Yes (dedicated subnets in us-east4)

#### 3.1.4 Systems Projects (pcc-fldr-systems)

**Production Systems:**
- **Project ID:** pcc-prj-sys-prod
- **Purpose:** Shared infrastructure services (DNS, secrets, identity)
- **Services:**
  - Cloud DNS (production zones)
  - Secret Manager (production secrets)
  - Certificate Manager
  - Identity Platform
- **Shared VPC Attachment:** pcc-prj-network-prod

**Non-Production Systems:**
- **Project ID:** pcc-prj-sys-nonprod
- **Purpose:** Shared infrastructure services for dev/test
- **Services:**
  - Cloud DNS (non-prod zones)
  - Secret Manager (dev/test secrets)
  - Certificate Manager
  - Identity Platform
- **Shared VPC Attachment:** pcc-prj-network-nonprod

### 3.2 Application Projects (pcc-fldr-app)

**DevTest Environment:**
- **Project ID:** pcc-prj-app-devtest
- **Purpose:** Development and testing environment for application workloads
- **Shared VPC Attachment:** pcc-prj-network-nonprod
- **Primary Region:** us-east4

**Development Environment:**
- **Project ID:** pcc-prj-app-dev
- **Purpose:** Stable development environment
- **Shared VPC Attachment:** pcc-prj-network-nonprod
- **Primary Region:** us-east4

**Staging Environment:**
- **Project ID:** pcc-prj-app-staging
- **Purpose:** Pre-production staging environment
- **Shared VPC Attachment:** pcc-prj-network-nonprod
- **Primary Region:** us-east4

**Production Environment:**
- **Project ID:** pcc-prj-app-prod
- **Purpose:** Production application workloads
- **Shared VPC Attachment:** pcc-prj-network-prod
- **Primary Region:** us-east4
- **DR Region:** us-central1

### 3.3 Data Projects (pcc-fldr-data)

**DevTest Data Platform:**
- **Project ID:** pcc-prj-data-devtest
- **Purpose:** Data platform for development/testing
- **Services:** BigQuery, Cloud SQL, Cloud Storage, Dataflow
- **Shared VPC Attachment:** pcc-prj-network-nonprod

**Development Data Platform:**
- **Project ID:** pcc-prj-data-dev
- **Purpose:** Stable development data environment
- **Services:** BigQuery, Cloud SQL, Cloud Storage, Dataflow
- **Shared VPC Attachment:** pcc-prj-network-nonprod

**Staging Data Platform:**
- **Project ID:** pcc-prj-data-staging
- **Purpose:** Pre-production data platform
- **Services:** BigQuery, Cloud SQL, Cloud Storage, Dataflow
- **Shared VPC Attachment:** pcc-prj-network-nonprod

**Production Data Platform:**
- **Project ID:** pcc-prj-data-prod
- **Purpose:** Production data platform with HA/DR
- **Services:** BigQuery, Cloud SQL (regional HA), Cloud Storage, Dataflow
- **Shared VPC Attachment:** pcc-prj-network-prod
- **Data Replication:** us-east4 → us-central1

---

## 4. Network Architecture

### 4.1 Production VPC (pcc-vpc-prod-shared)

**VPC Details:**
- **Host Project:** pcc-prj-network-prod
- **VPC Name:** pcc-vpc-prod-shared
- **Routing Mode:** Regional
- **DNS Policy:** Private Google Access enabled

#### 4.1.1 Production Subnets (us-east4 - Primary)

**Primary Workload Subnets:**
- **pcc-sub-prod-us-e4-primary:** 10.16.0.0/18 (16,382 hosts)
  - Purpose: General production workloads
  - Private Google Access: Enabled
  - Flow Logs: Enabled (sampling 0.5, interval 10min)

- **pcc-sub-prod-us-e4-gke-reserved:** 10.16.64.0/18 (16,382 hosts)
  - Purpose: Reserved for future GKE workloads
  - Private Google Access: Enabled
  - Flow Logs: Enabled

**DevOps GKE Subnets (us-east4):**
- **pcc-sub-devops-prod-us-e4-main:** 10.16.128.0/20 (4,094 hosts)
  - Purpose: GKE node subnet for pcc-prj-devops-prod
  - Secondary Ranges:
    - **pcc-sub-devops-prod-us-e4-pods:** 10.16.144.0/20 (4,094 IPs for pods)
    - **pcc-sub-devops-prod-us-e4-svc:** 10.16.160.0/20 (4,094 IPs for services)
  - Private Google Access: Enabled
  - Flow Logs: Enabled

- **pcc-sub-devops-prod-us-e4-overflow:** 10.16.176.0/20 (4,094 hosts)
  - Purpose: Overflow capacity for GKE expansion
  - Private Google Access: Enabled

**Reserved Blocks:**
- 10.16.192.0/18: Reserved for future production expansion (us-east4)
- 10.17.0.0/16: Reserved for future production services (us-east4)
- 10.18.0.0/15: Reserved for additional environments (us-east4)

#### 4.1.2 Production Subnets (us-central1 - DR)

**DR Workload Subnets:**
- **pcc-sub-prod-us-c1-primary:** 10.32.0.0/18 (16,382 hosts)
  - Purpose: DR for production workloads
  - Private Google Access: Enabled
  - Flow Logs: Enabled

**Reserved Blocks:**
- 10.32.64.0/18: Reserved for future DR capacity
- 10.33.0.0/16: Reserved for DR services
- 10.34.0.0/15: Reserved for DR expansion

#### 4.1.3 Production Network Services

**Cloud Routers:**
- **pcc-rtr-prod-us-e4:** us-east4, ASN 64560
  - Purpose: Enable Cloud NAT for private Google access
  - Advertise Custom Routes: Disabled

- **pcc-rtr-prod-us-c1:** us-central1, ASN 64570
  - Purpose: Enable Cloud NAT for DR region

**Cloud NAT Gateways:**
- **pcc-nat-prod-us-e4:** Attached to pcc-rtr-prod-us-e4
  - Auto-allocated IPs: 2 (baseline)
  - Min Ports per VM: 64
  - Logging: Enabled (errors and translations)

- **pcc-nat-prod-us-c1:** Attached to pcc-rtr-prod-us-c1
  - Auto-allocated IPs: 2 (baseline)

**Firewall Rules:**
- **pcc-fw-prod-allow-internal:** Allow all traffic within 10.16.0.0/13 and 10.32.0.0/13
- **pcc-fw-prod-allow-iap:** Allow IAP SSH/RDP (35.235.240.0/20)
- **pcc-fw-prod-allow-health-checks:** Allow Google health checks (35.191.0.0/16, 130.211.0.0/22)
- **pcc-fw-prod-deny-all-egress:** Explicit deny for unneeded egress (logging enabled)
- **pcc-fw-prod-allow-google-apis:** Allow private.googleapis.com (restricted.googleapis.com)

**Cloud Armor (Future):**
- Load Balancer integration for DDoS protection and WAF policies

### 4.2 Non-Production VPC (pcc-vpc-nonprod-shared)

**VPC Details:**
- **Host Project:** pcc-prj-network-nonprod
- **VPC Name:** pcc-vpc-nonprod-shared
- **Routing Mode:** Regional
- **DNS Policy:** Private Google Access enabled

#### 4.2.1 Non-Production Subnets (us-east4)

**Primary Workload Subnets:**
- **pcc-sub-nonprod-us-e4-primary:** 10.24.0.0/18 (16,382 hosts)
  - Purpose: Dev/test workloads
  - Private Google Access: Enabled
  - Flow Logs: Enabled (sampling 0.5)

- **pcc-sub-nonprod-us-e4-gke-reserved:** 10.24.64.0/18 (16,382 hosts)
  - Purpose: Reserved for future GKE workloads

**DevOps GKE Subnets (us-east4):**
- **pcc-sub-devops-nonprod-us-e4-main:** 10.24.128.0/20 (4,094 hosts)
  - Purpose: GKE node subnet for pcc-prj-devops-nonprod
  - Secondary Ranges:
    - **pcc-sub-devops-nonprod-us-e4-pods:** 10.24.144.0/20
    - **pcc-sub-devops-nonprod-us-e4-svc:** 10.24.160.0/20
  - Private Google Access: Enabled
  - Flow Logs: Enabled

- **pcc-sub-devops-nonprod-us-e4-overflow:** 10.24.176.0/20
  - Purpose: Overflow capacity for GKE expansion

**Reserved Blocks:**
- 10.24.192.0/18: Reserved for non-prod expansion
- 10.25.0.0/16 - 10.31.0.0/16: Reserved for additional non-prod environments

#### 4.2.2 Non-Production Subnets (us-central1)

**DevTest Subnets:**
- **pcc-sub-nonprod-us-c1-primary:** 10.40.0.0/18
  - Purpose: DevTest workloads in us-central1
  - Private Google Access: Enabled
  - Flow Logs: Enabled

**Reserved Blocks:**
- 10.40.64.0/18 - 10.47.0.0/16: Reserved for non-prod expansion

#### 4.2.3 Non-Production Network Services

**Cloud Routers:**
- **pcc-rtr-nonprod-us-e4:** us-east4, ASN 64520
- **pcc-rtr-nonprod-us-c1:** us-central1, ASN 64530

**Cloud NAT Gateways:**
- **pcc-nat-nonprod-us-e4:** Attached to pcc-rtr-nonprod-us-e4
  - Auto-allocated IPs: 2
  - Min Ports per VM: 64

- **pcc-nat-nonprod-us-c1:** Attached to pcc-rtr-nonprod-us-c1
  - Auto-allocated IPs: 2

**Firewall Rules:**
- **pcc-fw-nonprod-allow-internal:** Allow all within 10.24.0.0/13 and 10.40.0.0/13
- **pcc-fw-nonprod-allow-iap:** Allow IAP access
- **pcc-fw-nonprod-allow-health-checks:** Allow health checks
- **pcc-fw-nonprod-allow-google-apis:** Private Google Access

### 4.3 Network Architecture Diagram (ASCII)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                          Internet / Cloud Users                          │
└────────────────────────────────┬────────────────────────────────────────┘
                                 │
                    ┌────────────┴────────────┐
                    │   Cloud Armor (Future)  │
                    │   DDoS + WAF Protection │
                    └────────────┬────────────┘
                                 │
        ┌────────────────────────┴────────────────────────┐
        │                                                  │
┌───────▼──────────────────────┐        ┌────────────────▼──────────────────┐
│  Production VPC (10.16/13)   │        │  Non-Prod VPC (10.24/13)          │
│  pcc-prj-network-prod        │        │  pcc-prj-network-nonprod          │
└──────────────────────────────┘        └───────────────────────────────────┘
        │                                        │
   ┌────┴─────────────┐                    ┌────┴─────────────┐
   │                  │                    │                  │
┌──▼──────────────┐ ┌─▼───────────────┐ ┌─▼──────────────┐ ┌─▼────────────────┐
│  us-east4       │ │  us-central1    │ │  us-east4      │ │  us-central1     │
│  (Primary)      │ │  (DR)           │ │  (Primary)     │ │  (DevTest)       │
├─────────────────┤ ├─────────────────┤ ├────────────────┤ ├──────────────────┤
│ Cloud Router    │ │ Cloud Router    │ │ Cloud Router   │ │ Cloud Router     │
│ ASN 64560       │ │ ASN 64570       │ │ ASN 64520      │ │ ASN 64530        │
│   + NAT Gateway │ │   + NAT Gateway │ │   + NAT Gateway│ │   + NAT Gateway  │
├─────────────────┤ ├─────────────────┤ ├────────────────┤ ├──────────────────┤
│ Primary Subnet  │ │ DR Subnet       │ │ Primary Subnet │ │ DevTest Subnet   │
│ 10.16.0.0/18    │ │ 10.32.0.0/18    │ │ 10.24.0.0/18   │ │ 10.40.0.0/18     │
├─────────────────┤ └─────────────────┘ ├────────────────┤ └──────────────────┘
│ GKE DevOps      │                     │ GKE DevOps     │
│ Main: .128/20   │                     │ Main: .128/20  │
│ Pods: .144/20   │                     │ Pods: .144/20  │
│ Svcs: .160/20   │                     │ Svcs: .160/20  │
│ Over: .176/20   │                     │ Over: .176/20  │
└─────────────────┘                     └────────────────┘
         │                                       │
    ┌────┴────┐                            ┌────┴────┐
    │ Service │                            │ Service │
    │ Projects│                            │ Projects│
    └─────────┘                            └─────────┘
 - devops-prod                          - devops-nonprod
 - app-prod                             - app-devtest/dev/staging
 - data-prod                            - data-devtest/dev/staging
 - sys-prod                             - sys-nonprod
```

---

## 5. GKE Subnet Allocation Details

### 5.1 Production DevOps GKE (pcc-prj-devops-prod)

**Cluster Configuration:**
- **Cluster Name:** pcc-gke-devops-prod-us-e4
- **Region:** us-east4
- **Type:** Regional (3 zones)
- **Network:** pcc-vpc-prod-shared
- **Node Subnet:** pcc-sub-devops-prod-us-e4-main (10.16.128.0/20)

**IP Allocation:**
- **Nodes:** 10.16.128.0/20 (4,094 available IPs)
  - Maximum Nodes: ~3,800 (with IP reservation overhead)
  - Recommended: 100-500 nodes

- **Pods:** 10.16.144.0/20 (4,094 IPs via secondary range)
  - Maximum Pods: 4,094
  - With /24 per node (256 pods/node): ~16 nodes max
  - **Recommendation:** Use /27 per node (32 pods/node) for 128 nodes

- **Services:** 10.16.160.0/20 (4,094 IPs via secondary range)
  - Maximum Kubernetes Services: 4,094
  - Typical usage: 100-500 services

- **Overflow:** 10.16.176.0/20 (4,094 IPs)
  - Purpose: Additional node capacity or future cluster

**GKE Cluster Best Practices:**
- Enable Workload Identity for GCP service authentication
- Use VPC-native clusters (alias IPs)
- Enable Binary Authorization for image security
- Configure pod security policies (PSP) or Pod Security Standards (PSS)
- Enable GKE Dataplane V2 for network policy enforcement

### 5.2 Non-Production DevOps GKE (pcc-prj-devops-nonprod)

**Cluster Configuration:**
- **Cluster Name:** pcc-gke-devops-nonprod-us-e4
- **Region:** us-east4
- **Type:** Regional (3 zones)
- **Network:** pcc-vpc-nonprod-shared
- **Node Subnet:** pcc-sub-devops-nonprod-us-e4-main (10.24.128.0/20)

**IP Allocation:**
- **Nodes:** 10.24.128.0/20 (4,094 IPs)
- **Pods:** 10.24.144.0/20 (4,094 IPs)
- **Services:** 10.24.160.0/20 (4,094 IPs)
- **Overflow:** 10.24.176.0/20 (4,094 IPs)

**Configuration:** Same best practices as production

### 5.3 NO GKE Subnets for Other Projects

**Important:** ONLY the DevOps projects (pcc-prj-devops-prod and pcc-prj-devops-nonprod) receive dedicated GKE subnet allocations. All other projects (app, data, systems) use standard compute subnets.

---

## 6. Security Architecture

### 6.1 IAM Strategy

**Organization-Level Roles:**
- **Organization Admins:** Super admins only (break-glass accounts)
- **Billing Admins:** Finance team (billing account management)
- **Security Admins:** Security team (Security Command Center, org policies)

**Folder-Level Roles:**
- **pcc-fldr-si:**
  - Network Admins: `group:gcp-network-admins@pcconnect.ai`
  - DevOps Admins: `group:gcp-devops-admins@pcconnect.ai`

- **pcc-fldr-app:**
  - App Developers (Non-Prod): `group:gcp-developers@pcconnect.ai`
    - Roles: `roles/compute.instanceAdmin.v1`, `roles/container.admin`
  - App Operators (Prod): `group:gcp-app-operators@pcconnect.ai`
    - Roles: `roles/viewer`, `roles/logging.viewer`

- **pcc-fldr-data:**
  - Data Engineers: `group:gcp-data-engineers@pcconnect.ai`
    - Roles: `roles/bigquery.dataEditor`, `roles/storage.admin`
  - Data Analysts: `group:gcp-data-analysts@pcconnect.ai`
    - Roles: `roles/bigquery.dataViewer`

**Project-Level Roles:**
- **pcc-prj-logging-monitoring:**
  - Viewers: `group:gcp-logging-monitoring-viewers@pcconnect.ai`
  - Security Auditors: `group:gcp-security-admins@pcconnect.ai`

**Service Accounts:**
- **Terraform SA:** pcc-sa-terraform@pcc-prj-bootstrap.iam.gserviceaccount.com
  - Roles: `roles/resourcemanager.folderAdmin`, `roles/compute.xpnAdmin`, `roles/billing.user`
  - Key Management: Workload Identity Federation (no keys)

- **GKE Node SA:** Custom SAs per cluster with minimal permissions
- **Cloud Build SA:** Custom SA with Artifact Registry push, GKE deploy

### 6.2 Organization Policies

**Enforce across organization:**
- `compute.skipDefaultNetworkCreation`: TRUE (no default networks)
- `compute.requireOsLogin`: TRUE (require OS Login for SSH)
- `iam.disableServiceAccountKeyCreation`: TRUE (enforce Workload Identity)
- `compute.vmExternalIpAccess`: DENY (except for NAT gateways)
- `storage.uniformBucketLevelAccess`: TRUE (enforce uniform access)
- `compute.restrictSharedVpcSubnetworks`: Enforce service project subnet restrictions

**Custom Policies:**
- Restrict public IP allocation to specific projects (NAT gateway projects only)
- Enforce encryption with CMEK for production data projects
- Restrict VM machine types to cost-effective families

### 6.3 Security Services

**Security Command Center:**
- Enable Premium tier for production folders
- Enable Standard tier for non-production
- Configure findings for: open firewall rules, public IPs, unencrypted resources

**VPC Service Controls (Future - Phase 2):**
- Create service perimeter around production data projects
- Restrict data exfiltration via VPC-SC

**Cloud Armor:**
- Deploy with external Load Balancers (Phase 2)
- Implement rate limiting, geo-blocking, OWASP Top 10 rules

**Binary Authorization:**
- Enforce in GKE clusters (production required, non-prod audit mode)
- Attestation with Cloud Build

### 6.4 Encryption

**Data at Rest:**
- Google-managed keys (default) for non-production
- Customer-managed encryption keys (CMEK) for production data projects (Cloud KMS)

**Data in Transit:**
- TLS 1.2+ for all external connections
- mTLS with Istio/Anthos Service Mesh within GKE (future)

---

## 7. Logging and Monitoring

### 7.1 Centralized Logging

**Log Sinks:**
- **Organization-Level Sink:**
  - Destination: BigQuery dataset in pcc-prj-logging-monitoring
  - Filter: All logs (Admin Activity, Data Access, System Event)
  - Retention: 365 days (BQ storage)

- **Audit Logs:**
  - Admin Activity Logs: Always on (free)
  - Data Access Logs: Enabled for production projects
  - System Event Logs: Enabled

**Log Router Configuration:**
- Exclude low-value logs (e.g., load balancer health checks) via exclusion filters
- Route security logs to separate BigQuery table for SIEM integration

### 7.2 Cloud Monitoring

**Workspace:**
- **Host Project:** pcc-prj-logging-monitoring
- **Monitored Projects:** All projects in organization
- **Metrics Scope:** Organization-wide

**Dashboards:**
- Infrastructure Health: Compute, GKE, VPC metrics
- Security: Firewall hits, IAM changes, org policy violations
- Cost: Billing dashboard with budget alerts

**Alerting:**
- Critical: Firewall rule changes, IAM changes in production
- Warning: High error rates, quota exhaustion
- Info: Budget thresholds (50%, 80%, 100%)

**Uptime Checks:**
- External HTTPS endpoints (production apps)
- Internal service health (via Cloud Monitoring API)

### 7.3 Audit and Compliance

**Compliance Frameworks:**
- **CIS GCP Foundation Benchmark:** Align org policies with CIS Level 1
- **SOC 2 / ISO 27001:** Centralized logging for audit trails

**Access Transparency:**
- Enable for production folders (visibility into Google support access)

---

## 8. Cost Optimization and FinOps

### 8.1 Cost Breakdown (Estimated Monthly)

**Network Costs:**
- VPC (free, except egress)
- Cloud NAT: ~$45/NAT gateway × 4 = $180
- Cloud Router: ~$18/router × 4 = $72
- **Subtotal:** $252/month

**Logging and Monitoring:**
- Log ingestion: ~$0.50/GB × 100GB = $50
- BigQuery storage: ~$0.02/GB × 500GB = $10
- Monitoring: ~$2.50/metric × 50 metrics = $125
- **Subtotal:** $185/month

**Compute (Baseline - no workloads):**
- GKE control plane: $73/cluster × 2 = $146
- Minimal node pool (1 e2-medium/cluster): ~$25 × 2 = $50
- **Subtotal:** $196/month

**Operations:**
- Cloud Build: ~$0 (free tier sufficient for setup)
- Secret Manager: ~$10
- **Subtotal:** $10/month

**Total Baseline:** ~$643/month (no application workloads)

**With Initial Workloads (+GKE nodes, VMs):** $2,500-$4,000/month

### 8.2 Cost Optimization Strategies

**Committed Use Discounts (CUDs):**
- Once workloads stabilize, purchase 1-year CUDs for GKE node pools (up to 40% savings)
- 3-year CUDs for predictable production workloads (up to 55% savings)

**Sustained Use Discounts:**
- Automatic for VMs running >25% of the month (up to 30% savings)

**Rightsizing:**
- Enable recommender API for VM and GKE node rightsizing
- Set up automated alerting on underutilized resources

**Idle Resource Cleanup:**
- Tag resources with environment labels (dev/test/prod)
- Automate shutdown of dev/test resources outside business hours (Cloud Scheduler + Cloud Functions)

**Network Egress Optimization:**
- Keep traffic within regions (free)
- Use Cloud CDN for static content (reduce origin egress)
- Minimize cross-region traffic

**Storage Lifecycle Management:**
- Auto-transition GCS objects to Nearline (30 days) and Coldline (90 days)
- Delete old log exports after compliance retention (365 days)

### 8.3 Budget and Alerts

**Budget Configuration:**
- **Folder-Level Budgets:**
  - pcc-fldr-si: $5,000/month
  - pcc-fldr-app: $10,000/month
  - pcc-fldr-data: $8,000/month

- **Alerts:** 50%, 80%, 100% thresholds
- **Actions:** Email to finance team, Pub/Sub topic for automation

**FinOps Practices:**
- Monthly cost review meeting with stakeholders
- Chargeback model: Tag projects with cost center for allocation
- Cost anomaly detection with Cloud Billing API

---

## 9. Disaster Recovery and High Availability

### 9.1 RTO and RPO Targets

**Production Services:**
- **RTO (Recovery Time Objective):** 4 hours
- **RPO (Recovery Point Objective):** 15 minutes
- **Strategy:** Multi-region deployment with automated failover

**Non-Production Services:**
- **RTO:** 24 hours
- **RPO:** 24 hours
- **Strategy:** Best-effort recovery from backups

### 9.2 DR Architecture

**Regional Failover:**
- **Primary:** us-east4
- **Secondary:** us-central1
- **Failover Mechanism:** Cloud DNS with health checks for automated failover

**Data Replication:**
- **Cloud SQL:** HA configuration with read replicas in us-central1
- **GCS Buckets:** Multi-region or dual-region buckets (us-east4 + us-central1)
- **BigQuery:** Scheduled BigQuery Data Transfer Service to replicate datasets

**GKE Multi-Region:**
- Separate clusters in us-east4 and us-central1
- Application deployment via Anthos Config Management or GitOps (Flux/Argo)
- Traffic management via global load balancer

### 9.3 Backup Strategy

**GCE VMs:**
- Persistent disk snapshots: Daily for production, weekly for non-prod
- Retention: 30 days production, 7 days non-prod
- Automated via snapshot schedules

**GKE:**
- Backup for GKE: Daily backups of PVCs and cluster state
- Retention: 30 days

**Cloud SQL:**
- Automated backups: Daily with 7-day retention
- Point-in-time recovery enabled for production

### 9.4 Disaster Recovery Runbook

**Scenario: us-east4 Region Outage**

1. **Detection (0-15 min):**
   - Cloud Monitoring alerts on endpoint failures
   - Validate region-wide outage via GCP Status Dashboard

2. **Decision (15-30 min):**
   - Incident commander declares DR activation
   - Notify stakeholders via Slack/PagerDuty

3. **Failover Execution (30-60 min):**
   - Update Cloud DNS to point to us-central1 endpoints
   - Scale up GKE cluster in us-central1 (increase node count)
   - Promote Cloud SQL read replica to primary (if applicable)

4. **Validation (60-90 min):**
   - Run smoke tests on us-central1 endpoints
   - Validate data integrity (compare checksums/row counts)

5. **Communication (90-120 min):**
   - Notify customers of service restoration
   - Post-mortem planning

6. **Failback (after region recovery):**
   - Replicate data changes back to us-east4
   - Gradually shift traffic back via weighted Cloud DNS
   - Full cutover after validation

**Estimated RTO:** 2-4 hours (within target)

---

## 10. Terraform Implementation Plan

### 10.1 State Management

**Backend Configuration:**
- **Bucket:** pcc-tfstate-foundation-us-east4 (NEW bucket to create)
- **Location:** us-east4
- **Versioning:** Enabled
- **Encryption:** Google-managed
- **Lifecycle:** Prevent destroy
- **Access:** Restricted to Terraform SA only

**State Structure:**
```
terraform/
├── backend.tf            # GCS backend config
├── versions.tf           # Provider versions
├── variables.tf          # Global variables
├── outputs.tf            # Root outputs
├── main.tf               # Root module orchestration
├── modules/
│   ├── folders/          # Folder creation module
│   ├── projects/         # Project factory module
│   ├── network/          # VPC and subnet module
│   ├── network-services/ # NAT, routers, firewall module
│   ├── iam/              # IAM bindings module
│   ├── logging/          # Log sinks module
│   └── org-policy/       # Org policy module
└── environments/
    ├── bootstrap/        # Initial state bucket creation
    └── foundation/       # Main foundation deployment
```

### 10.2 Module Organization

**Module: folders**
- Creates folder hierarchy (pcc-fldr, pcc-fldr-si, subfolders)
- Outputs folder IDs for project creation

**Module: projects**
- Reusable project factory
- Inputs: project name, folder, APIs to enable, Shared VPC attachment
- Outputs: project ID, project number

**Module: network**
- Creates VPCs and subnets
- Configures Shared VPC host projects
- Outputs: VPC self-links, subnet self-links

**Module: network-services**
- Cloud Routers and NAT gateways
- Firewall rules
- Outputs: NAT gateway IPs

**Module: iam**
- Folder and project IAM bindings
- Group-based role assignments

**Module: logging**
- Organization-level log sink
- BigQuery dataset for logs
- Log exclusion filters

**Module: org-policy**
- Org policy constraints at org/folder level
- Boolean and list constraints

### 10.3 Deployment Phases

**Phase 0: Bootstrap (Pre-requisites)**
- Verify Terraform SA permissions
- Create state bucket: pcc-tfstate-foundation-us-east4
- Verify billing account and org ID
- **Manual step:** Create state bucket via gcloud CLI

**Phase 1: Folder and Project Creation (Week 1)**
- Deploy folder hierarchy
- Create all projects (network, logging, devops, systems, app, data)
- Enable required APIs
- Apply org policies
- **Validation:** Verify folder structure, project creation

**Phase 2: Network Foundation (Week 2)**
- Create VPCs (prod and nonprod)
- Create subnets (primary workload subnets only, no GKE subnets yet)
- Configure Shared VPC attachments for service projects
- Deploy Cloud Routers and NAT gateways
- **Validation:** Test connectivity, verify Shared VPC associations

**Phase 3: GKE Subnet Allocation (Week 3)**
- Add GKE-specific subnets for devops projects
- Configure secondary IP ranges for pods and services
- Update firewall rules for GKE
- **Validation:** Dry-run GKE cluster creation (do not deploy yet)

**Phase 4: Security and IAM (Week 3-4)**
- Apply IAM bindings at folder and project level
- Configure Service Account impersonation
- Enable Security Command Center
- **Validation:** Test IAM permissions with test users

**Phase 5: Logging and Monitoring (Week 4)**
- Create org-level log sink
- Deploy BigQuery dataset for logs
- Configure Cloud Monitoring workspace
- Set up budget alerts
- **Validation:** Generate test logs, verify log routing

**Phase 6: Validation and Documentation (Week 5-6)**
- End-to-end testing of network, IAM, logging
- Create operational runbooks
- Conduct DR drill (simulate failover)
- Hand-off to operations team

### 10.4 Migration from Existing State

**Note:** The requirement states "Use NEW bucket for state (not existing one), plan for state migration after initial deployment."

**Current State:** Reference Terraform likely uses `cs-tfstate-us-east4-7351f954f21d4c0c9476017588a0fb91`

**Migration Plan (Post-Deployment):**
1. Deploy foundation with new state bucket: `pcc-tfstate-foundation-us-east4`
2. Once validated, export existing state: `terraform state pull > old-state.json`
3. Import resources into new state (if needed): `terraform import <resource> <id>`
4. Decommission old state bucket after validation period (30 days)

---

## 11. GKE Implementation Details

### 11.1 GKE Cluster Configuration

**Production Cluster (pcc-gke-devops-prod-us-e4):**
- **Type:** Regional (multi-zonal)
- **Zones:** us-east4-a, us-east4-b, us-east4-c
- **Release Channel:** Regular (balance stability and features)
- **Network:** pcc-vpc-prod-shared
- **Subnet:** pcc-sub-devops-prod-us-e4-main
- **Secondary Ranges:** pods (10.16.144.0/20), services (10.16.160.0/20)

**Node Pool Configuration:**
- **Default Pool:**
  - Machine Type: e2-standard-4 (4 vCPU, 16GB RAM)
  - Min Nodes: 3 (1 per zone)
  - Max Nodes: 15 (5 per zone)
  - Autoscaling: Enabled
  - Auto-repair: Enabled
  - Auto-upgrade: Enabled (during maintenance window)

**Workload Identity:**
- Enabled at cluster level
- Each application uses dedicated Kubernetes Service Account (KSA) mapped to Google Service Account (GSA)

**Binary Authorization:**
- Enabled (enforce mode in production)
- Attestation required for Cloud Build images

**Network Policy:**
- Dataplane V2 (eBPF-based) for network policies
- Default-deny egress policy (allow explicit egress only)

**Monitoring and Logging:**
- GKE System logs: Enabled
- GKE Workload logs: Enabled
- Metrics: Enabled (Cloud Monitoring integration)

### 11.2 Non-Production Cluster (pcc-gke-devops-nonprod-us-e4)

**Configuration:** Similar to production with the following differences:
- **Release Channel:** Rapid (for early feature testing)
- **Node Pool:**
  - Machine Type: e2-standard-2 (2 vCPU, 8GB RAM)
  - Min Nodes: 1 (1 per zone)
  - Max Nodes: 9 (3 per zone)
- **Binary Authorization:** Audit mode (log violations, don't block)

---

## 12. Service Activation Matrix

| Service | Logging | Network Prod | Network NonProd | DevOps Prod | DevOps NonProd | Systems Prod | Systems NonProd | App Projects | Data Projects |
|---------|---------|--------------|-----------------|-------------|----------------|--------------|-----------------|--------------|---------------|
| compute.googleapis.com | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| logging.googleapis.com | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| monitoring.googleapis.com | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ | ✓ |
| container.googleapis.com | - | - | - | ✓ | ✓ | - | - | - | - |
| artifactregistry.googleapis.com | - | - | - | ✓ | ✓ | - | - | - | - |
| cloudbuild.googleapis.com | - | - | - | ✓ | ✓ | - | - | - | - |
| secretmanager.googleapis.com | - | - | - | ✓ | ✓ | ✓ | ✓ | - | - |
| dns.googleapis.com | - | ✓ | ✓ | - | - | ✓ | ✓ | - | - |
| bigquery.googleapis.com | ✓ | - | - | - | - | - | - | - | ✓ |
| storage.googleapis.com | ✓ | - | - | ✓ | ✓ | - | - | ✓ | ✓ |
| sql-component.googleapis.com | - | - | - | - | - | - | - | - | ✓ |
| dataflow.googleapis.com | - | - | - | - | - | - | - | - | ✓ |

---

## 13. Project Naming Conventions

**Standard:** `pcc-prj-<category>-<environment>`

- **pcc:** Organization prefix (PCConnect)
- **prj:** Indicates GCP project
- **category:** logging-monitoring, network, devops, sys (systems), app, data
- **environment:** prod, nonprod, devtest, dev, staging

**Examples:**
- pcc-prj-logging-monitoring
- pcc-prj-network-prod
- pcc-prj-devops-nonprod
- pcc-prj-app-prod
- pcc-prj-data-staging

**NO random IDs:** Clean, deterministic names as specified in requirements.

---

## 14. Security Posture Recommendations

### 14.1 Immediate Actions (Phase 1)

1. **Enable Organization Policies:**
   - Enforce `compute.skipDefaultNetworkCreation`
   - Enforce `compute.requireOsLogin`
   - Restrict external IPs

2. **Configure IAM:**
   - Remove primitive roles (Owner, Editor, Viewer) from users
   - Use predefined or custom roles only
   - Enforce group-based access

3. **Enable Audit Logging:**
   - Admin Activity Logs (always on)
   - Data Access Logs for production projects

4. **Deploy Centralized Logging:**
   - Organization-level log sink to BigQuery
   - 365-day retention for compliance

### 14.2 Short-Term Actions (Phase 2 - 3 months)

1. **Security Command Center:**
   - Enable Premium tier for production
   - Configure automated remediation for critical findings

2. **Cloud Armor:**
   - Deploy with external load balancers
   - Implement OWASP Top 10 rules

3. **Workload Identity:**
   - Migrate all workloads to Workload Identity (no service account keys)

4. **VPC Service Controls:**
   - Create perimeter around production data projects
   - Restrict data exfiltration

### 14.3 Long-Term Actions (Phase 3 - 6+ months)

1. **CMEK (Customer-Managed Encryption Keys):**
   - Implement for production data at rest
   - Key rotation policies

2. **Certificate Authority Service:**
   - Internal CA for mTLS within GKE

3. **Compliance Certifications:**
   - SOC 2 Type II
   - ISO 27001

4. **Zero Trust Architecture:**
   - BeyondCorp Enterprise for workforce access
   - Identity-Aware Proxy (IAP) for internal apps

---

## 15. Operational Excellence

### 15.1 Change Management

**Terraform Workflow:**
- All infrastructure changes via Terraform
- No manual GCP Console changes (enforced via org policy)
- Pull request approval required for production changes

**Git Workflow:**
- Branch: feature/network-updates
- PR review by 2 team members
- Automated `terraform plan` in CI/CD
- Manual approval to apply

### 15.2 Monitoring and Alerting

**Critical Alerts:**
- Firewall rule changes
- IAM policy changes in production
- Org policy violations
- Budget exceeds 100%

**Notification Channels:**
- Email: ops-team@pcconnect.ai
- Slack: #gcp-alerts
- PagerDuty: On-call rotation

### 15.3 Documentation

**Required Documentation:**
- Network diagrams (updated quarterly)
- Disaster recovery runbook (tested quarterly)
- IAM access matrix (updated per personnel changes)
- Cost allocation report (monthly)

### 15.4 Training

**Team Training:**
- GCP Professional Cloud Architect certification (recommended)
- Terraform Associate certification (recommended)
- Quarterly DR drills

---

## 16. Future Partner Folder Expansion

### 16.1 Partner Folder Structure (NOT in Initial Deployment)

```
pcc-fldr
└── pcc-fldr-pe-#####  (Partner folders - FUTURE)
    ├── pcc-prj-pe-#####-staging
    └── pcc-prj-pe-#####-prod
```

**Reserved IP Space for Partners:**
- **Production:** 10.19.0.0/16, 10.20.0.0/16, ... (us-east4)
- **Production:** 10.35.0.0/16, 10.36.0.0/16, ... (us-central1)
- **Non-Production:** 10.27.0.0/16, 10.28.0.0/16, ... (us-east4)
- **Non-Production:** 10.43.0.0/16, 10.44.0.0/16, ... (us-central1)

**Partner Onboarding Process (Future):**
1. Create folder: pcc-fldr-pe-<partner-id>
2. Create projects: pcc-prj-pe-<partner-id>-staging/prod
3. Allocate subnets from reserved blocks
4. Attach to Shared VPC
5. Configure partner-specific IAM and org policies

---

## 17. Validation Checklist

### 17.1 Post-Deployment Validation

- [ ] Verify all folders created (5 folders)
- [ ] Verify all projects created (14 projects)
- [ ] Verify Shared VPC associations (all service projects attached)
- [ ] Test connectivity between VPCs (should be isolated)
- [ ] Test NAT gateway functionality (curl to external IP from VM)
- [ ] Verify IAM permissions (test user access)
- [ ] Validate log sink (generate test logs, verify BigQuery)
- [ ] Verify budget alerts (manually trigger alert)
- [ ] Test firewall rules (attempt blocked connection)
- [ ] Validate GKE subnet allocation (check secondary ranges)

### 17.2 Compliance Validation

- [ ] Verify org policies applied (no default networks, OS Login enabled)
- [ ] Audit Admin Activity Logs (verify logging enabled)
- [ ] Review IAM bindings (no primitive roles on users)
- [ ] Validate service account keys (none created)
- [ ] Review Security Command Center findings (address criticals)

---

## 18. Cost Forecast (12-Month)

| Month | Baseline Cost | With Workloads | Notes |
|-------|---------------|----------------|-------|
| 1 | $650 | $2,500 | Initial setup, minimal workloads |
| 2-3 | $650 | $3,200 | Gradual workload migration |
| 4-6 | $650 | $4,500 | Full production workloads |
| 7-9 | $650 | $4,200 | CUD savings kick in (-10%) |
| 10-12 | $650 | $4,000 | Rightsizing optimizations (-15%) |
| **Year 1 Total** | **$7,800** | **$46,000** | Average $3,833/month with workloads |

**Savings Opportunities:**
- Committed Use Discounts (Year 1, Month 4): -$6,000/year
- Idle resource automation: -$3,600/year
- Rightsizing recommendations: -$4,800/year
- **Potential Year 2 Cost:** $31,600 ($2,633/month) with full optimization

---

## 19. Success Metrics

### 19.1 Technical Metrics

- **Deployment Success Rate:** 100% (all projects and resources created)
- **Network Uptime:** 99.9% SLA
- **Mean Time to Recovery (MTTR):** <4 hours (RTO target)
- **Security Findings:** 0 critical, <5 high-severity findings
- **Cost Variance:** ±10% from budget

### 19.2 Operational Metrics

- **Terraform Apply Time:** <30 minutes for full foundation deployment
- **Change Failure Rate:** <5% (Terraform plan/apply failures)
- **Documentation Coverage:** 100% (all projects documented)
- **Team Onboarding Time:** <5 days for new team members

---

## 20. Next Steps

1. **Week 1:** Review and approve architecture plan
2. **Week 1-2:** Implement Terraform modules (folders, projects, network)
3. **Week 2-3:** Deploy Phase 1 (folders and projects)
4. **Week 3-4:** Deploy Phase 2 (network and GKE subnets)
5. **Week 4-5:** Deploy Phase 3 (IAM and security)
6. **Week 5-6:** Deploy Phase 4 (logging and monitoring)
7. **Week 6:** End-to-end validation and handoff

---

## Appendix A: IP Allocation Summary

### Production (us-east4: 10.16.0.0/13)

| Subnet | CIDR | Hosts | Purpose |
|--------|------|-------|---------|
| pcc-sub-prod-us-e4-primary | 10.16.0.0/18 | 16,382 | General workloads |
| pcc-sub-prod-us-e4-gke-reserved | 10.16.64.0/18 | 16,382 | Future GKE |
| pcc-sub-devops-prod-us-e4-main | 10.16.128.0/20 | 4,094 | GKE nodes |
| pcc-sub-devops-prod-us-e4-pods | 10.16.144.0/20 | 4,094 | GKE pods (secondary) |
| pcc-sub-devops-prod-us-e4-svc | 10.16.160.0/20 | 4,094 | GKE services (secondary) |
| pcc-sub-devops-prod-us-e4-overflow | 10.16.176.0/20 | 4,094 | GKE overflow |
| Reserved | 10.16.192.0/18 | 16,382 | Future expansion |
| Reserved | 10.17.0.0/16 - 10.23.0.0/16 | - | Future use |

### Non-Production (us-east4: 10.24.0.0/13)

| Subnet | CIDR | Hosts | Purpose |
|--------|------|-------|---------|
| pcc-sub-nonprod-us-e4-primary | 10.24.0.0/18 | 16,382 | General workloads |
| pcc-sub-nonprod-us-e4-gke-reserved | 10.24.64.0/18 | 16,382 | Future GKE |
| pcc-sub-devops-nonprod-us-e4-main | 10.24.128.0/20 | 4,094 | GKE nodes |
| pcc-sub-devops-nonprod-us-e4-pods | 10.24.144.0/20 | 4,094 | GKE pods (secondary) |
| pcc-sub-devops-nonprod-us-e4-svc | 10.24.160.0/20 | 4,094 | GKE services (secondary) |
| pcc-sub-devops-nonprod-us-e4-overflow | 10.24.176.0/20 | 4,094 | GKE overflow |
| Reserved | 10.24.192.0/18 | 16,382 | Future expansion |
| Reserved | 10.25.0.0/16 - 10.31.0.0/16 | - | Future use |

### Production DR (us-central1: 10.32.0.0/13)

| Subnet | CIDR | Hosts | Purpose |
|--------|------|-------|---------|
| pcc-sub-prod-us-c1-primary | 10.32.0.0/18 | 16,382 | DR workloads |
| Reserved | 10.32.64.0/18 - 10.39.0.0/16 | - | Future DR expansion |

### Non-Production DR (us-central1: 10.40.0.0/13)

| Subnet | CIDR | Hosts | Purpose |
|--------|------|-------|---------|
| pcc-sub-nonprod-us-c1-primary | 10.40.0.0/18 | 16,382 | DevTest workloads |
| Reserved | 10.40.64.0/18 - 10.47.0.0/16 | - | Future expansion |

---

## Appendix B: Firewall Rules Reference

### Production VPC Rules

| Name | Direction | Priority | Protocol | Source | Destination | Action | Logging |
|------|-----------|----------|----------|--------|-------------|--------|---------|
| pcc-fw-prod-allow-internal | INGRESS | 1000 | ALL | 10.16.0.0/13, 10.32.0.0/13 | 10.16.0.0/13, 10.32.0.0/13 | ALLOW | Yes |
| pcc-fw-prod-allow-iap | INGRESS | 1000 | TCP:22,3389 | 35.235.240.0/20 | All instances | ALLOW | Yes |
| pcc-fw-prod-allow-health-checks | INGRESS | 1000 | TCP:80,443 | 35.191.0.0/16, 130.211.0.0/22 | Tagged: load-balanced | ALLOW | No |
| pcc-fw-prod-allow-google-apis | EGRESS | 1000 | TCP:443 | All instances | private.googleapis.com | ALLOW | No |
| pcc-fw-prod-deny-all-egress | EGRESS | 65534 | ALL | All | 0.0.0.0/0 | DENY | Yes |

### Non-Production VPC Rules

| Name | Direction | Priority | Protocol | Source | Destination | Action | Logging |
|------|-----------|----------|----------|--------|-------------|--------|---------|
| pcc-fw-nonprod-allow-internal | INGRESS | 1000 | ALL | 10.24.0.0/13, 10.40.0.0/13 | 10.24.0.0/13, 10.40.0.0/13 | ALLOW | Yes |
| pcc-fw-nonprod-allow-iap | INGRESS | 1000 | TCP:22,3389 | 35.235.240.0/20 | All instances | ALLOW | Yes |
| pcc-fw-nonprod-allow-health-checks | INGRESS | 1000 | TCP:80,443 | 35.191.0.0/16, 130.211.0.0/22 | Tagged: load-balanced | ALLOW | No |
| pcc-fw-nonprod-allow-google-apis | EGRESS | 1000 | TCP:443 | All instances | private.googleapis.com | ALLOW | No |

---

## Appendix C: Contact Information

**Project Stakeholders:**
- **Project Sponsor:** [Name], [Email]
- **Technical Lead:** [Name], [Email]
- **Network Architect:** [Name], [Email]
- **Security Lead:** [Name], [Email]
- **FinOps Lead:** [Name], [Email]

**Support Channels:**
- **Slack:** #gcp-foundation-project
- **Email:** gcp-ops@pcconnect.ai
- **On-Call:** PagerDuty rotation (gcp-oncall)

---

## Document Control

**Version:** 1.0
**Date:** 2025-10-01
**Author:** Claude (Cloud Architect Agent)
**Status:** Draft for Review
**Next Review:** 2025-10-15

**Change Log:**
- 2025-10-01: Initial architecture plan created

---

**END OF ARCHITECTURE PLAN**
