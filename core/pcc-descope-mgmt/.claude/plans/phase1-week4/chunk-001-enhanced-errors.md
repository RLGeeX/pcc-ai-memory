# Chunk 1: Enhanced Error Messages

**Status:** pending
**Dependencies:** none
**Complexity:** simple
**Estimated Time:** 15 minutes
**Tasks:** 2

---

## Task 1: Create ErrorFormatter Utility

**Agent:** python-pro
**Files:**
- Create: `src/descope_mgmt/cli/error_formatter.py`
- Create: `tests/unit/cli/test_error_formatter.py`

**Step 1: Write the failing test**

Create test file with error formatting tests:

```python
"""Tests for error formatter with recovery suggestions."""

from descope_mgmt.cli.error_formatter import ErrorFormatter
from descope_mgmt.types.exceptions import (
    ApiError,
    ConfigError,
    ConfigurationError,
    ValidationError,
)


def test_format_api_error_with_401():
    """Test formatting API error with authentication failure."""
    error = ApiError("Unauthorized", status_code=401)
    result = ErrorFormatter.format(error)

    assert "Authentication failed" in result
    assert "DESCOPE_MANAGEMENT_KEY" in result
    assert "verify your credentials" in result.lower()


def test_format_api_error_with_404():
    """Test formatting API error with not found."""
    error = ApiError("Tenant not found", status_code=404)
    result = ErrorFormatter.format(error)

    assert "not found" in result.lower()
    assert "tenant list" in result.lower()


def test_format_config_error_file_not_found():
    """Test formatting config error for missing file."""
    error = ConfigError("Configuration file not found: config/tenants.yaml")
    result = ErrorFormatter.format(error)

    assert "not found" in result.lower()
    assert "config/tenants.yaml.example" in result


def test_format_validation_error_unique_constraint():
    """Test formatting validation error for duplicates."""
    error = ValidationError("Duplicate tenant IDs: ['acme', 'acme']")
    result = ErrorFormatter.format(error)

    assert "duplicate" in result.lower()
    assert "unique" in result.lower()


def test_format_unknown_error():
    """Test formatting unknown error type."""
    error = ValueError("Something went wrong")
    result = ErrorFormatter.format(error)

    assert "Something went wrong" in result
```

**Step 2: Run test to verify it fails**

```bash
pytest tests/unit/cli/test_error_formatter.py -v
```

Expected: FAIL - "ModuleNotFoundError: No module named 'descope_mgmt.cli.error_formatter'"

**Step 3: Write minimal implementation**

Create `src/descope_mgmt/cli/error_formatter.py`:

```python
"""Error formatting with recovery suggestions."""

from descope_mgmt.types.exceptions import (
    ApiError,
    ConfigError,
    ConfigurationError,
    DescopeMgmtError,
    ValidationError,
)


class ErrorFormatter:
    """Formats errors with helpful recovery suggestions."""

    @staticmethod
    def format(error: Exception) -> str:
        """Format an exception with recovery suggestions.

        Args:
            error: The exception to format

        Returns:
            Formatted error message with recovery suggestions
        """
        if isinstance(error, ApiError):
            return ErrorFormatter._format_api_error(error)
        elif isinstance(error, ConfigError):
            return ErrorFormatter._format_config_error(error)
        elif isinstance(error, ValidationError):
            return ErrorFormatter._format_validation_error(error)
        else:
            return str(error)

    @staticmethod
    def _format_api_error(error: ApiError) -> str:
        """Format API error with status-specific suggestions."""
        base_msg = str(error)

        if error.status_code == 401:
            return f"{base_msg}\n\n💡 Recovery suggestions:\n  • Verify DESCOPE_MANAGEMENT_KEY environment variable is set\n  • Check credentials at https://app.descope.com/settings/company\n  • Ensure the management key has not expired"

        elif error.status_code == 404:
            return f"{base_msg}\n\n💡 Recovery suggestions:\n  • List available resources with: descope-mgmt tenant list\n  • Check the resource ID for typos\n  • Verify you're using the correct project"

        elif error.status_code == 429:
            return f"{base_msg}\n\n💡 Recovery suggestions:\n  • Wait a few seconds and retry\n  • Reduce concurrent operations\n  • Contact Descope support to increase rate limits"

        else:
            return f"{base_msg}\n\n💡 Check the Descope API status or contact support if the issue persists."

    @staticmethod
    def _format_config_error(error: ConfigError) -> str:
        """Format configuration error with file-specific suggestions."""
        msg = str(error)

        if "not found" in msg.lower():
            return f"{msg}\n\n💡 Recovery suggestions:\n  • Create the config file based on: config/tenants.yaml.example\n  • Verify the file path is correct\n  • Check file permissions"

        elif "invalid yaml" in msg.lower():
            return f"{msg}\n\n💡 Recovery suggestions:\n  • Validate YAML syntax at https://www.yamllint.com/\n  • Check for proper indentation (use spaces, not tabs)\n  • Review config/tenants.yaml.example for correct structure"

        else:
            return f"{msg}\n\n💡 Check the configuration file structure and values."

    @staticmethod
    def _format_validation_error(error: ValidationError) -> str:
        """Format validation error with constraint-specific suggestions."""
        msg = str(error)

        if "duplicate" in msg.lower():
            return f"{msg}\n\n💡 Recovery suggestions:\n  • Ensure all tenant IDs are unique\n  • Ensure all domains are unique across tenants\n  • Review the configuration file for duplicates"

        elif "invalid" in msg.lower():
            return f"{msg}\n\n💡 Recovery suggestions:\n  • Check value format requirements\n  • Review field constraints in documentation\n  • Use config/tenants.yaml.example as a reference"

        else:
            return f"{msg}\n\n💡 Check the validation requirements and adjust your input."
```

**Step 4: Run test to verify it passes**

```bash
pytest tests/unit/cli/test_error_formatter.py -v
```

Expected: PASS - All 5 tests passing

**Step 5: Verify coverage**

```bash
pytest tests/unit/cli/test_error_formatter.py --cov=src/descope_mgmt/cli/error_formatter --cov-report=term-missing
```

Expected: 100% coverage

**Step 6: Commit**

```bash
git add src/descope_mgmt/cli/error_formatter.py tests/unit/cli/test_error_formatter.py
git commit -m "feat: add error formatter with recovery suggestions"
```

---

## Task 2: Integrate ErrorFormatter into CLI Commands

**Agent:** python-pro
**Files:**
- Modify: `src/descope_mgmt/cli/tenant_cmds.py`
- Modify: `src/descope_mgmt/cli/flow_cmds.py`
- Modify: `tests/unit/cli/test_tenant_cmds.py`

**Step 1: Write the failing test**

Add test to `tests/unit/cli/test_tenant_cmds.py`:

```python
from descope_mgmt.cli.error_formatter import ErrorFormatter
from descope_mgmt.types.exceptions import ApiError


def test_list_tenants_formats_api_errors(
    runner: CliRunner, fake_client: FakeDescopeClient
) -> None:
    """Test that API errors are formatted with recovery suggestions."""
    # Make fake client raise an authentication error
    fake_client.list_tenants_error = ApiError("Unauthorized", status_code=401)

    result = runner.invoke(
        cli_app,
        ["tenant", "list", "--project-id", "test", "--management-key", "test"],
    )

    assert result.exit_code == 1
    assert "Authentication failed" in result.output
    assert "DESCOPE_MANAGEMENT_KEY" in result.output
    assert "verify your credentials" in result.output.lower()
```

**Step 2: Run test to verify it fails**

```bash
pytest tests/unit/cli/test_tenant_cmds.py::test_list_tenants_formats_api_errors -v
```

Expected: FAIL - Error messages not formatted

**Step 3: Update tenant commands to use ErrorFormatter**

Modify `src/descope_mgmt/cli/tenant_cmds.py`:

```python
# Add import at top
from descope_mgmt.cli.error_formatter import ErrorFormatter

# Update each command's error handling (list, create, update, delete, sync)
# Example for list_tenants:

@tenant_app.command(name="list")
def list_tenants(
    ctx: typer.Context,
    project_id: Annotated[str | None, typer.Option(...)] = None,
    management_key: Annotated[str | None, typer.Option(...)] = None,
) -> None:
    """List all tenants in the project."""
    console = get_console()
    try:
        client = ClientFactory.create_client(project_id, management_key)
        tenants = client.list_tenants()
        # ... existing display logic ...
    except Exception as e:
        console.print(f"[red]Error:[/red] {ErrorFormatter.format(e)}")
        raise typer.Exit(1)
```

**Step 4: Update flow commands similarly**

Modify `src/descope_mgmt/cli/flow_cmds.py` to wrap errors with ErrorFormatter in all commands.

**Step 5: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_tenant_cmds.py::test_list_tenants_formats_api_errors -v
pytest tests/unit/cli/ -v
```

Expected: All CLI tests passing

**Step 6: Manual verification**

```bash
# Test with invalid credentials
DESCOPE_MANAGEMENT_KEY=invalid descope-mgmt tenant list
```

Expected: Formatted error with recovery suggestions displayed

**Step 7: Commit**

```bash
git add src/descope_mgmt/cli/tenant_cmds.py src/descope_mgmt/cli/flow_cmds.py tests/unit/cli/test_tenant_cmds.py
git commit -m "feat: integrate error formatter into CLI commands"
```

---

## Chunk Complete Checklist

- [ ] Task 1: ErrorFormatter utility created with 5 tests
- [ ] Task 2: ErrorFormatter integrated into CLI commands
- [ ] All tests passing (156+ total)
- [ ] Coverage maintained at 94%+
- [ ] Code committed (2 commits)
- [ ] Ready for Chunk 2
