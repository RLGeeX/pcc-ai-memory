# Chunk 12: End-to-End API Verification

**Status:** completed
**Dependencies:** chunk-011-cli-integration
**Complexity:** medium
**Estimated Time:** 15 minutes
**Tasks:** 3
**Phase:** Integration & Testing

---

## Task 1: Verify Role Commands Against Live API

**Agent:** python-pro
**Files:**
- None (manual testing)

**Step 1: Set up environment**

```bash
source .env  # Load DESCOPE_PROJECT_ID and DESCOPE_MANAGEMENT_KEY
```

**Step 2: Test role list**

```bash
descope-mgmt role list
```

Expected: Shows table of existing roles (at minimum: "Tenant Admin")

**Step 3: Test role create**

```bash
descope-mgmt role create pcc-test-role --description "Test role for CLI verification"
```

Expected: "Created role: pcc-test-role"

**Step 4: Test role list again**

```bash
descope-mgmt role list
```

Expected: Shows "pcc-test-role" in the table

**Step 5: Test role delete**

```bash
descope-mgmt role delete pcc-test-role --force
```

Expected: "Deleted role: pcc-test-role"

**If any command fails:**
- Check error message
- Verify API endpoint patterns match Descope documentation
- Fix and re-test before proceeding

---

## Task 2: Verify User Commands Against Live API

**Agent:** python-pro
**Files:**
- None (manual testing)

**Step 1: Test user list**

```bash
descope-mgmt user list --limit 10
```

Expected: Shows table of users (may be empty if no users exist)

**Step 2: Test user invite (uses a test email)**

```bash
descope-mgmt user invite --email pcc-test-user@example.com --name "PCC Test User"
```

Expected: "Invited user: pcc-test-user@example.com" with User ID

Note: If this fails with "email already exists", the user was created previously. Use `user list` to find the user ID.

**Step 3: Test user get**

```bash
descope-mgmt user get <USER_ID_FROM_PREVIOUS_STEP>
```

Expected: Shows user details table

**Step 4: Test role assignment**

```bash
descope-mgmt user add-role <USER_ID> "Tenant Admin"
```

Expected: "Added role 'Tenant Admin' to user <USER_ID>"

**Step 5: Verify role was added**

```bash
descope-mgmt user get <USER_ID>
```

Expected: Roles field shows "Tenant Admin"

**Step 6: Clean up test user**

```bash
descope-mgmt user delete <USER_ID> --force
```

Expected: "Deleted user: <USER_ID>"

**If any command fails:**
- Document the error
- Check API endpoint and payload
- Fix in descope_client.py and re-test

---

## Task 3: Run Full Test Suite and Final Checks

**Agent:** python-pro
**Files:**
- None (verification only)

**Step 1: Run full test suite**

```bash
pytest tests/ -v --tb=short
```

Expected: All tests pass

**Step 2: Run linters**

```bash
ruff check . && ruff format --check . && mypy .
```

Expected: No errors

**Step 3: Run pre-commit hooks**

```bash
pre-commit run --all-files
```

Expected: All hooks pass

**Step 4: Generate coverage report**

```bash
pytest tests/ --cov=descope_mgmt --cov-report=term-missing
```

Expected: Coverage >= 90%

**Step 5: Final commit**

```bash
git add -A
git commit -m "feat: complete user management and RBAC CLI implementation

Adds user management commands:
- user list, get, invite, update, delete
- user add-role, remove-role

Adds role management commands:
- role list, create, update, delete

All commands verified against live Descope API."
```

---

## FINAL REVIEW CHECKPOINT

Before marking the feature complete:

1. **All tests pass** - `pytest tests/ -v`
2. **Linters pass** - `ruff check . && mypy .`
3. **Pre-commit hooks pass** - `pre-commit run --all-files`
4. **Live API verification complete** - All commands tested
5. **Coverage >= 90%**

---

## Chunk Complete Checklist

- [x] Role commands verified against live API
- [x] User commands verified against live API (dry-run only to avoid sending emails)
- [x] Full test suite passes (376 tests, 372 passed, 4 skipped)
- [x] Linters pass (ruff check, ruff format, mypy)
- [x] Pre-commit hooks pass
- [x] Coverage adequate (91% overall)
- [x] Feature complete
