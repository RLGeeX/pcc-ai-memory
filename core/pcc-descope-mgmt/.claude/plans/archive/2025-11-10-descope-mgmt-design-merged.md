# pcc-descope-mgmt Design Document

**Version**: 1.1 (Merged)
**Date**: 2025-11-10
**Status**: Approved
**Authors**: Claude (with business-analyst and python-pro consultation)

**Changelog**:
- v1.1: Merged design revisions from agent review process (PyrateLimiter, 10-week timeline, NFS distribution, backup format, SSO scope)
- v1.0: Initial comprehensive design

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Project Overview](#project-overview)
3. [Business Requirements](#business-requirements)
4. [Technical Architecture](#technical-architecture)
5. [Detailed Design](#detailed-design)
6. [Implementation Plan](#implementation-plan)
7. [Testing Strategy](#testing-strategy)
8. [Operational Considerations](#operational-considerations)
9. [Appendices](#appendices)

---

## Executive Summary

`pcc-descope-mgmt` is a Python CLI tool that transforms Descope authentication infrastructure management from error-prone manual operations into reliable, auditable, code-managed workflows. The tool enables developers to declaratively manage Descope projects, tenants, and authentication flows through YAML configuration files with full idempotency, safety mechanisms, and observability.

**Key Value Propositions**:
- **Time Savings**: Reduce environment provisioning from 2-4 hours to <5 minutes
- **Risk Reduction**: 80% fewer manual operations with built-in safety nets
- **Compliance**: 100% audit trails for all infrastructure changes
- **Developer Experience**: Intelligent defaults, rich feedback, and self-service capabilities

**Target Users**: DevOps engineers, backend developers, security engineers, platform engineers

**Core Capabilities**:
1. Create and manage Descope projects programmatically
2. Create/update/delete tenants with configuration-as-code
3. Deploy authentication flow templates (login, MFA, sign-up)
4. Detect and remediate configuration drift
5. Backup/restore Descope configurations
6. Multi-environment support (dev, staging, prod)

**Distribution**: Internal tool deployed via NFS mount at `/home/jfogarty/pcc/core/pcc-descope-mgmt` with editable pip install for team of 2 users.

---

## Project Overview

### Background

The PortCo Connect (PCC) platform requires managing authentication infrastructure across multiple portfolio companies, each with their own tenants, SSO configurations, and authentication flows. Manual management through the Descope console is:
- Time-consuming (hours per environment)
- Error-prone (typos, inconsistent settings)
- Not auditable (no version control)
- Difficult to replicate across environments

### Goals

**Primary Goal**: Provide a CLI tool that makes Descope infrastructure management as easy and safe as managing infrastructure-as-code with Terraform.

**Secondary Goals**:
- Enable rapid environment provisioning (<5 minutes)
- Reduce configuration errors by 80%+
- Provide 100% audit trail for compliance
- Support multi-environment workflows (dev → staging → prod)
- Enable configuration drift detection and remediation

### Non-Goals (Out of Scope)

**v1.0 Scope Exclusions**:
- Real-time user management (use Descope SDK directly)
- Custom authentication flow builder UI (start with templates only)
- Monitoring/alerting of Descope service health
- Migration from other auth providers (focus on Descope-native workflows)
- **SSO Configuration Management**: Manual one-time setup required in Descope Console for primary tenant (`pcconnect-main` with Google Workspace SSO for `pcconnect.ai` domain). Tool manages tenants and flows, but SSO must be configured manually. See [SSO Scope Clarification](#sso-scope-clarification) for details.

### Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Environment provisioning time | <5 minutes | Time from config creation to working auth |
| Error rate | <2% | Failed operations / total operations |
| Test coverage | >85% | pytest-cov measurement |
| Command discoverability | 90% | User survey: "Found command without docs" |
| Self-service error resolution | 85% | Errors resolved without escalation |

### Distribution Strategy

**Internal NFS Mount Only** (No PyPI or Git Distribution):

- **Installation Location**: `/home/jfogarty/pcc/core/pcc-descope-mgmt`
- **Team Size**: 2 users
- **Installation Method**: Editable pip install (`pip install -e .`)
- **Benefits**:
  - ✅ Single source of truth (shared location)
  - ✅ Automatic updates (everyone uses same install)
  - ✅ No version conflicts
  - ✅ No distribution complexity

**Setup Instructions**:

```bash
# Navigate to shared location
cd /home/jfogarty/pcc/core/pcc-descope-mgmt

# Install in editable mode
pip install -e .

# Verify installation
descope-mgmt --version
descope-mgmt --help
```

**Updates**: Changes are immediately available via editable install. Run `git pull` for version control updates.

---

## Business Requirements

*This section synthesizes findings from the business-analyst agent.*

### Use Cases

#### UC-1: New Environment Provisioning

**Actor**: DevOps Engineer
**Goal**: Provision complete authentication infrastructure for a new environment in <5 minutes

**Preconditions**:
- Descope account exists
- Management API key created
- YAML config file prepared

**Main Flow**:
1. Engineer creates `descope-dev.yaml` with project and tenant definitions
2. Engineer runs `descope-mgmt tenant sync --config descope-dev.yaml --dry-run`
3. System displays diff showing resources to be created
4. Engineer confirms changes
5. System creates project and tenants with progress indicators
6. System displays operation summary with created resource IDs

**Success Criteria**:
- All resources created successfully
- Operation completes in <5 minutes
- Audit log entry created
- Backup of pre-operation state saved

**Error Scenarios**:
- Invalid API key → Clear error with link to Descope console
- Rate limit exceeded → Automatic retry with exponential backoff (using PyrateLimiter)
- Network failure mid-operation → Idempotent retry from checkpoint

---

#### UC-2: Multi-Tenant Application Setup

**Actor**: Backend Developer
**Goal**: Create tenant hierarchy for portfolio companies with specific SSO and domain configurations

**Preconditions**:
- Descope project exists
- Tenant configuration YAML prepared
- Domain ownership verified (manual step)
- **SSO configured manually** in Descope Console for primary tenant

**Main Flow**:
1. Developer defines 10 tenants in `tenants.yaml` with domains and custom attributes
2. Developer runs `descope-mgmt tenant sync --config tenants.yaml`
3. System validates configuration (no duplicate domains, valid tenant IDs)
4. System shows diff: 10 tenants to create
5. Developer confirms
6. System creates tenants with batch operations (respecting rate limits via PyrateLimiter)
7. System displays summary: 10 created, 0 failed

**Success Criteria**:
- All tenants created with correct configurations
- Domains properly mapped
- Operation summary shows all successes
- Configuration stored in version control

**Error Scenarios**:
- Duplicate tenant ID → Validation error before API call
- Domain already claimed → Clear error indicating which tenant/domain conflicts
- Partial failure (7/10 succeed) → Summary shows 7 created, 3 failed with specific errors; successful tenants not rolled back; developer can fix config and re-run (idempotent)

---

#### UC-3: Authentication Flow Synchronization

**Actor**: Security Engineer
**Goal**: Deploy updated MFA authentication flow across all environments

**Preconditions**:
- Flow template tested in dev environment
- Config updated with new flow settings
- Change approved via PR review

**Main Flow**:
1. Engineer updates `flows.yaml` to enable MFA with SMS + TOTP methods
2. Engineer runs `descope-mgmt flow deploy --config flows.yaml --environment staging --dry-run`
3. System shows flow configuration changes
4. Engineer confirms staging deployment
5. System deploys flow to staging with backup of old flow
6. Engineer repeats for production after validation
7. System provides rollback command if issues detected

**Success Criteria**:
- Flow deployed successfully to all environments
- Backups created before each deployment (using structured Pydantic backup format)
- Audit trail shows who deployed what and when
- Rollback capability available

**Error Scenarios**:
- Flow template not found → Error with list of available templates
- Flow configuration invalid → Validation error with schema details
- API failure during deployment → Automatic rollback from backup

---

#### UC-4: Configuration Drift Detection

**Actor**: Platform Engineer
**Goal**: Identify and remediate differences between code and live Descope state

**Preconditions**:
- YAML config represents desired state
- Manual changes may have been made in Descope console
- Regular drift detection scheduled (e.g., weekly)

**Main Flow**:
1. Engineer runs `descope-mgmt tenant sync --config tenants.yaml --dry-run`
2. System queries Descope API for current state
3. System compares current vs. desired state
4. System displays drift report:
   - 2 tenants have domain changes
   - 1 tenant missing from Descope
   - 1 tenant in Descope not in config (orphaned)
5. Engineer reviews changes and decides:
   - Apply config to fix drift: `descope-mgmt tenant sync --config tenants.yaml`
   - Update config to match reality: manual YAML edits
6. System applies changes with confirmation prompts
7. Drift resolved; audit log records remediation

**Success Criteria**:
- All drift identified accurately
- Engineer has clear options to resolve (apply config or update config)
- Audit trail shows drift detection and resolution
- No unintended changes applied

**Error Scenarios**:
- Cannot determine drift cause → System shows both states side-by-side for manual review
- Conflicting changes (manual + config changes) → System requires explicit conflict resolution
- Orphaned resources → System prompts whether to delete or import into config

---

### Business Rules

#### Resource Identification Constraints

1. **Tenant IDs**: Must be lowercase alphanumeric with hyphens, 3-50 characters, globally unique within project
2. **Project Names**: 1-100 characters, no special characters except spaces and hyphens
3. **Domain Validation**: Must be valid DNS format (RFC 1035), verified ownership before assignment
4. **Tenant Hierarchy**: Max 3 levels of nesting (parent → child → grandchild)

#### Hierarchy Rules

1. **Parent-Child Relationships**: Child tenants inherit SSO configuration from parent unless explicitly overridden
2. **Nesting Depth**: Maximum 3 levels to prevent complexity
3. **Deletion Order**: Must delete children before parent (enforced by system)

#### Flow Dependencies

1. **Connector Requirements**: OAuth flows require configured OAuth connectors
2. **Fallback Methods**: If primary MFA method unavailable, fallback method required
3. **Template Versioning**: Flow templates versioned; system tracks which version deployed

#### Environment Isolation

1. **Production Safeguards**: Production changes require explicit `--environment prod` flag + confirmation
2. **Cross-Environment Restrictions**: Cannot copy staging tenant IDs to production (prevents ID collision)

#### Change Management

1. **Confirmation Requirements**: Destructive operations (delete, replace) require confirmation unless `--yes` flag
2. **Audit Logging**: All operations logged with timestamp, user, operation, resources affected
3. **Backup Policy**: Automatic backup before any modify/delete operation (structured JSON format with Pydantic schemas)

#### Rate Limiting Compliance

1. **Batch Operations**: Respect Descope rate limits (200 req/60s for tenants) using PyrateLimiter library with InMemoryBucket
2. **Retry Strategy**: Exponential backoff on 429 responses (1s, 2s, 4s, 8s, max 5 retries)
3. **Concurrent Limits**: Adaptive worker pool sizing based on rate limits (calculated using `calculate_optimal_workers()`)
4. **Rate Limiting at Submission**: RateLimitedExecutor applies rate limiting BEFORE submitting tasks to thread pool (prevents queue buildup)

---

### Edge Cases & Error Scenarios

#### 1. Partial Failures

**Scenario**: Creating 10 tenants, #7 fails due to domain conflict

**System Behavior**:
- Complete operations 1-6 successfully
- Halt on operation 7, display error
- Ask user: Continue with remaining (8-10)? Skip? Abort?
- Provide recovery command to retry just #7 after fixing config
- Log all outcomes (6 success, 1 failed, 3 skipped/pending)

**Design Decision**: Do NOT rollback successful operations (idempotency allows safe re-run)

---

#### 2. Configuration Drift

**Scenario**: Tenant "acme-corp" has domain "acme.com" in config, but "acme.com" and "acme.net" in Descope (manual addition)

**System Behavior**:
- Detect drift: `descope-mgmt tenant sync --dry-run`
- Display diff:
  ```
  Tenant: acme-corp
    ~ domains: ["acme.com"] → ["acme.com", "acme.net"]
  ```
- Prompt user:
  - **Option A**: Apply config (remove "acme.net") - Use `--apply`
  - **Option B**: Update config to match reality - Manual YAML edit
  - **Option C**: Ignore (accept drift) - No action
- Log drift detection and resolution choice

**Design Decision**: Never auto-resolve drift; always require explicit user choice

---

#### 3. Network Failures Mid-Operation

**Scenario**: Creating tenant, network drops after API call sent but before response received

**System Behavior**:
- Log operation start with request details
- On network timeout, attempt retry (idempotent operation checks if tenant exists)
- If tenant exists on retry, verify configuration matches desired state
- If matches, mark as success (already created)
- If differs, treat as drift and show diff
- If tenant doesn't exist, retry creation

**Design Decision**: All operations must be idempotent; use checkpoints for multi-step operations

---

#### 4. Conflicting Configurations

**Scenario**: Two YAML files define tenant "acme-corp" with different domains

**System Behavior**:
- During config loading, detect duplicate tenant ID
- Error immediately: "Tenant 'acme-corp' defined in multiple configs: dev.yaml, prod.yaml"
- Suggest: Use environment-specific tenant IDs or merge configs

**Design Decision**: Fail fast on ambiguity; never guess which config takes precedence

---

#### 5. API Rate Limiting

**Scenario**: Batch creating 50 tenants exceeds 200 req/60s limit

**System Behavior**:
- Track API call rate using PyrateLimiter's InMemoryBucket (thread-safe sliding window)
- Apply rate limiting at task submission time (RateLimitedExecutor)
- If rate limit would be exceeded, block submission until window resets
- If 429 received (defensive), pause and display: "Rate limited, retrying in 5s..."
- Use exponential backoff via retry decorator: 1s, 2s, 4s, 8s
- Show progress indicator: "Created 30/50 tenants (rate limited, pausing...)"
- Resume after backoff period

**Design Decision**: Proactive rate limiting at submission + reactive backoff; never fail due to rate limits

**Implementation**: See [Rate Limiter Implementation](#rate-limiter-implementation) section for complete PyrateLimiter integration details.

---

#### 6. Flow Version Conflicts

**Scenario**: Updating flow from v1 to v2 with breaking changes (removed authentication method)

**System Behavior**:
- Detect version change during diff
- Display warning: "Flow 'mfa-login' version change: v1 → v2 (breaking changes possible)"
- Require explicit flag: `--allow-breaking-changes`
- Create backup of v1 flow automatically (structured Pydantic backup)
- Provide rollback command in output: `descope-mgmt flow rollback --backup <backup-id>`
- Log version change in audit trail

**Design Decision**: Treat flow updates as potentially breaking; require explicit acknowledgment

---

### User Experience Considerations

#### What Makes This Tool Delightful

1. **Intelligent Defaults**:
   - Auto-detect environment from Git branch name (feature/dev → dev environment)
   - Default config file discovery (./descope.yaml, ./.descope/config.yaml, ~/.descope/config.yaml)
   - Sensible defaults for all optional config fields

2. **Progressive Disclosure**:
   - Simple commands for common tasks: `descope-mgmt tenant sync`
   - Advanced flags for power users: `--dry-run`, `--backup-dir`, `--log-level debug`
   - Help text shows examples for each command

3. **Rich Feedback**:
   - Progress indicators for batch operations with estimated time remaining
   - Color-coded diffs (green=add, yellow=modify, red=delete)
   - Operation summaries with counts: "✓ 10 created, ⚠ 2 updated, ✗ 0 failed"

4. **Safety Nets**:
   - Dry-run mode shows changes without applying
   - Confirmation prompts with impact assessment: "This will delete 5 tenants. Continue? [y/N]"
   - Automatic backups before destructive operations (stored in `~/.descope-mgmt/backups/` by default)
   - Rollback commands provided after changes

5. **Contextual Help**:
   - Command suggestions: "Did you mean 'descope-mgmt tenant list'?"
   - Inline examples in help text
   - Troubleshooting tips in error messages: "Check your management key in Descope Console → Company → Management Keys"

---

#### What Makes This Tool Frustrating (To Avoid)

1. **Silent Failures**:
   - ❌ Operation fails with no output
   - ✅ Explicit error message with fix suggestion

2. **Hidden State**:
   - ❌ Changes applied without preview
   - ✅ Always show diff before applying (unless `--yes` flag)

3. **Ambiguous Prompts**:
   - ❌ "Continue? [y/n]" (continue what?)
   - ✅ "Delete 5 tenants permanently? [y/N]"

4. **Blocking Operations**:
   - ❌ Long operations with no feedback
   - ✅ Progress indicators with time estimates

5. **Configuration Hell**:
   - ❌ Multiple sources of truth, unclear precedence
   - ✅ Single config file, explicit environment overrides

---

