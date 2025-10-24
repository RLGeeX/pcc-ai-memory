# ADR 007: Four Environment Architecture

**Date**: 2025-10-24
**Status**: Accepted
**Decision Makers**: Lead Architect, DevOps Lead, Product Owner
**Consulted**: Google Cloud Architecture Center, Industry Best Practices

## Context

PortCo Connect (PCC) requires a multi-environment deployment strategy that balances development velocity, production stability, customer testing requirements, and cost constraints. We need to determine the optimal number of environments and their purposes.

### Business Context
- Small team (5-10 developers) building portfolio risk management platform
- Limited budget for infrastructure ($3000-5000/month total)
- Need safe testing of infrastructure and application changes
- Require customer integration testing environment
- Must maintain production uptime (99.99% SLA target)
- Support CI/CD automation for rapid iteration

### Technical Requirements
1. **Development Velocity**: Developers can iterate quickly without production concerns
2. **Infrastructure Safety**: Test org-level changes (networking, IAM) before production
3. **CI/CD Integration**: Automated pipeline deployment and validation
4. **Customer Testing**: Realistic pre-production environment for customer integration
5. **Production Isolation**: Zero risk of development/testing affecting live customers
6. **Cost Management**: Minimize redundant infrastructure while maintaining safety

### Environment Architecture Options

**Option 1: Two Environments (dev + prod)**
- Structure: Development + Production
- Cost: Lowest (2x infrastructure)
- Safety: Minimal (no pre-production validation)
- Customer Testing: In production (risky)

**Option 2: Three Environments (dev + staging + prod)**
- Structure: Development + Staging + Production
- Cost: Medium (3x infrastructure)
- Safety: Good (staging validates prod deployments)
- Customer Testing: In staging (good)
- Infrastructure Testing: In dev (shares with development work)

**Option 3: Four Environments (devtest + dev + staging + prod)**
- Structure: DevTest + Development + Staging + Production
- Cost: Higher (4x infrastructure for some services)
- Safety: Excellent (dedicated infrastructure testing environment)
- Customer Testing: In staging (isolated from dev work)
- Infrastructure Testing: In devtest (isolated from dev work)

**Option 4: Five+ Environments (devtest + dev + qa + uat + staging + prod)**
- Structure: Multiple pre-production environments
- Cost: Highest (5-6x infrastructure)
- Safety: Maximum (many validation gates)
- Complexity: High operational overhead
- Over-engineering: Unnecessary for team size

## Decision

We will implement a **four-environment architecture** with the following structure:

### Environment Definitions

**1. DevTest Environment** (`pcc-prj-app-devtest`)

**Purpose**: Infrastructure experimentation and manual testing
- GCP Project: `pcc-prj-app-devtest`
- AlloyDB: ZONAL (no HA, ~$200/month)
- GKE: Small cluster (3 nodes, n1-standard-2)
- Audience: Platform team, infrastructure engineers
- Stability: Unstable, breaking changes acceptable
- Deployment: Manual (kubectl apply, terraform apply)
- Data: Synthetic test data, ephemeral

**Use Cases**:
- Test AlloyDB HA configurations before dev
- Experiment with Workload Identity bindings
- Validate new Terraform modules
- Test Flyway migrations before dev
- Try new GKE features or node pools
- **NO automated CI/CD deployments**
- **NO customer access**

**2. Dev Environment** (`pcc-prj-app-dev`)

**Purpose**: CI/CD pipeline validation and automated testing
- GCP Project: `pcc-prj-app-dev`
- AlloyDB: ZONAL (no HA, ~$200/month)
- GKE: Medium cluster (5 nodes, n1-standard-4)
- Audience: Development team, automated tests
- Stability: Moderate, frequent deployments
- Deployment: Automated (Cloud Build, Argo CD)
- Data: Synthetic test data, refreshed nightly

**Use Cases**:
- Automated PR validation (build, test, deploy)
- Integration testing across microservices
- Performance testing (load tests)
- Security scanning (vulnerability detection)
- Smoke tests after deployment
- **First environment with automated deployments**
- **NO customer access**

**3. Staging Environment** (`pcc-prj-app-staging`)

**Purpose**: Pre-production validation and customer integration testing
- GCP Project: `pcc-prj-app-staging`
- AlloyDB: REGIONAL (HA, ~$600/month)
- GKE: Production-identical cluster (10 nodes, n1-standard-8)
- Audience: Customers, QA team, product owners
- Stability: High, production-like behavior
- Deployment: Automated (after dev validation)
- Data: Production-like synthetic data, anonymized customer data

**Use Cases**:
- Customer integration testing (API contracts)
- QA validation before production release
- Performance testing under production-like load
- Disaster recovery testing (failover, backup restore)
- Production dry-run (exact same deployment as prod)
- **Production-identical infrastructure (HA, REGIONAL)**
- **Customer-accessible for integration testing**

**4. Production Environment** (`pcc-prj-app-prod`)

**Purpose**: Live customer traffic, production SLAs
- GCP Project: `pcc-prj-app-prod`
- AlloyDB: REGIONAL (HA, ~$600/month) → Multi-region (Phase 4)
- GKE: Large cluster (20+ nodes, autoscaling)
- Audience: End users, customers
- Stability: Highest, 99.99% SLA target
- Deployment: Automated (after staging validation)
- Data: Live customer data, production backups

**Use Cases**:
- Live customer traffic
- Revenue-generating operations
- Production monitoring and alerting
- Incident response and on-call
- **Production SLAs enforced**
- **Multi-region DR (future Phase 4)**

### Environment Comparison Matrix

| Aspect | DevTest | Dev | Staging | Prod |
|--------|---------|-----|---------|------|
| **Audience** | Platform team | Dev team + CI/CD | Customers + QA | End users |
| **Deployment** | Manual | Automated (PR) | Automated (after dev) | Automated (after staging) |
| **AlloyDB HA** | ZONAL | ZONAL | REGIONAL | REGIONAL (→ Multi-region) |
| **GKE Size** | Small (3 nodes) | Medium (5 nodes) | Large (10 nodes) | X-Large (20+ nodes) |
| **Cost/Month** | ~$400 | ~$600 | ~$1200 | ~$1500+ |
| **Stability** | Unstable | Moderate | High | Highest |
| **Breaking Changes** | ✅ Acceptable | ⚠️ Avoid | ❌ Prohibited | ❌ Prohibited |
| **Customer Access** | ❌ No | ❌ No | ✅ Yes | ✅ Yes |
| **Data Type** | Synthetic | Synthetic | Prod-like | Live customer data |
| **SLA** | None | None | 99.9% | 99.99% |

### Promotion Path

**Code Deployment Flow**:
```
Developer → PR → DevTest (manual) → Dev (CI/CD) → Staging (CI/CD) → Prod (CI/CD)
                    ↓                     ↓               ↓                ↓
               Manual test          Automated tests   Customer tests    Live traffic
               Break things         Integration       QA validation     SLA enforced
               Experiment           Performance       DR testing        Monitoring
```

**Infrastructure Deployment Flow** (Terraform):
```
DevTest (manual terraform apply)
  ↓ validate for 24-48 hours
Dev (manual terraform apply)
  ↓ soak test for 48 hours
Staging (manual terraform apply, maintenance window)
  ↓ validate for 72 hours
Prod (manual terraform apply, maintenance window)
```

### Cost Analysis

**Monthly Infrastructure Cost** (Phase 2):

**DevTest**:
- AlloyDB ZONAL: $200
- GKE (3 nodes, n1-standard-2): $150
- Secret Manager: $5
- **Total**: ~$400/month

**Dev**:
- AlloyDB ZONAL: $200
- GKE (5 nodes, n1-standard-4): $350
- Secret Manager: $5
- **Total**: ~$600/month

**Staging**:
- AlloyDB REGIONAL: $600
- GKE (10 nodes, n1-standard-8): $1400
- Secret Manager: $10
- **Total**: ~$1200/month

**Prod**:
- AlloyDB REGIONAL: $600 (Phase 2) → $1600 (Phase 4 multi-region)
- GKE (20 nodes, autoscaling): $2000+
- Secret Manager: $10
- **Total**: ~$1500/month (Phase 2), ~$3000+/month (Phase 4)

**Total Monthly Cost**: ~$3700/month (Phase 2), ~$5200/month (Phase 4)

**Cost Optimization**:
- DevTest + Dev use ZONAL AlloyDB: 60% savings vs REGIONAL
- Smaller GKE clusters in non-production: 50-75% node cost savings
- Shutdown devtest/dev overnight (future): Additional 50% savings on GKE

## Rationale

### Advantages

1. **Infrastructure Safety Testing**
   - DevTest provides isolated environment for infrastructure experiments
   - AlloyDB HA configuration tested in devtest before dev
   - Networking changes (VPC, firewall) validated without dev disruption
   - Terraform module changes proven before dev deployment

2. **CI/CD Pipeline Validation**
   - Dev environment is CI/CD target (automated deployments)
   - Every PR triggers deployment to dev
   - Integration tests run automatically in dev
   - Performance tests validate before staging promotion

3. **Customer Integration Testing**
   - Staging provides production-identical environment for customers
   - Customers test API integrations in staging (not dev)
   - QA team validates staging before prod release
   - Staging validates exact deployment that will reach prod

4. **Production Isolation**
   - Zero risk of development/testing affecting production
   - Clear separation: dev work in dev, customer testing in staging
   - Production reserved for live customer traffic only
   - No experiments, no manual testing in production

5. **Cost-Effective Isolation**
   - 4 environments provide essential isolation
   - Devtest + dev are cost-optimized (ZONAL AlloyDB, smaller GKE)
   - Staging + prod are production-grade (REGIONAL AlloyDB, large GKE)
   - $3700/month reasonable for 4-environment platform

6. **Clear Purpose Per Environment**
   - Devtest: "Break things, try new ideas"
   - Dev: "Automated CI/CD validation"
   - Staging: "Customer integration testing"
   - Prod: "Live customer traffic"
   - No ambiguity about which environment to use

### Trade-offs Accepted

1. **Higher Infrastructure Cost**
   - 4 environments cost 2x more than 2 environments
   - Acceptable: Safety and isolation justify cost
   - Mitigation: Cost-optimize devtest/dev (ZONAL, smaller GKE)

2. **Operational Complexity**
   - Must manage 4 complete environments
   - More Terraform to maintain, more monitoring
   - Acceptable: Terraform modules reduce duplication (DRY)

3. **Longer Deployment Pipeline**
   - Code passes through 4 environments (devtest → dev → staging → prod)
   - Takes longer than 2-environment pipeline
   - Acceptable: Quality gates prevent production issues

4. **Resource Duplication**
   - Secrets, IAM bindings, configurations duplicated 4x
   - Acceptable: Terraform `for_each` and variables reduce duplication

## Consequences

### Positive

- **Safety**: Infrastructure changes tested in devtest before dev
- **Quality**: Automated tests in dev catch regressions
- **Confidence**: Customer testing in staging validates production readiness
- **Stability**: Production isolated from all development/testing work
- **Compliance**: Clear audit trail (which environment, when, by whom)

### Negative

- **Cost**: $3700/month for 4 environments (vs $1500 for 2 environments)
- **Complexity**: More environments to manage, monitor, troubleshoot
- **Pipeline Time**: Longer deployment pipeline (devtest → dev → staging → prod)
- **Configuration Duplication**: 4x secrets, IAM bindings, terraform

### Mitigation Strategies

1. **Terraform Modules (DRY)**
   - Reusable modules in pcc-tf-library
   - Variable-driven configuration per environment
   - Minimize duplication, consistent patterns

2. **Cost Optimization**
   - Devtest + dev use ZONAL AlloyDB (60% savings)
   - Smaller GKE clusters in non-production (50-75% savings)
   - Future: Shutdown devtest/dev overnight (additional 50% GKE savings)

3. **Automated Promotion**
   - CI/CD pipeline automates dev → staging → prod
   - Manual gate between staging and prod (approval required)
   - Rollback automation if deployment fails

4. **Monitoring Consolidation**
   - Single Cloud Monitoring workspace for all environments
   - Unified dashboards, cross-environment metrics
   - Centralized alerting and incident response

## Alternatives Considered

### Alternative 1: Two Environments (dev + prod)
**Rejected because:**
- No safe infrastructure testing (org-level changes affect prod)
- No customer integration testing environment
- No CI/CD validation before production
- Single point of failure (dev also serves as staging)
- **Too risky**: No production parity testing

### Alternative 2: Three Environments (dev + staging + prod)
**Rejected because:**
- Dev environment must serve dual purpose:
  * Infrastructure experimentation (unstable)
  * CI/CD pipeline validation (stable)
- Conflicting requirements lead to:
  * Either too unstable for CI/CD
  * Or too constrained for infrastructure experiments
- **Lacks isolation**: Infrastructure experiments disrupt CI/CD

### Alternative 3: Five Environments (devtest + dev + qa + uat + staging + prod)
**Rejected because:**
- Excessive cost ($5000+/month for 5 environments)
- QA and UAT overlap with staging purpose
- Operational complexity managing 5 environments
- Diminishing returns: marginal safety benefit
- **Over-engineering**: 3 pre-production environments unnecessary for team size

### Alternative 4: Single Shared "Non-Prod" Environment
**Rejected because:**
- Shared environment becomes bottleneck
- Deployment conflicts between teams
- Cannot isolate infrastructure experiments from CI/CD
- No clear ownership or purpose
- **Antipattern**: Shared environments lead to "works on my machine" problems

## Implementation Notes

### GCP Project Structure

**Existing Foundation** (from `pcc-foundation-infra`):
```
pcc-fldr-app (Application Folder)
├── pcc-prj-app-devtest
├── pcc-prj-app-dev
├── pcc-prj-app-staging
└── pcc-prj-app-prod

pcc-fldr-data (Data Folder)
├── pcc-prj-data-devtest
├── pcc-prj-data-dev
├── pcc-prj-data-staging
└── pcc-prj-data-prod
```

**Project Naming Convention**:
- Format: `pcc-prj-{domain}-{environment}`
- Examples: `pcc-prj-app-devtest`, `pcc-prj-data-staging`

### Terraform Variable Pattern

**Environment Variable**:
```hcl
variable "environment" {
  description = "Environment name: devtest, dev, staging, or prod"
  type        = string

  validation {
    condition     = contains(["devtest", "dev", "staging", "prod"], var.environment)
    error_message = "Environment must be one of: devtest, dev, staging, prod"
  }
}
```

**Configuration Per Environment**:
```hcl
locals {
  # AlloyDB cluster type based on environment
  cluster_type = contains(["staging", "prod"], var.environment) ? "REGIONAL" : "ZONAL"

  # GKE node count based on environment
  gke_node_count = {
    devtest = 3
    dev     = 5
    staging = 10
    prod    = 20
  }

  # Automated backup based on environment
  automated_backup = contains(["staging", "prod"], var.environment) ? true : false
}
```

### Access Control Pattern

**IAM Roles Per Environment**:
```
DevTest:
- Platform team: Owner (full access for experimentation)
- Dev team: Viewer (read-only)

Dev:
- Platform team: Editor (can deploy infrastructure)
- Dev team: Developer (can deploy applications)
- CI/CD service account: Developer

Staging:
- Platform team: Editor
- Dev team: Developer
- QA team: Viewer
- Customer: API Consumer (limited to API Gateway)

Prod:
- Platform team: Editor (restricted, requires approval)
- Dev team: Viewer (read-only, no deployment)
- On-call: Emergency Responder
- CI/CD service account: Developer (limited, requires approval)
```

### Monitoring and Alerting

**Alert Severity Per Environment**:
```
DevTest: No alerts (manual monitoring)
Dev: Info-level alerts (Slack notifications)
Staging: Warning-level alerts (email + Slack)
Prod: Critical-level alerts (PagerDuty + email + Slack)
```

**SLA Targets**:
```
DevTest: No SLA
Dev: No SLA
Staging: 99.9% uptime (best-effort)
Prod: 99.99% uptime (contractual SLA)
```

## References

- [Google Cloud Architecture Framework](https://cloud.google.com/architecture/framework)
- [Phase 2 Implementation Files](./../plans/devtest-deployment/)
- [ADR-001: Two-Organization Apigee X Architecture](./001-two-org-apigee-architecture.md)
- [ADR-003: AlloyDB HA Strategy](./003-alloydb-ha-strategy.md)
- [ADR-004: Secret Management Approach](./004-secret-management-approach.md)
- [ADR-005: Workload Identity Pattern](./005-workload-identity-pattern.md)
- [ADR-006: Database Migration Strategy](./006-database-migration-strategy.md)

## Approval

- [x] Lead Architect Approval
- [x] DevOps Lead Approval
- [x] Product Owner Approval
- [ ] Finance Approval (budget allocation)
- [ ] Dev Partner Approval

---

*This ADR establishes the four-environment architecture for all PCC infrastructure. All future infrastructure decisions must consider impact across all four environments.*
