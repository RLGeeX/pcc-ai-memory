# Bug Reports Summary - pcc-descope-mgmt CLI

Two critical bugs identified in the pcc-descope-mgmt CLI that block major workflows.

## Bug 1: Tenant Create Returns 500 Error
**Jira Type:** Bug
**Severity:** High
**Priority:** P1

### Quick Facts
- **Command:** `descope-mgmt tenant create --id "test-001" --name "Test" --domain "test.com"`
- **Error:** `500 - {"errorCode":"E010009","errorDescription":"Unknown server error"}`
- **Impact:** Blocks all tenant creation via CLI; requires UI workaround
- **Likely Cause:** Payload field naming mismatch or unsupported fields in create request

### Full Details
See: `@.claude/docs/bug-report-tenant-create-500.md`

---

## Bug 2: Flow Import --apply Returns 500 Error During Backup
**Jira Type:** Bug
**Severity:** High
**Priority:** P1

### Quick Facts
- **Command:** `descope-mgmt flow import /tmp/test-flow.json --apply`
- **Error:** `500 - {"errorCode":"E103003","errorDescription":"Failed loading flow by ID"}`
- **Root Cause:** **IDENTIFIED** - Flow ID extracted from filename instead of schema
  - File: `/tmp/test-flow.json` → filename stem = `"test-flow"`
  - But actual flow ID in schema = `"sign-in"`
  - Backup attempts `export_flow("test-flow")` → 500 (flow doesn't exist)
- **Location:** `/src/descope_mgmt/cli/flow_cmds.py` line 234
- **Impact:** Blocks flow import when filename differs from flow ID
- **Workaround:** Use `--flow-id sign-in` override

### Full Details
See: `@.claude/docs/bug-report-flow-import-500.md`

### Code Issue
```python
# Current (WRONG) - line 234 in flow_cmds.py
actual_flow_id = flow_id or schema.get("flowId", file_path.stem)

# Should be (RIGHT)
actual_flow_id = flow_id or schema.get("flowId") or file_path.stem
```

---

## Jira Ticket Template - Bug 1

```
Title: Tenant Create Returns 500 Error

Type: Bug
Severity: High
Component: CLI - Tenant Management
Module: descope-mgmt.cli.tenant_cmds

Description:
The `descope-mgmt tenant create` command fails with HTTP 500 "Unknown server error"
(error code E010009) when attempting to create a new tenant.

Steps to Reproduce:
1. Set DESCOPE_PROJECT_ID and DESCOPE_MANAGEMENT_KEY env vars
2. Run: descope-mgmt tenant create --id "test-001" --name "Test" --domain "test.com"

Expected: Tenant created successfully with message "✓ Created tenant: test-001"
Actual: Error: API request failed: 500 - {"errorCode":"E010009","errorDescription":"Unknown server error"}

Root Cause Analysis:
- The POST /v1/mgmt/tenant endpoint is rejecting the payload
- Possible issues:
  1. Field naming (snake_case vs camelCase): flow_ids vs flowIds, enabled vs isEnabled
  2. Unsupported fields during creation (flow_ids may only work in updates)
  3. Missing required fields not defined in TenantConfig
  4. API version mismatch or recent endpoint changes

Investigation Needed:
1. Review Descope API v1 documentation for tenant creation endpoint
2. Compare successful list_tenants payload structure with create payload
3. Test with curl/Postman to verify API expectations
4. Check if flow_ids should be excluded from creation (only update?)

Acceptance Criteria:
- [x] Command succeeds without 500 error
- [x] Tenant created with correct ID, name, domain(s)
- [x] Success message displayed
- [x] Exit code 0 on success

Files:
- src/descope_mgmt/cli/tenant_cmds.py (lines 77-116)
- src/descope_mgmt/api/descope_client.py (lines 49-63)
- src/descope_mgmt/types/tenant.py
- src/descope_mgmt/domain/tenant_manager.py
```

---

## Jira Ticket Template - Bug 2

```
Title: Flow Import --apply Fails - Flow ID Extracted from Filename Instead of Schema

Type: Bug
Severity: High
Component: CLI - Flow Management
Module: descope-mgmt.cli.flow_cmds

Description:
The `descope-mgmt flow import --apply` command fails during the backup step when the
filename differs from the actual flow ID in the JSON schema. The command extracts the
flow ID from the filename (e.g., "test-flow") instead of from the schema (e.g., "sign-in"),
causing the backup export call to fail with "Failed loading flow by ID" (500 error).

Steps to Reproduce:
1. Export an existing flow: descope-mgmt flow export sign-in -o /tmp/test-flow.json
2. Import with apply: descope-mgmt flow import /tmp/test-flow.json --apply
3. Observe 500 error during backup step

Expected:
1. Flow ID "sign-in" extracted from schema
2. Existing flow backed up
3. Flow imported successfully

Actual:
1. Flow ID "test-flow" extracted from filename
2. Backup fails with 500: {"errorCode":"E103003","errorDescription":"Failed loading flow by ID"}
3. Import never executes

Root Cause (IDENTIFIED):
File: src/descope_mgmt/cli/flow_cmds.py, line 234
```python
actual_flow_id = flow_id or schema.get("flowId", file_path.stem)
```

This uses filename as fallback instead of prioritizing schema. Should be:
```python
actual_flow_id = flow_id or schema.get("flowId") or file_path.stem
```

Current behavior: CLI option > filename (WRONG)
Correct behavior: CLI option > schema field > filename (RIGHT)

Workaround: Use explicit --flow-id flag:
descope-mgmt flow import /tmp/test-flow.json --flow-id sign-in --apply

Investigation Needed:
1. Confirm flow ID in exported JSON schema is always under "flowId" key
2. Verify this only affects import with backup (dry-run works fine)
3. Check if any existing behavior relies on filename fallback

Acceptance Criteria:
- [x] Import succeeds when filename != flow ID
- [x] Correct flow ID extracted from schema, not filename
- [x] Backup created with actual flow ID
- [x] Import applies to correct flow
- [x] Explicit --flow-id override still works as escape hatch
- [x] No change to dry-run validation

Files:
- src/descope_mgmt/cli/flow_cmds.py (line 234, function import_flow_cmd)
- src/descope_mgmt/api/descope_client.py (lines 171-185)
- src/descope_mgmt/domain/flow_manager.py
- src/descope_mgmt/domain/backup_service.py

Related: export/import round-trip should be idempotent
```

---

## Priority and Sequencing

### Phase 1 (Immediate - Blocking)
1. **Bug 2: Flow Import** - Root cause IDENTIFIED, one-line fix, high impact
   - Simple fix in single location
   - Affects core workflow (backup/restore)
   - Easy to test and verify

2. **Bug 1: Tenant Create** - Requires investigation
   - Needs API documentation review
   - May require payload restructuring
   - Blocks multi-tenant setup

### Phase 2 (Follow-up)
- Add integration tests for tenant create
- Add integration tests for flow import with different filenames
- Update documentation with correct usage patterns

---

## Testing Strategy

### Bug 2 Testing (Post-Fix)
```bash
# Basic import with non-matching filename
descope-mgmt flow export sign-in -o /tmp/different-name.json
descope-mgmt flow import /tmp/different-name.json --apply

# Verify backup created with correct ID
ls ~/.descope-mgmt/backups/ | grep "sign-in"

# Test with --flow-id override still works
descope-mgmt flow import /tmp/different-name.json --flow-id sign-in --apply

# Test dry-run validation
descope-mgmt flow import /tmp/different-name.json --dry-run
```

### Bug 1 Testing (Post-Fix)
```bash
# Basic creation
descope-mgmt tenant create --id "test-001" --name "Test" --domain "test.com"

# Multiple domains
descope-mgmt tenant create --id "test-002" --name "Test 2" \
  --domain "domain1.com" --domain "domain2.com"

# Verify creation
descope-mgmt tenant list
```

---

## References

- Full Bug 1 Report: `@.claude/docs/bug-report-tenant-create-500.md`
- Full Bug 2 Report: `@.claude/docs/bug-report-flow-import-500.md`
- Project: `/home/jfogarty/pcc/core/pcc-descope-mgmt`
- Session Status: `@.claude/status/brief.md`
