# ADR 009: Regional Deployment Strategy

**Date**: 2025-10-25
**Status**: Accepted
**Decision Makers**: Lead Architect, FinOps Lead
**Consulted**: Google Cloud Architecture Center, GCP Regions Documentation

## Context

PortCo Connect (PCC) requires a consistent regional deployment strategy for multi-region services including AlloyDB, GKE, Apigee X, Cloud Storage, BigQuery, and Artifact Registry. Regional decisions impact latency, disaster recovery capability, compliance, and cost.

### Business Context
- Portfolio risk management platform serving financial institutions
- Primary user base: East Coast United States (NYC, Boston financial centers)
- Latency requirements: Sub-100ms for API responses
- Disaster recovery: 99.99% availability target for production
- Compliance: Data residency requirements (US-only)
- Cost constraints: Minimize unnecessary cross-region data transfer

### Technical Requirements
1. **Low Latency**: Primary region close to user population
2. **Geographic Separation**: Secondary region for disaster recovery (500+ miles)
3. **Cost Optimization**: Avoid expensive cross-region egress where possible
4. **Compliance**: All data remains within United States
5. **Future Multi-Region**: Support for cross-region replication (AlloyDB, Cloud Storage)
6. **Consistent Strategy**: Same regions across all services

### GCP Regional Considerations

**us-east4 (Northern Virginia)**
- Location: Ashburn, VA
- Proximity: 225 miles from NYC financial centers
- Latency: 5-10ms to East Coast users
- Pricing: Standard tier
- Connectivity: Multiple fiber paths to financial hubs
- Carbon footprint: 51% CFE (carbon-free energy)

**us-central1 (Iowa)**
- Location: Council Bluffs, IA
- Distance from us-east4: ~850 miles (good DR separation)
- Latency: 30-40ms cross-region to us-east4
- Pricing: Standard tier (same as us-east4)
- Connectivity: Central US location
- Carbon footprint: 96% CFE
- Cost-effective secondary region

**us-west1 (Oregon)** - Considered but rejected
- Distance from us-east4: ~2,400 miles
- Latency: 70-80ms cross-region
- Higher cross-region transfer costs
- Overkill for disaster recovery separation

**us-east1 (South Carolina)** - Considered but rejected
- Distance from us-east4: ~400 miles (insufficient DR separation)
- Same weather patterns (hurricane risk)
- Insufficient blast radius for DR

## Decision

We will implement a **two-region strategy** with the following regional assignments:

### Primary Region: **us-east4** (Northern Virginia)

**Purpose**: Primary operations for all environments (devtest, dev, staging, prod)

**Services Deployed**:
- AlloyDB primary clusters
- GKE primary clusters (devops, app workloads)
- Apigee X primary instances (API gateway)
- Cloud Storage primary buckets
- BigQuery primary datasets
- Artifact Registry primary repositories
- Secret Manager secrets

**Rationale**:
- Closest to primary user base (East Coast financial centers)
- Lowest latency for real-time API traffic
- Primary location for all four environments (ADR-007)
- Strong network connectivity to NYC, Boston, DC

### Secondary Region: **us-central1** (Iowa)

**Purpose**: Disaster recovery and multi-region replication

**Services Deployed**:
- AlloyDB secondary clusters (prod only, future Phase 4+)
- GKE secondary clusters (prod only, future multi-region)
- Apigee X secondary instances (multi-region HA / DR failover)
- Cloud Storage secondary buckets (dual-region or multi-region)
- BigQuery secondary datasets (cross-region replication)
- Artifact Registry mirrors (optional)

**Rationale**:
- Geographic separation: 850 miles (meets DR best practice)
- Different seismic/weather zone (reduces correlated failure risk)
- Cost-effective secondary region (same pricing tier)
- Central US location balances East/West traffic
- High carbon-free energy percentage (96% CFE)

## Rationale

### Advantages

1. **Optimal Latency**
   - us-east4 provides 5-10ms latency to East Coast users
   - Competitive advantage for real-time portfolio risk calculations
   - Meets sub-100ms API response requirement

2. **Effective Disaster Recovery**
   - 850-mile separation protects against regional disasters
   - Different weather patterns (reduces hurricane correlation)
   - Cross-region replication latency: 30-40ms (acceptable for async)

3. **Cost Optimization**
   - Same pricing tier for both regions (no premium region costs)
   - Minimizes cross-region data transfer (most traffic stays in us-east4)
   - Future multi-region costs manageable

4. **Compliance Alignment**
   - Both regions within United States
   - Meets data residency requirements
   - Supports regulatory constraints (FINRA, SEC)

5. **Consistency Across Services**
   - AlloyDB, GKE, Apigee, Cloud Storage all use same regions
   - Simplifies terraform module configuration
   - Reduces operational complexity

6. **Environmental Consideration**
   - us-central1: 96% carbon-free energy
   - us-east4: 51% carbon-free energy
   - Both better than many alternatives

### Trade-offs Accepted

1. **Single Region for Development**
   - Devtest, dev, staging all in us-east4 only
   - Acceptable: Development environments don't require DR
   - Cost savings: No redundant development infrastructure

2. **Cross-Region Replication Latency**
   - 30-40ms for us-east4 ↔ us-central1
   - Acceptable: Async replication tolerates this latency
   - AlloyDB cross-region RPO: <5 minutes

3. **West Coast Latency**
   - West Coast users experience 60-70ms latency
   - Acceptable: Primary user base is East Coast
   - Can add us-west region in future if needed

## Consequences

### Positive

- **Clear regional strategy** across all GCP services
- **Cost predictability** with consistent region selection
- **Simplified terraform modules** with standard region variables
- **DR-ready architecture** from day one
- **Future multi-region path** well-defined

### Negative

- **Documentation maintenance**: Must update if regions change
- **Regional quota management**: Need quotas in both regions
- **Cross-region testing**: DR testing requires secondary region resources

### Mitigation Strategies

1. **Regional Variables in Terraform**
   - Centralized region configuration
   - Default: `region = "us-east4"`
   - Explicit overrides for secondary deployments

2. **Organization Policy Constraints**
   ```hcl
   constraint: constraints/gcp.resourceLocations
   allowed_values:
     - in:us-east4-locations
     - in:us-central1-locations
   ```

3. **Documentation References**
   - All ADRs reference ADR-009 for regional decisions
   - Phase plans include regional context
   - Deployment guides specify region requirements

4. **Cost Monitoring**
   - Separate budgets per region
   - Cross-region egress alerts
   - Monthly regional cost review

## Applies To

This regional strategy applies to the following services:

### Phase 2: AlloyDB
- **Current**: ZONAL/REGIONAL in us-east4 (ADR-003)
- **Future**: Multi-region with PRIMARY (us-east4) + SECONDARY (us-central1)

### Phase 3: GKE
- **Current**: GKE clusters in us-east4
- **Future**: Multi-region GKE with us-central1 secondary

### Phase 4+: Apigee X
- **Primary instance**: us-east4 (co-located with GKE and backends)
- **Secondary instance**: us-central1 (multi-region HA / DR)
- **Rationale**: API gateway must be in primary region to minimize latency for East Coast users and backend services

### Phase 4+: Cloud Storage
- **Primary buckets**: us-east4 (single region)
- **Multi-region buckets**: US (includes both regions)
- **Terraform state**: us-east4 (existing `pcc-tfstate-foundation-us-east4`)

### Phase 4+: BigQuery
- **Primary datasets**: us-east4
- **Cross-region backup**: us-central1

### All Phases: Artifact Registry
- **Primary registry**: us-east4
- **Optional mirrors**: us-central1 (for DR)

## Alternatives Considered

### Alternative 1: us-east4 + us-west1
**Rejected because:**
- 2,400-mile separation is overkill for DR
- 70-80ms cross-region latency hurts replication performance
- Higher cross-region egress costs
- West Coast location doesn't serve primary user base

### Alternative 2: us-east4 + us-east1
**Rejected because:**
- Only 400 miles separation (insufficient for DR)
- Correlated weather risks (both in hurricane zone)
- Similar seismic profile (insufficient blast radius)
- Doesn't meet 500+ mile DR best practice

### Alternative 3: Multi-region from Day 1
**Rejected because:**
- Premature optimization for current scale
- 4-6x infrastructure cost not justified
- Operational complexity too high for small team
- Better to prove product-market fit first

### Alternative 4: Single Region (us-east4 only)
**Rejected because:**
- No disaster recovery capability
- Violates 99.99% availability requirement
- Risky for production customer data
- Difficult to add DR later

## Implementation Notes

### Terraform Module Pattern

**Standard region variable**:
```hcl
variable "region" {
  description = "GCP region for deployment (Primary: us-east4, Secondary: us-central1)"
  type        = string
  default     = "us-east4"
}
```

**Multi-region example** (AlloyDB):
```hcl
module "alloydb_primary" {
  source = "git::https://github.com/portco-connect/pcc-tf-library.git//modules/alloydb-multi-region"
  region = "us-east4"
  cluster_type = "PRIMARY"
}

module "alloydb_secondary" {
  source = "git::https://github.com/portco-connect/pcc-tf-library.git//modules/alloydb-multi-region"
  region = "us-central1"
  cluster_type = "SECONDARY"
}
```

### Organization Policy

**Resource location constraint**:
```yaml
constraint: constraints/gcp.resourceLocations
listPolicy:
  allowedValues:
    - in:us-east4-locations
    - in:us-central1-locations
  deniedValues: []
```

**Applied to**: All organization folders (devtest, dev, staging, prod)

### Cost Monitoring

**Regional budget alerts**:
- us-east4: $4,000/month baseline (all environments)
- us-central1: $500/month baseline (DR/secondary only)
- Cross-region egress: Alert at $200/month

## References

- [GCP Regions and Zones](https://cloud.google.com/compute/docs/regions-zones)
- [GCP Region Picker](https://cloud.withgoogle.com/region-picker/)
- [AlloyDB Multi-Region Documentation](https://cloud.google.com/alloydb/docs/multi-region-overview)
- [ADR-003: AlloyDB HA Strategy](./003-alloydb-ha-strategy.md)
- [ADR-007: Four Environment Architecture](./007-four-environment-architecture.md)
- [Security IAM Blueprint](../security-iam-blueprint.md)
- [Apigee X Networking Specification](../apigee-x-networking-specification.md)

## Approval

- [x] Lead Architect Approval
- [ ] FinOps Lead Review (budget impact)
- [ ] DevOps Lead Approval

---

*This ADR establishes the regional strategy for all PCC infrastructure. Future ADRs should reference ADR-009 instead of repeating regional decisions.*
