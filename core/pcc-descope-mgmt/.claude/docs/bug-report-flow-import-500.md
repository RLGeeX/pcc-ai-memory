# Bug Report: Flow Import --apply Returns 500 Error During Backup

## Summary
`descope-mgmt flow import --apply` command fails with 500 "Failed loading flow by ID" error during the backup step, preventing flow imports even when the flow file is valid.

## Description
The flow import command has a critical flaw in its backup logic. When attempting to import a flow with the `--apply` flag, the command:

1. Successfully reads the flow file from disk
2. Extracts the flow ID (either from `--flow-id` option, file's `flowId` field, or filename stem)
3. Attempts to backup the existing flow by calling `export_flow(actual_flow_id)`
4. Fails with a 500 error because the flow ID passed to the export function is incorrect

The root cause is that the flow ID is being derived from the filename (e.g., `test-flow` from `/tmp/test-flow.json`) instead of using the actual flow ID from the exported schema (e.g., `sign-in`). This causes the API to attempt exporting a flow ID that doesn't exist, triggering the backup failure.

## Steps to Reproduce

1. Export an existing flow to a JSON file:
   ```bash
   export DESCOPE_PROJECT_ID="P2..."
   export DESCOPE_MANAGEMENT_KEY="K2..."
   descope-mgmt flow export sign-in -o /tmp/test-flow.json
   ```

2. Attempt to import the flow with `--apply`:
   ```bash
   descope-mgmt flow import /tmp/test-flow.json --apply
   ```

3. Observe the error (command fails immediately during backup step)

## Actual Result

```
Error: API request failed: 500 -
{"errorCode":"E103003","errorDescription":"Failed getting flow","errorMessage":"Failed loading flow by ID","message":"Failed loading flow by ID"}
[red]Error:[/red] API request failed: 500 -
{"errorCode":"E103003","errorDescription":"Failed getting flow","errorMessage":"Failed loading flow by ID","message":"Failed loading flow by ID"}
```

The CLI exits with a non-zero status code. No flow is imported. No backup is created.

## Expected Result

The flow should be imported successfully with the following behavior:
1. Read flow file: `/tmp/test-flow.json`
2. Extract flow ID: `sign-in` (from file contents, not filename)
3. Backup existing flow: Export current `sign-in` flow to backup directory
4. Import new flow: Apply the flow schema from the JSON file
5. Success message:
   ```
   Backed up existing flow to: /home/.../flow_sign-in_2025-12-02_15-30-45.json
   [green]Imported flow:[/green] sign-in
   ```

## Technical Investigation

### Code Flow Analysis

The bug is in `/home/jfogarty/pcc/core/pcc-descope-mgmt/src/descope_mgmt/cli/flow_cmds.py::import_flow_cmd()` (lines 219-267):

**Line 234: Incorrect Flow ID derivation**
```python
# BUG: Uses filename stem instead of flow ID from schema
actual_flow_id = flow_id or schema.get("flowId", file_path.stem)
```

**Problem Sequence:**
1. File: `/tmp/test-flow.json`
2. `file_path.stem` = `"test-flow"` (filename without extension)
3. Schema actually contains: `"flowId": "sign-in"`
4. Flow ID used for backup: `"test-flow"` (WRONG)
5. Backup call: `manager.export_flow("test-flow")` → 500 error (flow doesn't exist)

### Root Cause

Line 234 uses a fallback order that prioritizes the filename over the actual flow ID in the JSON schema:
```python
actual_flow_id = flow_id or schema.get("flowId", file_path.stem)
```

This creates a three-tier fallback:
1. Use `--flow-id` CLI option (if provided)
2. Use `flowId` from JSON schema (if present)
3. Fall back to filename stem (if neither above)

The intent was to handle cases where flow ID isn't provided, but the logic is **inverted**. It should prioritize the actual flow ID from the schema, not the filename.

### Comparison with Working Export

The `export_flow_cmd()` (lines 186-210) works correctly because it takes the flow ID as a direct argument:
```python
@click.argument("flow_id")  # Takes flow ID directly
def export_flow_cmd(ctx: click.Context, flow_id: str, output: Path | None) -> None:
    # ...
    schema = manager.export_flow(flow_id)  # Uses provided flow_id, no fallback
```

### API Endpoints Involved

1. **Export endpoint**: `POST /v1/mgmt/flow/export` (line 183-185 in `descope_client.py`)
   - Payload: `{"flowId": "test-flow"}` (the WRONG ID)
   - Response: 500 error because flow "test-flow" doesn't exist

2. **Import endpoint**: `POST /v1/mgmt/flow/import` (line 187-202)
   - Would work if backup step succeeded
   - Payload: `{"flowId": "test-flow", "flow": {...}}` (using wrong ID)

### Backup Service

`BackupService.backup_flow()` (in `/home/jfogarty/pcc/core/pcc-descope-mgmt/src/descope_mgmt/domain/backup_service.py`) just writes files locally. The error originates from the API call, not the backup service.

### Impact Scope

**All import scenarios fail:**
1. `descope-mgmt flow import /tmp/sign-in.json --apply` (filename = flow ID)
   - Works by accident (filename happens to match flow ID)

2. `descope-mgmt flow import /tmp/test-flow.json --apply` (filename != flow ID)
   - **FAILS** - This is the bug scenario

3. `descope-mgmt flow import /tmp/any-name.json --flow-id sign-in --apply`
   - Works (uses explicit `--flow-id` option)

4. Import with dry-run flag works (doesn't attempt backup)
   ```bash
   descope-mgmt flow import /tmp/test-flow.json --dry-run  # SUCCESS
   descope-mgmt flow import /tmp/test-flow.json --apply    # FAILS
   ```

## Impact

**Severity:** High
- Blocks flow import functionality when filename differs from flow ID
- Users must use `--flow-id` override as workaround
- No intuitive way for users to know which ID to pass
- Inconsistent with export command behavior (takes flow ID directly)

**Affected Components:**
- `descope_mgmt.cli.flow_cmds::import_flow_cmd()` (lines 219-267)
- `descope_mgmt.domain.flow_manager::import_flow()` (backup step)

**Scenarios Affected:**
- Importing exported flows with renamed files
- CI/CD pipelines that don't use explicit `--flow-id` flag
- Backup/restore workflows expecting idempotent behavior

## Files Involved

- `/home/jfogarty/pcc/core/pcc-descope-mgmt/src/descope_mgmt/cli/flow_cmds.py` (lines 219-267, bug at line 234)
- `/home/jfogarty/pcc/core/pcc-descope-mgmt/src/descope_mgmt/api/descope_client.py` (lines 171-185)
- `/home/jfogarty/pcc/core/pcc-descope-mgmt/src/descope_mgmt/domain/flow_manager.py` (export_flow and import_flow methods)
- `/home/jfogarty/pcc/core/pcc-descope-mgmt/src/descope_mgmt/domain/backup_service.py` (backup_flow method)

## Acceptance Criteria

### Must Have
1. Flow import succeeds when filename differs from actual flow ID in the JSON schema
2. Correct flow ID is extracted from JSON schema (not filename)
3. Backup is created using actual flow ID before import
4. Import applies to correct flow ID after successful backup
5. Command: `descope-mgmt flow import /tmp/test-flow.json --apply` succeeds

### Should Have
1. Explicit `--flow-id` override still works as escape hatch
2. Verbose mode shows which flow ID was extracted and used
3. Clear error message if flow ID cannot be determined from schema or CLI option
4. Dry-run validation also validates flow ID extraction

### Must Not
1. Change behavior when `--flow-id` is explicitly provided (should override schema)
2. Break existing working scenarios (filename = flow ID)

## Test Cases

```bash
# Setup: Export a flow with known ID
descope-mgmt flow export sign-in -o /tmp/test-flow.json

# Test 1: Import with filename != flow ID (MAIN BUG)
descope-mgmt flow import /tmp/test-flow.json --apply
# Expected: Success, backup created with "sign-in" ID

# Test 2: Import with --flow-id override
descope-mgmt flow import /tmp/test-flow.json --flow-id sign-in --apply
# Expected: Success (current workaround)

# Test 3: Import with matching filename
descope-mgmt flow export sign-in -o /tmp/sign-in.json
descope-mgmt flow import /tmp/sign-in.json --apply
# Expected: Success

# Test 4: Dry-run validation (should work)
descope-mgmt flow import /tmp/test-flow.json --dry-run
# Expected: Validation passes, shows extracted flow ID

# Test 5: Import non-existent flow (create new)
# Create JSON with new flow ID, verify import works
descope-mgmt flow import /tmp/new-flow.json --apply
# Expected: New flow created with correct ID

# Test 6: Backup verification
# Verify backup file was created with correct flow ID
ls -la ~/.descope-mgmt/backups/ | grep "sign-in"
# Expected: flow_sign-in_TIMESTAMP.json exists
```

## Suggested Fix Approach

**Option 1: Correct the fallback order (Recommended)**
```python
# Current (WRONG):
actual_flow_id = flow_id or schema.get("flowId", file_path.stem)

# Fixed (RIGHT):
actual_flow_id = flow_id or schema.get("flowId") or file_path.stem
# This ensures: CLI option > schema field > filename
```

**Option 2: Use flowId from schema exclusively in dry-run**
```python
# Ensure dry-run validates against actual schema flow ID
if dry_run or not apply_import:
    schema_flow_id = schema.get("flowId", file_path.stem)
    console.print(f"  Flow ID (from schema): {schema_flow_id}")
```

**Option 3: Require explicit flow ID when schema has one**
```python
# Fail fast if schema has flowId but doesn't match
if "flowId" in schema and flow_id and schema["flowId"] != flow_id:
    raise ValueError(f"Flow ID mismatch: CLI={flow_id}, schema={schema['flowId']}")
```

## Related Issues

- Flow export works correctly: `descope-mgmt flow export sign-in -o /tmp/test.json`
- Dry-run validation passes: `descope-mgmt flow import /tmp/test-flow.json --dry-run`
- Workaround exists: Use `--flow-id` explicitly
- Inconsistent with expected behavior of `export → import` round-trip

## Environment

- Python: 3.12
- Project: pcc-descope-mgmt
- CLI: descope-mgmt (Click-based)
- API: Descope Management API v1
- Related endpoints:
  - `POST /v1/mgmt/flow/export` (backup step fails here)
  - `POST /v1/mgmt/flow/import` (never reached due to backup failure)
