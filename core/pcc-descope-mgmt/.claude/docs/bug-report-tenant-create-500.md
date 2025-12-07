# Bug Report: Tenant Create Returns 500 Error

## Summary
`descope-mgmt tenant create` command fails with 500 "Unknown server error" when attempting to create a new tenant via the CLI.

## Description
The CLI's tenant creation command is failing at the API layer, returning a 500 Internal Server Error with error code `E010009`. The underlying cause appears to be related to how the request payload is formatted or what fields are being sent to the Descope management API.

The `tenant list` command works correctly, confirming that:
- Authentication credentials are valid
- API connectivity is functional
- Base endpoint URL is correct
- Rate limiting is not the issue

This suggests the issue is specific to the `POST /v1/mgmt/tenant` endpoint or the payload being sent to it.

## Steps to Reproduce

1. Set up environment variables:
   ```bash
   export DESCOPE_PROJECT_ID="P2..."
   export DESCOPE_MANAGEMENT_KEY="K2..."
   ```

2. Run the create tenant command:
   ```bash
   descope-mgmt tenant create --id "test-001" --name "Test Tenant" --domain "test.example.com"
   ```

3. Observe the error output

## Actual Result

```
Error: API request failed: 500 -
{"errorCode":"E010009","errorDescription":"Unknown server error"}
```

The CLI exits with a non-zero status code and no tenant is created.

## Expected Result

The tenant should be created successfully with:
- ID: `test-001`
- Name: `Test Tenant`
- Domain(s): `test.example.com`
- Default enabled status: `True`
- Default flow_ids: empty list

The CLI should output:
```
✓ Created tenant: test-001
```

## Technical Investigation

### Code Flow
1. User invokes: `descope-mgmt tenant create --id "test-001" --name "Test Tenant" --domain "test.example.com"`
2. CLI handler: `/home/jfogarty/pcc/core/pcc-descope-mgmt/src/descope_mgmt/cli/tenant_cmds.py::create_tenant()` (line 77-116)
3. Validation: Creates `TenantConfig` object with provided parameters
4. Manager call: `TenantManager.create_tenant(tenant_config)` passes to API client
5. API call: `DescopeClient.create_tenant()` (line 49-63 in `descope_client.py`)
6. Request: `POST /v1/mgmt/tenant` with payload from `TenantConfig.model_dump(mode="json")`

### Payload Structure
Based on `TenantConfig` class definition (`/home/jfogarty/pcc/core/pcc-descope-mgmt/src/descope_mgmt/types/tenant.py`):

**Expected payload:**
```json
{
  "id": "test-001",
  "name": "Test Tenant",
  "domains": ["test.example.com"],
  "flow_ids": [],
  "enabled": true
}
```

### Possible Root Causes

1. **Field naming mismatch**: The Descope API may expect camelCase or snake_case differently than what's being sent
   - Current: `flow_ids`, `enabled`
   - Possible API expectation: `flowIds`, `isEnabled`, or other variations

2. **Unexpected fields**: The API may not accept `flow_ids` during creation (only supports it in updates)
   - Error code `E010009` suggests server-side validation failure

3. **Missing required fields**: Some fields required by the API might not be included in the payload
   - Possible fields: `customDomain`, `customerId`, `selfServiceURL`, or other config

4. **Payload serialization issue**: The `model_dump(mode="json")` call may not be properly converting Pydantic models to JSON-compatible format

5. **API endpoint mismatch**: The endpoint `POST /v1/mgmt/tenant` may have changed in recent Descope API versions

### Investigation Steps

1. Enable verbose logging to see the exact JSON payload being sent:
   ```bash
   descope-mgmt --verbose tenant create --id "test-001" --name "Test Tenant" --domain "test.example.com"
   ```

2. Check Descope API documentation for:
   - Required and optional fields in tenant creation payload
   - Field naming conventions (snake_case vs camelCase)
   - Any version-specific changes to the endpoint

3. Compare with successful `tenant list` request structure:
   - `list_tenants()` uses `GET /v1/mgmt/tenant/all` (line 103)
   - The parser expects fields: `tenants[].id`, `tenants[].name`, `tenants[].domains`

4. Test with Postman/curl to verify API behavior:
   ```bash
   curl -X POST https://api.descope.com/v1/mgmt/tenant \
     -H "Authorization: Bearer $DESCOPE_PROJECT_ID:$DESCOPE_MANAGEMENT_KEY" \
     -H "Content-Type: application/json" \
     -d '{
       "id": "test-001",
       "name": "Test Tenant",
       "domains": ["test.example.com"],
       "enabled": true
     }'
   ```

## Impact

**Severity:** High
- Blocks entire tenant creation workflow
- Cannot establish multi-tenant infrastructure via CLI
- Workaround: None (must use Descope UI if available)

**Affected Components:**
- `descope_mgmt.cli.tenant_cmds::create_tenant()`
- `descope_mgmt.api.descope_client::create_tenant()`
- `descope_mgmt.types.tenant::TenantConfig`

**User Impact:**
- Users cannot programmatically create tenants
- CI/CD pipelines cannot automate tenant provisioning
- Manual tenant creation required in UI

## Files Involved

- `/home/jfogarty/pcc/core/pcc-descope-mgmt/src/descope_mgmt/cli/tenant_cmds.py` (lines 77-116)
- `/home/jfogarty/pcc/core/pcc-descope-mgmt/src/descope_mgmt/api/descope_client.py` (lines 49-63)
- `/home/jfogarty/pcc/core/pcc-descope-mgmt/src/descope_mgmt/types/tenant.py` (entire file)
- `/home/jfogarty/pcc/core/pcc-descope-mgmt/src/descope_mgmt/domain/tenant_manager.py` (create_tenant method)

## Acceptance Criteria

### Must Have
1. CLI command `descope-mgmt tenant create --id "test-001" --name "Test" --domain "test.com"` succeeds
2. Tenant is created in Descope with correct ID, name, and domain(s)
3. Command outputs success message: `✓ Created tenant: test-001`
4. Exit code is 0 on success

### Should Have
1. Verbose mode shows exact API payload being sent
2. Improved error message if API returns 400-level errors (validation issues)
3. Documentation updated if field names or payload structure change

### Test Cases
```bash
# Basic creation
descope-mgmt tenant create --id "basic" --name "Basic Test" --domain "basic.com"

# Multiple domains
descope-mgmt tenant create --id "multi" --name "Multi Domain" \
  --domain "domain1.com" --domain "domain2.com"

# Special characters in name
descope-mgmt tenant create --id "special" --name "Test & Co." --domain "special.com"

# Dry run validation
descope-mgmt --dry-run tenant create --id "dryrun" --name "Dry Run" --domain "dryrun.com"
```

## Related Issues

- Similar working operations: `tenant list`, `flow list`, `flow export`
- Likely related to API contract changes in Descope SDK or endpoint

## Environment

- Python: 3.12
- Project: pcc-descope-mgmt
- CLI: descope-mgmt (Click-based)
- API: Descope Management API v1
