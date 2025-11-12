# Chunk 5: Environment Variable Substitution

**Status:** pending
**Dependencies:** chunk-001, chunk-002
**Estimated Time:** 30 minutes

---

## Task 1: Environment Variable Substitution

**Files:**
- Create: `src/descope_mgmt/utils/env_vars.py`
- Create: `tests/unit/utils/test_env_vars.py`

**Step 1: Write failing tests**

Create `tests/unit/utils/test_env_vars.py`:
```python
"""Tests for environment variable substitution"""
import os
import pytest
from descope_mgmt.utils.env_vars import substitute_env_vars


def test_substitute_simple_string():
    """Simple string substitution"""
    os.environ["TEST_VAR"] = "test_value"
    result = substitute_env_vars("${TEST_VAR}")
    assert result == "test_value"


def test_substitute_in_middle():
    """Substitution in middle of string"""
    os.environ["USER"] = "testuser"
    result = substitute_env_vars("Hello ${USER}, welcome!")
    assert result == "Hello testuser, welcome!"


def test_substitute_multiple_vars():
    """Multiple variable substitutions"""
    os.environ["HOST"] = "localhost"
    os.environ["PORT"] = "5432"
    result = substitute_env_vars("${HOST}:${PORT}")
    assert result == "localhost:5432"


def test_no_substitution_needed():
    """Strings without variables remain unchanged"""
    result = substitute_env_vars("plain string")
    assert result == "plain string"


def test_substitute_in_dict():
    """Recursive substitution in dictionaries"""
    os.environ["PROJECT_ID"] = "P2abc123"
    data = {
        "project_id": "${PROJECT_ID}",
        "nested": {
            "value": "${PROJECT_ID}"
        }
    }
    result = substitute_env_vars(data)
    assert result["project_id"] == "P2abc123"
    assert result["nested"]["value"] == "P2abc123"


def test_substitute_in_list():
    """Substitution in lists"""
    os.environ["DOMAIN1"] = "example.com"
    data = ["${DOMAIN1}", "static.com"]
    result = substitute_env_vars(data)
    assert result == ["example.com", "static.com"]


def test_missing_env_var_raises():
    """Missing environment variable should raise error"""
    from descope_mgmt.types.exceptions import ConfigurationError
    with pytest.raises(ConfigurationError) as exc_info:
        substitute_env_vars("${NONEXISTENT_VAR}")
    assert "NONEXISTENT_VAR" in str(exc_info.value)
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/utils/test_env_vars.py -v`

Expected: FAIL with import errors

**Step 3: Implement env var substitution**

Create `src/descope_mgmt/utils/env_vars.py`:
```python
"""Environment variable substitution utilities."""
import os
import re
from typing import Any
from descope_mgmt.types.exceptions import ConfigurationError


def substitute_env_vars(value: Any) -> Any:
    """Recursively substitute environment variables in strings.

    Supports ${VAR_NAME} syntax.

    Args:
        value: String, dict, list, or other value to process

    Returns:
        Value with environment variables substituted

    Raises:
        ConfigurationError: If environment variable not found

    Example:
        >>> os.environ["PROJECT_ID"] = "P2abc"
        >>> substitute_env_vars("${PROJECT_ID}")
        'P2abc'
    """
    if isinstance(value, str):
        return _substitute_string(value)
    elif isinstance(value, dict):
        return {k: substitute_env_vars(v) for k, v in value.items()}
    elif isinstance(value, list):
        return [substitute_env_vars(item) for item in value]
    else:
        return value


def _substitute_string(text: str) -> str:
    """Substitute environment variables in a string."""
    pattern = re.compile(r'\$\{([A-Z_][A-Z0-9_]*)\}')

    def replace_var(match: re.Match[str]) -> str:
        var_name = match.group(1)
        value = os.environ.get(var_name)
        if value is None:
            raise ConfigurationError(
                f"Environment variable '{var_name}' not found",
                details={"variable": var_name}
            )
        return value

    return pattern.sub(replace_var, text)
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/unit/utils/test_env_vars.py -v`

Expected: PASS (all 7 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/utils/env_vars.py tests/unit/utils/test_env_vars.py
git commit -m "feat: add environment variable substitution"
```

---

## Chunk Complete Checklist

- [ ] Environment variable substitution implemented
- [ ] 7 tests passing
- [ ] Supports ${VAR_NAME} syntax
- [ ] Recursive substitution in dicts and lists
- [ ] Raises ConfigurationError for missing vars
- [ ] Commit made
