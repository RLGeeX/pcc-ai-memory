# ADR 003: AlloyDB High Availability Strategy

**Date**: 2025-10-24
**Status**: Accepted
**Decision Makers**: Lead Architect
**Consulted**: Google Cloud AlloyDB Documentation, Cloud Architecture Center

## Context

PortCo Connect (PCC) requires a PostgreSQL-compatible database for 7 microservices (user-api, auth-api, task-tracker-api, etc.). We need to balance high availability requirements with cost constraints across four environments: devtest, dev, staging, and prod.

### Business Context
- Small team with limited budget for infrastructure
- Different availability requirements per environment
- Development and testing environments tolerate brief outages
- Production requires high availability for customer SLAs
- Need clear path from cost-effective development to production-ready infrastructure

### Technical Requirements
1. **Environment-specific HA**: Different availability postures for development vs production
2. **Cost management**: Minimize spend in non-production environments
3. **Production reliability**: 99.99% availability target for production
4. **Regional resilience**: Staging must test production-like HA behavior
5. **Performance**: Sub-10ms read/write latency for all environments
6. **PostgreSQL compatibility**: Support existing application code without modification

### AlloyDB Availability Options

**ZONAL (Single Zone)**
- Structure: Primary instance in single availability zone
- Failover: Manual promotion or instance recreation (~5-10 min downtime)
- Cost: Base cost (~$200/month for db-standard-2)
- Availability: 99.5% SLA

**REGIONAL (Multi-Zone High Availability)**
- Structure: Primary instance + synchronous read replica in different zone
- Failover: Automatic promotion (~60-120 seconds)
- Cost: 2.5-3x base cost (~$600/month for db-standard-2)
- Availability: 99.99% SLA

**MULTI-REGION (Cross-Region Disaster Recovery)**
- Structure: PRIMARY cluster + SECONDARY cluster in different region
- Failover: Manual region switch or automated GeoRedundancy
- Cost: 4-6x base cost (~$1600+/month, multiple clusters)
- Availability: 99.999% SLA with cross-region DR

## Decision

We will implement an **environment-tiered HA strategy** with different AlloyDB configurations per environment:

### Four Environment Architecture

**Devtest Environment** (`pcc-prj-app-devtest`)
- **Configuration**: ZONAL (single zone)
- **HA**: No read replica
- **Justification**: Manual testing environment, brief outages acceptable
- **Cost**: ~$200/month
- **SLA**: 99.5%

**Dev Environment** (`pcc-prj-app-dev`)
- **Configuration**: ZONAL (single zone)
- **HA**: No read replica
- **Justification**: CI/CD testing, tolerates outages during pipeline runs
- **Cost**: ~$200/month
- **SLA**: 99.5%

**Staging Environment** (`pcc-prj-app-staging`)
- **Configuration**: REGIONAL (multi-zone HA)
- **HA**: Automatic failover with read replica
- **Justification**: Pre-production testing, must validate production-like behavior
- **Cost**: ~$600/month
- **SLA**: 99.99%

**Production Environment** (`pcc-prj-app-prod`)
- **Configuration**: REGIONAL (multi-zone HA)
- **HA**: Automatic failover with read replica
- **Future**: Multi-region DR (Phase 4+)
- **Cost**: ~$600/month (current), ~$1600+/month (future multi-region)
- **SLA**: 99.99% (current), 99.999% (future)

### Cluster Naming Convention
- `pcc-alloydb-devtest` (ZONAL)
- `pcc-alloydb-dev` (ZONAL)
- `pcc-alloydb-staging` (REGIONAL)
- `pcc-alloydb-prod` (REGIONAL, future multi-region)

### Database Naming Convention
**Same database name across all environments**: `client_api_db`

**Rationale**:
- Application code is environment-agnostic
- Differentiation happens at cluster level (cluster name includes environment)
- Simplifies connection string management
- Consistent schema across environments

## Rationale

### Advantages

1. **Cost Optimization**
   - 60% cost savings in devtest/dev environments
   - Pay for HA only where it's required (staging, prod)
   - Clear budget allocation per environment

2. **Production Parity in Staging**
   - Staging validates exact HA behavior that will run in production
   - Tests automatic failover, replica lag, connection pooling
   - Catches HA-specific issues before customer impact

3. **Development Velocity**
   - Devtest/dev environments are lower cost, enabling more experimentation
   - Can destroy/recreate development databases without HA cost concern
   - Shorter creation time (ZONAL: 10-12 min vs REGIONAL: 15-20 min)

4. **Operational Simplicity**
   - Single terraform module supports all configurations via `cluster_type` variable
   - Consistent management across environments
   - Clear upgrade path: ZONAL → REGIONAL as environment matures

5. **Future-Proof Architecture**
   - REGIONAL configuration supports multi-region upgrade path
   - Production can scale to cross-region DR without redesign
   - Staging environment can test multi-region behavior before production rollout

### Trade-offs Accepted

1. **Development Environment Risk**
   - Devtest/dev can experience 5-10 minute outages during failures
   - Acceptable: these are internal development environments
   - Mitigation: Use staging for any availability-sensitive testing

2. **Manual Failover in Development**
   - No automatic failover in devtest/dev
   - Acceptable: manual intervention OK for development environments
   - Mitigation: Document failover procedures, consider this learning opportunity

3. **Cost Differential**
   - 3x cost difference between dev and staging
   - Acceptable: staging/prod justify cost with customer SLAs
   - Mitigation: Monitor actual usage, can downsize dev instances if underutilized

## Consequences

### Positive

- **$800/month savings** in Phase 2 (devtest + dev ZONAL vs REGIONAL)
- **Production confidence**: Staging environment proves HA behavior
- **Clear cost model**: Easy to explain and budget
- **Flexible architecture**: Can upgrade environments independently

### Negative

- **Configuration complexity**: Must manage different cluster types
- **Testing gaps**: Cannot test automatic failover in development environments
- **Documentation burden**: Must document which environments have HA

### Mitigation Strategies

1. **Reusable Terraform Module**
   - Single `alloydb-cluster` module in pcc-tf-library
   - Variable: `cluster_type = "ZONAL" | "REGIONAL"`
   - Conditional resource creation for read replicas
   - DRY principle: same code for all environments

2. **Clear Environment Documentation**
   - README.md in each infra repo documents HA configuration
   - Phase planning documents specify cluster type per environment
   - Runbooks include failover procedures per environment

3. **Staging as HA Test Environment**
   - Mandate staging testing for any HA-sensitive features
   - Chaos engineering tests run in staging (not dev)
   - Pre-production validation includes failover testing

4. **Monitoring and Alerting**
   - All environments monitored regardless of HA configuration
   - Separate SLA targets per environment
   - Automatic alerts for staging/prod, manual for dev

## Alternatives Considered

### Alternative 1: REGIONAL HA for All Environments
**Rejected because:**
- Unnecessary $1600/month cost for devtest + dev environments
- HA not required for internal development work
- Budget better spent on production infrastructure or additional environments
- Creates false expectation of production-grade availability in development

### Alternative 2: ZONAL for All Environments (Including Prod)
**Rejected because:**
- Unacceptable availability risk for customer-facing production
- Manual failover increases MTTR during production incidents
- No competitive advantage if platform has frequent outages
- Staging would not validate production HA behavior

### Alternative 3: Multi-Region from Day 1
**Rejected because:**
- Premature optimization: multi-region DR not required for initial launch
- 8x cost increase ($3200+/month total) not justified by current scale
- Significant operational complexity managing cross-region clusters
- Better to prove product-market fit before investing in cross-region DR

### Alternative 4: Staging ZONAL, Production REGIONAL Only
**Rejected because:**
- Staging would not validate production HA behavior
- HA-specific bugs (replica lag, failover timing) would surface in production
- $300/month savings not worth loss of production parity testing
- Staging environment must be production-identical per Apigee ADR-001 pattern

## Implementation Notes

### Terraform Module Structure

**Module**: `pcc-tf-library/modules/alloydb-cluster`

```hcl
variable "cluster_type" {
  description = "Cluster availability type: ZONAL or REGIONAL"
  type        = string
  default     = "ZONAL"

  validation {
    condition     = contains(["ZONAL", "REGIONAL"], var.cluster_type)
    error_message = "cluster_type must be either ZONAL or REGIONAL"
  }
}

resource "google_alloydb_cluster" "cluster" {
  cluster_id = var.cluster_id
  location   = var.region

  automated_backup_policy {
    enabled = var.cluster_type == "REGIONAL" ? true : var.automated_backup_enabled
  }
}

# Conditional read replica for REGIONAL clusters
resource "google_alloydb_instance" "read_replica" {
  count = var.cluster_type == "REGIONAL" ? 1 : 0

  cluster       = google_alloydb_cluster.cluster.name
  instance_id   = "read-replica"
  instance_type = "READ_POOL"
}
```

### Environment Configuration

**Devtest**: `alloydb.tf`
```hcl
module "alloydb" {
  source = "git::https://github.com/portco-connect/pcc-tf-library.git//modules/alloydb-cluster?ref=main"

  cluster_id   = "pcc-alloydb-${var.environment}"
  cluster_type = "ZONAL"  # devtest
}
```

**Staging**: `alloydb.tf`
```hcl
module "alloydb" {
  source = "git::https://github.com/portco-connect/pcc-tf-library.git//modules/alloydb-cluster?ref=main"

  cluster_id   = "pcc-alloydb-${var.environment}"
  cluster_type = "REGIONAL"  # staging
}
```

### Future Multi-Region Architecture (Phase 4+)

**Production Multi-Region** (not implemented in Phase 2):
```hcl
# PRIMARY cluster in us-east4
module "alloydb_primary" {
  source       = "git::https://github.com/portco-connect/pcc-tf-library.git//modules/alloydb-multi-region?ref=main"
  cluster_id   = "pcc-alloydb-prod-primary"
  region       = "us-east4"
  cluster_type = "PRIMARY"
}

# SECONDARY cluster in us-west2
module "alloydb_secondary" {
  source        = "git::https://github.com/portco-connect/pcc-tf-library.git//modules/alloydb-multi-region?ref=main"
  cluster_id    = "pcc-alloydb-prod-secondary"
  region        = "us-west2"
  cluster_type  = "SECONDARY"
  primary_cluster = module.alloydb_primary.cluster_name
}
```

**Note**: Multi-region requires new module (`alloydb-multi-region`), separate from current Phase 2 implementation.

### Cost Monitoring

**Monthly Budget Alerts**:
- Devtest: Alert at $250 (buffer above $200 baseline)
- Dev: Alert at $250
- Staging: Alert at $700 (buffer above $600 baseline)
- Prod: Alert at $700 (current), $1800 (future multi-region)

### Upgrade Path

**ZONAL → REGIONAL Migration**:
1. Export database schema and data
2. Create new REGIONAL cluster
3. Import data to new cluster
4. Update connection strings
5. Cutover during maintenance window
6. Delete old ZONAL cluster

**Downtime**: 15-30 minutes (controlled migration)

## References

- [AlloyDB HA Architecture](https://cloud.google.com/alloydb/docs/cluster-instance-overview)
- [AlloyDB Pricing](https://cloud.google.com/alloydb/pricing)
- [Phase 2.1: AlloyDB Module Skeleton](./../plans/devtest-deployment/phase-2.1-implement-alloydb-module-skeleton.md)
- [Phase 2.3: AlloyDB Configuration](./../plans/devtest-deployment/phase-2.3-create-alloydb-configuration.md)
- [ADR-001: Two-Organization Apigee X Architecture](./001-two-org-apigee-architecture.md) (staging parity pattern)

## Approval

- [x] Lead Architect Approval
- [ ] FinOps Team Review (budget allocation)
- [ ] Dev Partner Approval

---

*This ADR establishes the HA strategy for Phase 2 AlloyDB deployment. Future multi-region architecture will be documented in a separate ADR during Phase 4 planning.*
