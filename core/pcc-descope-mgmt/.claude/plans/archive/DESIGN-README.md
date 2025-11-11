# pcc-descope-mgmt Design Documentation Guide

**Last Updated**: 2025-11-10 16:45 EST
**Status**: Design Complete and Approved

---

## Quick Start

**For Implementation**: Read this document first, then use the detailed documents as reference.

---

## Design Documents Overview

We have two complementary design documents that together form the complete design:

### 1. Main Design Document (PRIMARY REFERENCE)
**File**: `.claude/plans/2025-11-10-descope-mgmt-design.md`
**Size**: 11,500+ lines
**Purpose**: Comprehensive design with full architecture, examples, and details

**Use this for**:
- Understanding the overall architecture (3-layer: CLI → Domain → API)
- CLI command reference with examples
- Configuration schema and YAML examples
- State management and diff calculation design
- Detailed design patterns and code organization
- Full testing strategy fundamentals

### 2. Design Revisions (UPDATES & FIXES)
**File**: `.claude/plans/2025-11-10-design-revisions.md`
**Size**: 1,900+ lines
**Purpose**: Critical updates from agent review process

**Use this for**:
- Specific implementation decisions (rate limiter, backup format)
- Updated code examples (PyrateLimiter, RateLimitedExecutor, Pydantic schemas)
- Performance testing strategy
- Integration testing approach
- Updated timeline (10 weeks instead of 8)
- Distribution strategy (NFS mount only)

---

## Key Changes in Revisions (MUST READ)

These revisions supersede the original design where they conflict:

### 1. Rate Limiting Implementation
**Location**: Revisions Section 1
**Change**: Use PyrateLimiter library (not custom implementation)
```python
from pyrate_limiter import Limiter, InMemoryBucket, Rate, Duration

# Thread-safe rate limiter
limiter = Limiter(InMemoryBucket([Rate(200, Duration.SECOND * 60)]))
```

### 2. RateLimitedExecutor Fix (CRITICAL)
**Location**: Revisions Section 2
**Change**: Rate limiting MUST happen at submission time (not in worker threads)
```python
def submit(self, fn, *args, weight=1, **kwargs):
    # CRITICAL: Acquire BEFORE submitting to executor
    self._rate_limiter.acquire(weight=weight)
    future = self._executor.submit(fn, *args, **kwargs)
    return future
```

### 3. Timeline Update
**Location**: Revisions Section 3
**Change**: 10 weeks (not 8)
- Weeks 1-2: Foundation
- Weeks 3-4: Safety & Observability
- Weeks 5-6: Flow Management
- Weeks 7-8: Performance & Polish
- **Weeks 9-10: Documentation & Internal Deployment** (NEW)

### 4. Distribution Strategy
**Location**: Revisions Section 4
**Change**: NFS mount only (no PyPI or git distribution)
- Internal tool for 2-person team
- Shared location: `/home/jfogarty/pcc/core/pcc-descope-mgmt`
- Editable install: `pip install -e .`
- No packaging complexity

### 5. Performance Testing Strategy
**Location**: Revisions Section 5
**Change**: Comprehensive performance test suite added
- Batch operation benchmarks (100 tenants in <45s)
- Rate limiter overhead tests (<10ms for 100 acquisitions)
- Memory usage tests (<50MB for 1000 configs)
- Concurrent API call validation
- Config loading performance (<1s for 500 tenants)

### 6. Backup File Format
**Location**: Revisions Section 6
**Change**: Pydantic schema with structured metadata
```python
class Backup(BaseModel):
    metadata: BackupMetadata  # version, timestamp, operation, user, git_commit
    tenants: list[TenantBackupData]
    flows: list[FlowBackupData]
    project_settings: Optional[dict[str, Any]]
```

### 7. Backup Storage Strategy
**Location**: Revisions Section 7
**Change**: Specified storage location and retention
- Default: `~/.descope-mgmt/backups/`
- 30-day retention policy
- Optional git integration for team access
- Optional cloud sync (S3, GCS)

### 8. Integration Testing
**Location**: Revisions Section 8
**Change**: Use Descope test users with real API
- Local testing with pre-commit hooks
- Manual integration tests with test users
- No CI/CD pipelines
- Environment variables: `DESCOPE_TEST_PROJECT_ID`, `DESCOPE_TEST_MANAGEMENT_KEY`

### 9. SSO Scope Clarification
**Location**: Revisions Section 9
**Change**: SSO configuration is OUT OF SCOPE for v1.0
- Manual one-time setup in Descope Console
- Tool manages tenants after SSO setup
- Future v2.0 feature: SSO template replication

### 10. Additional Improvements
**Location**: Revisions Section 10
**Changes**:
- Type stubs for Descope SDK (remove mypy ignore)
- Streaming config loading (multi-document YAML)
- Import cycle prevention architecture (types/ package)

---

## How to Use These Documents

### For Understanding Architecture
1. Read Main Design → Technical Architecture section
2. Read Main Design → Detailed Design section
3. Note: Use PyrateLimiter (from Revisions) not custom implementation

### For Implementation Planning
1. Read Main Design → Implementation Plan (but use 10-week timeline from Revisions)
2. Read Revisions → Timeline Revision (Section 3) for correct phase breakdown
3. Read Revisions → Distribution Strategy (Section 4) for NFS mount approach

### For Testing Strategy
1. Read Main Design → Testing Strategy (fundamentals)
2. Read Revisions → Performance Testing Strategy (Section 5)
3. Read Revisions → Integration Testing (Section 8)

### For Backup/Restore Design
1. Skip Main Design backup section
2. Read Revisions → Backup File Format (Section 6)
3. Read Revisions → Backup Storage Strategy (Section 7)

### For Rate Limiting
1. Skip Main Design rate limiting section
2. Read Revisions → Rate Limiter Implementation (Section 1)
3. Read Revisions → RateLimitedExecutor Fix (Section 2) - CRITICAL

---

## Quick Reference: Where to Find Things

| Topic | Primary Source | Page/Section |
|-------|---------------|--------------|
| Overall Architecture | Main Design | Technical Architecture |
| CLI Commands | Main Design | Detailed Design → CLI Interface |
| Configuration Schema | Main Design | Detailed Design → Configuration |
| State Management | Main Design | Technical Architecture → Domain Layer |
| **Rate Limiting** | **Revisions** | **Section 1-2** |
| **Timeline (10 weeks)** | **Revisions** | **Section 3** |
| **Distribution (NFS)** | **Revisions** | **Section 4** |
| **Performance Tests** | **Revisions** | **Section 5** |
| **Backup Format** | **Revisions** | **Section 6-7** |
| **Integration Tests** | **Revisions** | **Section 8** |
| **SSO Scope** | **Revisions** | **Section 9** |
| Pydantic Models | Main Design | Technical Architecture → Domain Layer |
| Error Handling | Main Design | Technical Architecture → Error Strategy |
| Deployment | Main Design | Operational Considerations |

---

## Design Approval Status

### First Review (Afternoon)
- Business Analyst: APPROVED (95% confidence)
- Python Pro: APPROVED (Grade A, 95% confidence)

### Second Review (16:31 EST)
- Business Analyst: APPROVED (95% confidence, Score: 96/100 - Excellent)
- Python Pro: APPROVED WITHOUT CONDITIONS (Grade A-, 92%, 95% confidence)

**All blocking and critical issues resolved.**

---

## Next Steps

1. ✅ Design complete and approved
2. ✅ Revisions integrated into documentation
3. → **Create implementation plan** using `/superpowers:write-plan`
4. → Execute with parallel agents

---

## Supporting Documents

- **Business Requirements**: `.claude/docs/business-requirements-analysis.md`
- **Python Patterns**: `.claude/docs/python-technical-analysis.md`
- **Handoff**: `.claude/handoffs/ClaudeCode-2025-11-10-Afternoon-v2.md`
- **Status**: `.claude/status/brief.md` and `.claude/status/current-progress.md`

---

**For Implementation**: Start with `/superpowers:write-plan` to create bite-sized tasks from these designs.
