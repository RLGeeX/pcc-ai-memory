# Design Validation Addendum

**Date**: 2025-11-12
**Status**: Validated
**Validated By**: Brainstorming session with user

## Overview

This document captures refinements and clarifications to the original `design.md` based on validation session. These decisions should be incorporated into the implementation.

---

## 1. Architecture & Layers Refinements

### Type Import Strategy: Hybrid Approach

**Decision**: Use ID references for cross-model relationships, reserve forward references for genuine nested structures.

**Implementation**:
```python
# ✅ Preferred: ID references
class TenantConfig(ResourceIdentifier):
    flow_ids: list[str] = []  # Reference by ID only

# ❌ Avoid unless necessary: Nested objects
class TenantConfig(ResourceIdentifier):
    flows: list['FlowConfig'] = []  # Only if genuinely needed
```

**Rationale**:
- Prevents circular import complexity
- Aligns with API patterns (APIs return IDs, not full objects)
- Easier to test (simpler mocks)
- Better IDE support (no string literals)

**Shared Base Model**:
```python
# src/descope_mgmt/types/shared.py
class ResourceIdentifier(BaseModel):
    """Shared identifier pattern for all Descope resources"""
    id: str
    name: str
    description: str | None = None
```

---

### Dependency Injection: Protocols for Core Only

**Decision**: Use Protocol only for external boundaries (DescopeClient, RateLimiter). Use concrete classes for internal services.

**What gets a Protocol**:
- ✅ `DescopeClientProtocol` (external API calls)
- ✅ `RateLimiterProtocol` (external concern)
- ❌ `TenantManager`, `ConfigLoader`, `BackupManager` (internal, use concrete classes)

**Rationale**:
- Reduces boilerplate for 2-person team
- Protocols only where testability matters most (external boundaries)
- Internal services tested directly (fast, no mocking)
- Clear signal: "Protocol = integration point"

**Example**:
```python
# src/descope_mgmt/types/protocols.py
class DescopeClientProtocol(Protocol):
    def create_tenant(self, config: TenantConfig) -> TenantResponse: ...
    def update_tenant(self, tenant_id: str, config: TenantConfig) -> TenantResponse: ...
    def delete_tenant(self, tenant_id: str) -> None: ...

class RateLimiterProtocol(Protocol):
    def acquire(self, weight: int = 1) -> None: ...

# src/descope_mgmt/domain/tenant_manager.py
class TenantManager:  # Concrete class, no protocol needed
    def __init__(self, client: DescopeClientProtocol):
        self.client = client
```

---

### Layer Boundary Enforcement: import-linter

**Decision**: Use `import-linter` package with pre-commit hooks for automated enforcement.

**Configuration** (add to `pyproject.toml`):
```toml
[tool.importlinter]
root_package = "descope_mgmt"

[[tool.importlinter.contracts]]
name = "Layer architecture enforcement"
type = "layers"
layers = [
    "cli",
    "domain",
    "api",
    "types",
]
ignore_imports = [
    "descope_mgmt.*.tests -> descope_mgmt.*",  # Tests can import anything
]

[[tool.importlinter.contracts]]
name = "Utils can't import business logic"
type = "forbidden"
source_modules = ["descope_mgmt.utils"]
forbidden_modules = [
    "descope_mgmt.domain",
    "descope_mgmt.api",
    "descope_mgmt.cli",
]
```

**Pre-commit hook** (add to `.pre-commit-config.yaml`):
```yaml
- repo: local
  hooks:
    - id: import-linter
      name: Check layer boundaries
      entry: lint-imports
      language: system
      pass_filenames: false
      always_run: true
```

**Dependencies**:
```bash
pip install import-linter
```

---

## 2. Rate Limiting Strategy Refinements

### Burst Handling: Not Needed

**Decision**: No burst capability required for v1.0.

**Rationale**:
- Small team, small customer base
- Maximum ~20 tenants expected
- 30-second sync time for 100 tenants is acceptable (won't happen in practice)
- YAGNI principle

**Future consideration**: If scale increases, add burst bucket option.

---

### Retry Logic Location: DescopeClient

**Decision**: Retry logic lives in `DescopeClient`, not in executor or domain layer.

**Implementation**:
```python
class DescopeClient:
    def create_tenant(self, config: TenantConfig) -> TenantResponse:
        for attempt in range(5):
            try:
                self._rate_limiter.acquire()  # Blocks if needed
                response = requests.post(self._base_url, json=config.dict())

                if response.status_code == 429:
                    sleep_time = 2 ** attempt  # 1s, 2s, 4s, 8s, 16s
                    logger.warning(f"Rate limit hit, retry in {sleep_time}s")
                    sleep(sleep_time)
                    continue

                response.raise_for_status()
                return TenantResponse(**response.json())

            except requests.RequestException as e:
                if attempt == 4:  # Last attempt
                    raise ApiError(f"Failed after 5 attempts: {e}")
                sleep(2 ** attempt)
```

**Rationale**:
- HTTP retries are HTTP concerns
- Keeps domain layer clean
- Centralized in one place (API client)

---

### Rate Limiter Scope: Single Limiter for v1.0

**Decision**: Single rate limiter (200 req/60s) for all Descope operations in v1.0.

**Rationale**:
- YAGNI: Start simple, add complexity when needed
- Tenant API is primary use case
- Can add per-resource limiters later if Descope has different limits per endpoint

**Future consideration**: If flow API has different rate limits, add `FlowRateLimiter` in v2.0.

---

## 3. Scope & Requirements Clarifications

### Environment Structure: 5 Separate Projects

**Decision**: Each environment (test, devtest, dev, staging, prod) has its own Descope project.

**Implications**:
- 5 separate project IDs
- 5 separate management API keys
- Complete isolation between environments
- No risk of cross-environment modifications

**Configuration structure**:
```yaml
# ~/.descope-mgmt/config.yaml
projects:
  test:
    project_id: "P2test..."
    management_key: "${DESCOPE_TEST_MANAGEMENT_KEY}"
  devtest:
    project_id: "P2devtest..."
    management_key: "${DESCOPE_DEVTEST_MANAGEMENT_KEY}"
  dev:
    project_id: "P2dev..."
    management_key: "${DESCOPE_DEV_MANAGEMENT_KEY}"
  staging:
    project_id: "P2staging..."
    management_key: "${DESCOPE_STAGING_MANAGEMENT_KEY}"
  prod:
    project_id: "P2prod..."
    management_key: "${DESCOPE_PROD_MANAGEMENT_KEY}"
```

---

### Flow Template Deployment: Design Deferred

**Decision**: Defer flow template design until Descope Flow API is explored.

**Action Required**: Before Week 5 (Flow Deployment phase), investigate:
1. Descope's flow API capabilities
2. Whether flows are:
   - Pre-built templates you activate
   - Custom JSON you export/import
   - Parameterized templates with variables
3. Rate limits for flow operations
4. Flow versioning/rollback support

**Placeholder design**: Assume export/import pattern similar to Terraform:
```bash
# Export flow from staging
descope-mgmt flow export --env staging --flow-id mfa-flow --output mfa-flow.json

# Deploy to production
descope-mgmt flow deploy --env prod --file mfa-flow.json
```

---

### Backup/Restore Scope: Comprehensive

**Decision**: Back up tenants, flows, and project settings.

**Backup structure**:
```
~/.descope-mgmt/backups/
  {project_id}/
    {timestamp}/
      tenants.json          # All tenant configs (Pydantic schemas)
      flows.json            # All flow definitions (if flow API supports)
      project_settings.json # Project-level config
      metadata.json         # Backup metadata (tool version, timestamp, user)
```

**Restore capabilities**:
```bash
# Full restore
descope-mgmt restore --project test --backup-id 2025-11-12T10:30:00

# Partial restore (tenants only)
descope-mgmt restore --project test --backup-id 2025-11-12T10:30:00 --resources tenants

# Dry-run mode
descope-mgmt restore --project test --backup-id 2025-11-12T10:30:00 --dry-run
```

**Retention policy**: 30 days (configurable via config.yaml)

**Pydantic schema example**:
```python
class BackupMetadata(BaseModel):
    tool_version: str
    timestamp: datetime
    project_id: str
    user: str
    resources: list[str]  # ["tenants", "flows", "project_settings"]

class TenantBackup(BaseModel):
    metadata: BackupMetadata
    tenants: list[TenantConfig]

class ProjectBackup(BaseModel):
    metadata: BackupMetadata
    tenants: list[TenantConfig]
    flows: list[FlowConfig]
    project_settings: ProjectSettings
```

---

## 4. Implementation Impact

### Week 1 Changes

**Add to dependencies** (`pyproject.toml`):
```toml
[project]
dependencies = [
    # ... existing
    "import-linter>=2.0",
]
```

**Types module structure**:
```
src/descope_mgmt/types/
  __init__.py
  protocols.py      # DescopeClientProtocol, RateLimiterProtocol
  shared.py         # ResourceIdentifier base
  tenant.py         # TenantConfig
  flow.py           # FlowConfig (uses ID references)
  project.py        # ProjectSettings
```

---

### Week 3 Changes

**Backup module** must support all three resource types:
```python
class BackupManager:
    def create_backup(
        self,
        project_id: str,
        resources: list[str] = ["tenants", "flows", "project_settings"]
    ) -> BackupMetadata:
        # Implementation
        pass
```

---

### Week 5 Changes (Flow Deployment)

**Prerequisite**: Complete Descope Flow API exploration before starting Week 5.

**Research tasks**:
1. Read Descope Flow API documentation
2. Test flow export/import via API
3. Determine flow versioning strategy
4. Identify flow-specific rate limits
5. Design flow template structure

---

## 5. Testing Impact

### Protocol Testing

Only 2 protocols need test doubles:

```python
# tests/fakes.py
class FakeDescopeClient:
    """Fake for DescopeClientProtocol"""
    def __init__(self):
        self.calls: list[dict] = []

    def create_tenant(self, config: TenantConfig) -> TenantResponse:
        self.calls.append({"method": "create_tenant", "config": config})
        return TenantResponse(id=config.id, status="created")

class FakeRateLimiter:
    """Fake for RateLimiterProtocol"""
    def __init__(self):
        self.acquire_count = 0

    def acquire(self, weight: int = 1) -> None:
        self.acquire_count += weight
```

Internal services tested directly:
```python
# tests/domain/test_tenant_manager.py
def test_sync_tenants():
    fake_client = FakeDescopeClient()
    manager = TenantManager(client=fake_client)  # Concrete class
    # Test directly, no additional mocking needed
```

---

## 6. Documentation Updates

### CLAUDE.md Updates

Add to "Critical References":
```markdown
- 🔧 **Design Addendum**: @.claude/plans/2025-11-12-design-validation-addendum.md
```

Add to "Code Style and Best Practices":
```markdown
- Use ID references for cross-model relationships (not nested objects)
- Protocols only for external boundaries (DescopeClient, RateLimiter)
- Run `lint-imports` before commits (enforced via pre-commit)
```

---

## Summary of Key Decisions

| Area | Decision | Rationale |
|------|----------|-----------|
| **Type imports** | Hybrid (ID refs + forward refs) | Prevents circular imports, cleaner design |
| **Dependency injection** | Protocols for core only | Reduces boilerplate for small team |
| **Layer enforcement** | import-linter + pre-commit | Automated, catches violations early |
| **Burst handling** | Not needed in v1.0 | Small scale, YAGNI |
| **Retry logic** | In DescopeClient | HTTP concern, keeps domain clean |
| **Rate limiters** | Single limiter for v1.0 | Start simple, expand if needed |
| **Environment structure** | 5 separate projects | Complete isolation |
| **Flow templates** | Design deferred | Requires API exploration |
| **Backup scope** | Tenants + flows + project settings | Comprehensive disaster recovery |

---

## Next Steps

1. ✅ Design validated and documented
2. ⏳ Ready for implementation setup
3. ⏳ Create git worktree (if needed)
4. ⏳ Generate micro-chunked implementation plan
5. ⏳ Begin Week 1, Chunk 1 execution

**Recommendation**: Proceed with implementation using validated design decisions.
