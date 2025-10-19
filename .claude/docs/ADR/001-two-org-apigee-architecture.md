# ADR 001: Two-Organization Apigee X Architecture

**Date**: 2025-10-17
**Status**: Accepted (pending dev partner approval)
**Decision Makers**: Lead Architect, Dev Partner (pending)
**Consulted**: Gemini 2.5 Pro, OpenAI Codex (gpt-5-codex)

## Context

PortCo Connect (PCC) is deploying Apigee X as an API gateway for 7 microservices. As a small organization building a portfolio risk management platform, we need to balance several competing concerns:

### Business Context
- Small team with limited operational resources
- Need cost-effective infrastructure while maintaining production-grade reliability
- Require safe testing of infrastructure-level changes before production deployment
- Must support customer integration testing in realistic pre-prod environment

### Technical Requirements
1. **Isolation for org-level changes**: Ability to test Apigee organization-level infrastructure changes (networking, IAM, instance scaling) without risk to production
2. **Customer integration path**: Clear workflow for customer integration testing before production deployment
3. **Deployment efficiency**: Streamlined promotion path from development to production
4. **Cost management**: Minimize redundant infrastructure while maintaining safety

### Architecture Options Evaluated

**Option 1: Single Apigee Organization with 4 Environments**
- Structure: One org containing devtest, dev, staging, prod environments
- Cost: Lowest (1 Apigee org, minimal networking overhead)
- Isolation: **CRITICAL WEAKNESS** - org-level changes affect all environments simultaneously

**Option 2: Two Apigee Organizations**
- Structure: Non-prod org (devtest + dev), Prod org (staging + prod)
- Cost: Moderate (2 Apigee orgs in 2 of 4 GCP projects)
- Isolation: Strong - org-level changes tested in non-prod before touching customer-facing environments

**Option 3: Four Separate Apigee Organizations**
- Structure: One org per environment, each in its own GCP project
- Cost: Highest (4 Apigee orgs across 4 GCP projects, maximum networking/operational overhead)
- Isolation: Maximum - each environment completely isolated

### AI Consultation Results

To inform this decision, we consulted two leading AI systems on Apigee testing strategies:

#### Gemini 2.5 Pro Analysis
- **Key Finding**: Single-org architecture has inherent risk that organization-level changes can affect all environments
- **Testing Strategy**: Requires "blast radius reduction" and "progressive validation" with 24-48 hour soak testing in canary environment
- **Recommendation**: "For most large enterprises, a multi-org strategy (at minimum, separating non-prod and prod) is the recommended best practice."
- **Rationale**: "Benefits of isolation, security, and compliance outweigh the additional cost and operational overhead"

#### OpenAI Codex (gpt-5-codex) Analysis
- **Key Finding**: "Hard isolation keeps org-level misconfig confined; Terraform can apply to lower orgs without prod impact"
- **Multi-org Benefits**: "Allows per-environment quotas, billing, and IAM boundaries—useful for regulated teams"
- **Testing Strategy**: Promoted pipeline with OPA policy checks, runtime health checks, synthetic transactions
- **Trade-offs**: "4x org administration, higher cost for duplicate Apigee instances and networking"

#### Consensus Recommendation
Both AI systems agreed: **Minimum 2-org architecture** (non-prod + prod) provides essential isolation for safe org-level infrastructure testing while balancing cost concerns.

## Decision

We will implement a **two-organization Apigee X architecture** with the following structure:

### GCP Project Structure

**Existing Foundation Infrastructure** (deployed in `pcc-foundation-infra` repository):
- 15 GCP projects across folder hierarchy (220 resources, deployed 2025-10-03)
- `pcc-fldr-si` (Shared Infrastructure): logging-monitoring, devops (nonprod/prod), systems (nonprod/prod), network (nonprod/prod)
- `pcc-fldr-app` (Application): app-devtest, app-dev, app-staging, app-prod (GKE clusters)
- `pcc-fldr-data` (Data): data-devtest, data-dev, data-staging, data-prod (AlloyDB, BigQuery)

**New Dedicated Apigee Projects** (to be added to `pcc-foundation-infra`):
- `pcc-prj-apigee-nonprod` (under `pcc-fldr-si`) - **Hosts nonprod Apigee organization**
- `pcc-prj-apigee-prod` (under `pcc-fldr-si`) - **Hosts prod Apigee organization**

**Rationale for Dedicated Projects** (Gemini 2.5 Pro + OpenAI Codex consensus):
- Apigee is platform-level shared infrastructure serving all applications
- Clean separation of concerns: runtime API gateway vs. CI/CD tooling vs. application workloads
- Clear IAM boundaries: platform team manages Apigee projects, app teams consume APIs
- Isolated quotas: Apigee resource needs don't compete with Cloud Build or GKE
- Cost transparency: Dedicated project billing shows exact Apigee spend
- Network clarity: Hub-and-spoke pattern with Apigee as hub, app projects as spokes

### Non-Prod Apigee Organization (hosted in `pcc-prj-apigee-nonprod` GCP project)
**Environments**: devtest, dev
**Purpose**: Internal development and org-level infrastructure testing
**Characteristics**:
- Safe environment for infrastructure experiments
- Breaking changes acceptable in devtest
- Stable development testing in dev
- No customer access

### Prod Apigee Organization (hosted in `pcc-prj-apigee-prod` GCP project)
**Environments**: staging, prod
**Purpose**: Customer-facing, production-grade infrastructure
**Characteristics**:
- Customer integration testing in staging
- Live customer traffic in prod
- Seamless staging → prod promotion (same org)
- Production SLAs and support

### Environment Split Rationale

**Why staging + prod together?**
1. **Customer integration testing**: Customers test in staging environment, which is identical to prod (same org, networking, security posture)
2. **Seamless promotion**: Staging → prod is simple environment promotion within same org (no cross-org artifact export/import)
3. **Operational simplicity**: Single set of production infrastructure to manage (networking, IAM, monitoring)
4. **Realistic testing**: Staging environment is production-identical, validating exact deployment that will reach prod

**Why devtest + dev separate?**
1. **Org-level change isolation**: Infrastructure experiments (networking, IAM, scaling) tested in non-prod org first
2. **Breaking change safety**: Devtest environment can have breaking changes without any risk to customer-facing environments
3. **Development velocity**: Internal development team can iterate rapidly without production concerns

## Rationale

### Advantages

1. **Safe Org-Level Testing**
   - Terraform infrastructure changes tested in non-prod org before touching production
   - Networking, VPC peering, service networking changes validated without customer impact
   - IAM and security policy changes can be thoroughly tested
   - Instance scaling and regional deployment tested safely

2. **Clear Customer Integration Path**
   - Customers test integrations in staging (production-identical environment)
   - No confusion about which environment to use for pre-production testing
   - Staging environment guarantees production parity (same org)

3. **Operational Efficiency**
   - Staging → prod promotion is simple (same org, just environment promotion)
   - No complex cross-org artifact export/import for production deployments
   - Single production infrastructure management (monitoring, alerting, networking)

4. **Cost-Effective Isolation**
   - 2 Apigee orgs vs 4 orgs (50% cost reduction vs Option 3)
   - Essential isolation without redundant infrastructure
   - Appropriate for small organization budget

5. **Development Velocity**
   - Internal team can iterate rapidly in devtest without production concerns
   - Dev environment provides stable pre-integration testing
   - No customer visibility into development/experimentation work

### Trade-offs Accepted

1. **Cross-Org Promotion Complexity**
   - Promoting from dev → staging requires cross-org artifact promotion
   - Must export/import API proxies, shared flows between orgs
   - Requires CI/CD pipeline support for cross-org promotion

2. **Dual Infrastructure Management**
   - Must manage 2 Apigee orgs with separate networking, IAM, monitoring
   - Higher operational overhead than single-org (but acceptable for small team)

3. **No Customer Testing in Non-Prod Org**
   - Customers cannot test in devtest/dev environments
   - However, this is the correct trade-off - customers should test in staging (production-identical)

## Consequences

### Positive

- **Infrastructure safety**: Org-level changes tested safely before production
- **Customer confidence**: Integration testing in production-identical staging environment
- **Cost-effective**: Balances isolation needs with budget constraints
- **Clear boundaries**: Development vs customer-facing environments clearly separated

### Negative

- **Promotion complexity**: Cross-org promotion more complex than single-org
- **Operational overhead**: Must manage 2 complete Apigee infrastructures
- **Artifact duplication**: API proxies, shared flows must be promoted across org boundary

### Mitigation Strategies

1. **Automated Cross-Org Promotion**
   - CI/CD pipeline handles export/import automatically
   - Terraform automation for infrastructure promotion
   - Clear promotion gates between dev and staging

2. **Shared Terraform Modules**
   - Reusable modules for both orgs (DRY principle)
   - Configuration-driven differences (tfvars per org)
   - Consistent infrastructure patterns

3. **Centralized Monitoring**
   - Single observability stack for both orgs
   - Unified alerting and incident response
   - Cross-org metrics and dashboards

## Alternatives Considered

### Alternative 1: Single Org with 4 Environments
**Rejected because:**
- No isolation for org-level infrastructure testing
- Gemini: "Org-level changes in devtest can potentially impact prod"
- Codex: "Use a promoted pipeline... but org-level diffs surface before production" (still risky)
- Testing strategy requires "accepting inherent risk" (unacceptable for production system)

### Alternative 2: Four Separate Organizations
**Rejected because:**
- Excessive cost for small organization (4x Apigee instances, networking overhead)
- Operational complexity managing 4 complete infrastructures
- Codex: "4x org administration... higher cost for duplicate Apigee instances"
- Over-engineering for current scale and team size

### Alternative 3: Three Organizations (devtest, dev, staging+prod)
**Considered but rejected because:**
- Marginal isolation benefit over 2-org approach
- Significant cost increase (3x vs 2x Apigee orgs)
- Adds complexity without clear value
- Dev environment sufficient for pre-staging validation

## Implementation Notes

### Promotion Path
```
devtest → dev (within non-prod org)
         ↓ (cross-org promotion)
    staging → prod (within prod org)
```

### Terraform Structure

**Phase 0: Foundation Updates** (add Apigee projects to `pcc-foundation-infra`):
```
pcc-foundation-infra/terraform/main.tf
├── Add pcc-prj-apigee-nonprod to locals.projects
│   └── Folder: pcc-fldr-si
│   └── APIs: apigee.googleapis.com, servicenetworking.googleapis.com, etc.
└── Add pcc-prj-apigee-prod to locals.projects
    └── Folder: pcc-fldr-si
    └── APIs: apigee.googleapis.com, servicenetworking.googleapis.com, etc.
```

**Phase 1: Apigee Infrastructure** (new Apigee-specific terraform):
```
infra/pcc-apigee-infra/terraform/
├── nonprod/
│   ├── devtest.tfvars (devtest env in pcc-prj-apigee-nonprod)
│   ├── dev.tfvars (dev env in pcc-prj-apigee-nonprod)
│   └── main.tf (Apigee org, instances, environment groups)
└── prod/
    ├── staging.tfvars (staging env in pcc-prj-apigee-prod)
    ├── prod.tfvars (prod env in pcc-prj-apigee-prod)
    └── main.tf (Apigee org, instances, environment groups)
```

**Note:** 15 GCP projects already exist in `pcc-foundation-infra` for GKE, databases, networking, devops, and systems infrastructure. 2 new dedicated Apigee projects will be added to this foundation following GCP best practices for platform-level shared infrastructure.

### Testing Strategy for Org-Level Changes
1. Apply Terraform change to non-prod org
2. Validate in devtest environment (automated tests + manual validation)
3. Soak test in dev environment (24-48 hours)
4. Apply same change to prod org during maintenance window
5. Validate in staging environment before routing customer traffic
6. Progressive rollout to prod environment

### Rollback Strategy
- Maintain last-known-good Terraform state for both orgs
- Documented rollback procedures per change type
- Expected propagation delays documented (e.g., instance resize: 30-45 min)
- Break-glass access procedures for emergency changes

## References

- [Phase 1 Foundation Infrastructure Plan](./../plans/phase-1-foundation-infrastructure.md)
- [Apigee X Networking Specification](./../docs/apigee-x-networking-specification.md)
- [Apigee X Traffic Routing Specification](./../docs/apigee-x-traffic-routing-specification.md)
- Gemini 2.5 Pro consultation: 2025-10-17
- OpenAI Codex (gpt-5-codex) consultation: 2025-10-17

## Approval

- [ ] Dev Partner Approval
- [x] Lead Architect Approval

---

*This ADR documents a critical architectural decision for the PCC platform. All subsequent Phase 1 planning and implementation work assumes this 2-org architecture.*
