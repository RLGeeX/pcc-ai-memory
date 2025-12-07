# Jira Ticket Templates - Ready to Copy/Paste

Use these templates to create Jira tickets for the two identified bugs.

---

## TICKET 1: Tenant Create Returns 500 Error

**Type:** Bug
**Priority:** High
**Severity:** High
**Component:** CLI
**Labels:** bug, cli, tenant-management, api-integration

### Title
```
Tenant Create Returns 500 Error - E010009 Unknown Server Error
```

### Description
```
The `descope-mgmt tenant create` CLI command fails with HTTP 500 "Unknown server error"
(error code E010009) when attempting to create a new tenant. This blocks the entire
tenant creation workflow and forces users to create tenants via the Descope UI.

STEPS TO REPRODUCE
==================
1. Set environment variables:
   export DESCOPE_PROJECT_ID="P2..."
   export DESCOPE_MANAGEMENT_KEY="K2..."

2. Run the create tenant command:
   descope-mgmt tenant create --id "test-001" --name "Test Tenant" --domain "test.example.com"

3. Observe the error response


ACTUAL BEHAVIOR
===============
Error: API request failed: 500 -
{"errorCode":"E010009","errorDescription":"Unknown server error"}

Command exits with non-zero status
No tenant is created
No success message is displayed


EXPECTED BEHAVIOR
=================
Tenant should be created successfully with:
- ID: test-001
- Name: Test Tenant
- Domain(s): test.example.com
- Status: enabled (default)
- Flow IDs: empty (default)

CLI output:
✓ Created tenant: test-001

Command exits with status code 0


TECHNICAL DETAILS
=================

API Endpoint: POST /v1/mgmt/tenant
Expected Payload:
{
  "id": "test-001",
  "name": "Test Tenant",
  "domains": ["test.example.com"],
  "flow_ids": [],
  "enabled": true
}

Code Flow:
1. User invokes: descope-mgmt tenant create --id "test-001" --name "Test Tenant" --domain "test.example.com"
2. Handler: src/descope_mgmt/cli/tenant_cmds.py::create_tenant() (line 77-116)
3. Validation: TenantConfig validation succeeds
4. API Call: DescopeClient.create_tenant() → POST /v1/mgmt/tenant
5. Response: 500 error with E010009


POSSIBLE ROOT CAUSES
====================
1. Field naming mismatch:
   - Current: flow_ids, enabled
   - API expects: flowIds, isEnabled, or other variations

2. Unsupported fields during creation:
   - API may not accept flow_ids during tenant creation
   - May only support flow_ids during updates

3. Missing required fields:
   - Possible required fields: customDomain, customerId, selfServiceURL, etc.

4. Payload serialization issue:
   - Pydantic model_dump(mode="json") may not match API expectations

5. API endpoint mismatch:
   - Recent Descope API changes may have updated field names or requirements


INVESTIGATION STEPS
===================
1. Test with curl to verify API behavior:
   curl -X POST https://api.descope.com/v1/mgmt/tenant \
     -H "Authorization: Bearer $DESCOPE_PROJECT_ID:$DESCOPE_MANAGEMENT_KEY" \
     -H "Content-Type: application/json" \
     -d '{"id":"test-001","name":"Test","domains":["test.com"],"enabled":true}'

2. Check Descope API v1 documentation for:
   - Required and optional fields in tenant creation
   - Field naming conventions (camelCase vs snake_case)
   - Any recent version changes

3. Compare with working operation:
   - tenant list (GET /v1/mgmt/tenant/all) works correctly
   - Response format should guide payload format

4. Enable verbose logging:
   descope-mgmt --verbose tenant create --id "test-001" --name "Test" --domain "test.com"

5. Review TenantConfig.model_dump(mode="json") output


AFFECTED FILES
==============
- src/descope_mgmt/cli/tenant_cmds.py (lines 77-116)
- src/descope_mgmt/api/descope_client.py (lines 49-63, create_tenant method)
- src/descope_mgmt/types/tenant.py (TenantConfig class)
- src/descope_mgmt/domain/tenant_manager.py (create_tenant wrapper)


ACCEPTANCE CRITERIA
===================
Must Have:
- [ ] Command succeeds without 500 error
- [ ] Tenant created with correct ID, name, and domains
- [ ] Success message displayed: "✓ Created tenant: <id>"
- [ ] Exit code is 0 on success
- [ ] All validation still works (invalid tenant IDs rejected, etc.)

Should Have:
- [ ] Verbose mode shows exact payload sent to API
- [ ] Better error messages for 400-level API errors
- [ ] Documentation updated if payload structure changes

Test Cases:
- [ ] Basic creation: --id "basic" --name "Basic" --domain "basic.com"
- [ ] Multiple domains: --id "multi" --name "Multi" --domain "d1.com" --domain "d2.com"
- [ ] Special characters: --id "special" --name "Test & Co." --domain "special.com"
- [ ] Dry run: descope-mgmt --dry-run tenant create --id "test" --name "Test" --domain "test.com"


IMPACT
======
Severity: HIGH - Blocks critical workflow
- Users cannot programmatically create tenants
- CI/CD automation cannot provision multi-tenant environments
- Workaround: Manual creation via Descope UI (unacceptable for automation)

Affected Users:
- Infrastructure teams automating Descope setup
- CI/CD pipelines deploying multi-tenant configurations
- Anyone using descope-mgmt for infrastructure-as-code


RELATED ISSUES
==============
- Similar working commands: tenant list, flow list, flow export
- Likely related to API contract changes in Descope SDK or endpoint updates
```

---

## TICKET 2: Flow Import --apply Fails - Flow ID From Filename Instead of Schema

**Type:** Bug
**Priority:** High
**Severity:** High
**Component:** CLI
**Labels:** bug, cli, flow-management, backup-restore

### Title
```
Flow Import --apply Fails During Backup - Flow ID Extracted from Filename Instead of Schema
```

### Description
```
The `descope-mgmt flow import --apply` command fails with HTTP 500 "Failed loading flow by ID"
error during the backup step when the input filename differs from the actual flow ID in the
JSON schema. The bug causes the backup to attempt exporting a flow ID derived from the
filename (e.g., "test-flow") instead of from the schema (e.g., "sign-in"), resulting in
a 500 error because the wrong flow ID doesn't exist.

ROOT CAUSE IDENTIFIED
====================
File: src/descope_mgmt/cli/flow_cmds.py
Line: 234

Current (WRONG):
    actual_flow_id = flow_id or schema.get("flowId", file_path.stem)

This logic:
1. If --flow-id provided, use it (correct)
2. Otherwise, check schema for "flowId" (correct)
3. Otherwise, use filename stem (WRONG - should be last resort)

Problem: When schema has "flowId", it gets evaluated by .get(), but if not
provided via --flow-id, it doesn't fall through to schema check properly.

Correct order should be:
    actual_flow_id = flow_id or schema.get("flowId") or file_path.stem

This ensures: CLI option > schema field > filename


STEPS TO REPRODUCE
==================
1. Export an existing flow:
   descope-mgmt flow export sign-in -o /tmp/test-flow.json

2. Attempt to import with --apply:
   descope-mgmt flow import /tmp/test-flow.json --apply

3. Observe 500 error during backup


ACTUAL BEHAVIOR
===============
Error: API request failed: 500 -
{"errorCode":"E103003","errorDescription":"Failed getting flow",
"errorMessage":"Failed loading flow by ID","message":"Failed loading flow by ID"}

What happens:
1. File path: /tmp/test-flow.json
2. file_path.stem extracted: "test-flow"
3. Backup attempts: export_flow("test-flow")
4. API error: Flow "test-flow" doesn't exist
5. Command exits without importing


EXPECTED BEHAVIOR
=================
1. Read flow file: /tmp/test-flow.json
2. Extract flow ID from schema: "sign-in" (from JSON's "flowId" field)
3. Backup existing flow: export_flow("sign-in")
4. Backup saved: ~/.descope-mgmt/backups/flow_sign-in_TIMESTAMP.json
5. Import new flow: import_flow("sign-in", schema)
6. Success message:
   Backed up existing flow to: /home/.../flow_sign-in_TIMESTAMP.json
   Imported flow: sign-in


TECHNICAL DETAILS
=================

Files Involved:
- src/descope_mgmt/cli/flow_cmds.py (lines 219-267, bug at line 234)
- src/descope_mgmt/api/descope_client.py (lines 171-185)
- src/descope_mgmt/domain/flow_manager.py (export_flow, import_flow)
- src/descope_mgmt/domain/backup_service.py (backup_flow)

API Endpoints:
- Backup step (FAILS): POST /v1/mgmt/flow/export
  Payload: {"flowId": "test-flow"} ← WRONG ID
  Response: 500 - "Failed loading flow by ID"

- Import step (NEVER REACHED): POST /v1/mgmt/flow/import
  Would have been: {"flowId": "test-flow", "flow": {...}} ← Wrong ID

Affected Scenarios:
1. ✓ Works: descope-mgmt flow import /tmp/sign-in.json --apply
   (Filename matches flow ID, works by accident)

2. ✗ FAILS: descope-mgmt flow import /tmp/test-flow.json --apply
   (Filename doesn't match flow ID - the bug)

3. ✓ Works: descope-mgmt flow import /tmp/test-flow.json --flow-id sign-in --apply
   (Explicit override bypasses bug)

4. ✓ Works: descope-mgmt flow import /tmp/test-flow.json --dry-run
   (Dry-run doesn't attempt backup, validation only)


CURRENT WORKAROUND
==================
Users must explicitly provide the flow ID:
descope-mgmt flow import /tmp/test-flow.json --flow-id sign-in --apply

This is not intuitive and defeats the purpose of extracting ID from schema.


IMPACT
======
Severity: HIGH - Blocks critical workflow

Blocked scenarios:
- Importing exported flows with renamed files
- CI/CD pipelines that don't know the flow ID beforehand
- Backup/restore workflows expecting idempotent behavior
- Export → Import round-trip when filename is not preserved

Users affected:
- Anyone using flow import as part of disaster recovery
- CI/CD automation for flow deployment
- Infrastructure-as-code tools relying on idempotent imports


ACCEPTANCE CRITERIA
===================
Must Have:
- [ ] Import succeeds when filename != flow ID
- [ ] Correct flow ID extracted from schema (not filename)
- [ ] Backup created with actual flow ID
- [ ] Import applies to correct flow ID
- [ ] Explicit --flow-id override still works as escape hatch
- [ ] No regression in existing working scenarios

Should Have:
- [ ] Verbose mode shows which flow ID was extracted
- [ ] Clear error if flow ID cannot be determined
- [ ] Dry-run validation also validates flow ID extraction

Test Cases:
- [ ] Import with non-matching filename:
      descope-mgmt flow export sign-in -o /tmp/renamed.json
      descope-mgmt flow import /tmp/renamed.json --apply

- [ ] Import with --flow-id override (should still work):
      descope-mgmt flow import /tmp/renamed.json --flow-id sign-in --apply

- [ ] Import with matching filename (should still work):
      descope-mgmt flow export sign-in -o /tmp/sign-in.json
      descope-mgmt flow import /tmp/sign-in.json --apply

- [ ] Dry-run validation (should work, shows flow ID):
      descope-mgmt flow import /tmp/renamed.json --dry-run

- [ ] Create new flow via import:
      descope-mgmt flow import /tmp/new-flow.json --apply

- [ ] Verify backup file created with correct ID:
      ls -la ~/.descope-mgmt/backups/ | grep sign-in


AFFECTED FILES
==============
- src/descope_mgmt/cli/flow_cmds.py (line 234, function import_flow_cmd)
- Related: src/descope_mgmt/api/descope_client.py (export_flow, import_flow)
- Related: src/descope_mgmt/domain/flow_manager.py
- Related: src/descope_mgmt/domain/backup_service.py


FIX SUMMARY
===========
Simple one-line fix in src/descope_mgmt/cli/flow_cmds.py, line 234:

BEFORE:
    actual_flow_id = flow_id or schema.get("flowId", file_path.stem)

AFTER:
    actual_flow_id = flow_id or schema.get("flowId") or file_path.stem

Reasoning:
- Original used fallback in .get() call, making filename always available
- Fixed version uses proper None chaining, ensuring schema is checked first
- Maintains backward compatibility (filename still works as last resort)
- Explicit --flow-id override still takes precedence


TESTING
=======
Before deploying, verify:
1. Dry-run validation still works
2. Import with --flow-id override still works
3. Import with matching filename still works
4. Import with non-matching filename now works (previously failed)
5. Backup created with correct flow ID
6. Correct flow imported (verify via API or list command)
```

---

## Quick Copy-Paste Instructions

### For Jira UI:

1. Go to: https://your-jira-instance/secure/CreateIssue.jspa
2. Select Project: pcc-descope-mgmt (or appropriate project)
3. Issue Type: Bug
4. For Ticket 1:
   - **Summary:** Tenant Create Returns 500 Error - E010009 Unknown Server Error
   - **Description:** Copy from "TICKET 1" section above
   - **Priority:** High
   - **Labels:** bug, cli, tenant-management
5. For Ticket 2:
   - **Summary:** Flow Import --apply Fails - Flow ID From Filename Instead of Schema
   - **Description:** Copy from "TICKET 2" section above
   - **Priority:** High
   - **Labels:** bug, cli, flow-management, backup-restore

---

## Alternative: Create via CLI (if using Jira CLI)

```bash
# Ticket 1
jira issue create \
  --project PCC \
  --type Bug \
  --summary "Tenant Create Returns 500 Error - E010009 Unknown Server Error" \
  --priority High \
  --labels bug,cli,tenant-management \
  --description "$(cat <<'EOF'
[See bug-report-tenant-create-500.md for full details]
EOF
)"

# Ticket 2
jira issue create \
  --project PCC \
  --type Bug \
  --summary "Flow Import --apply Fails - Flow ID From Filename Instead of Schema" \
  --priority High \
  --labels bug,cli,flow-management,backup-restore \
  --description "$(cat <<'EOF'
[See bug-report-flow-import-500.md for full details]
EOF
)"
```

---

## Priority Recommendations

### Fix Bug 2 FIRST (Flow Import)
- Root cause IDENTIFIED and simple
- Single line fix
- High impact (core workflow)
- Easy to test and verify
- Estimated: 30 mins

### Fix Bug 1 SECOND (Tenant Create)
- Requires API investigation
- Likely involves payload restructuring
- Estimated: 2-4 hours (includes investigation)

---

## References

- **Full Bug 1 Details:** `@.claude/docs/bug-report-tenant-create-500.md`
- **Full Bug 2 Details:** `@.claude/docs/bug-report-flow-import-500.md`
- **Summary:** `@.claude/docs/bug-reports-summary.md`
- **Project Directory:** `/home/jfogarty/pcc/core/pcc-descope-mgmt`
