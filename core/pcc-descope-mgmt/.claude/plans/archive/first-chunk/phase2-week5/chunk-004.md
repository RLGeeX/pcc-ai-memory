# Chunk 4: Flow Validation & Testing

**Status:** pending
**Dependencies:** chunk-003
**Estimated Time:** 45 minutes

---

## Task 1: Implement Flow Validation

**Files:**
- Create: `src/descope_mgmt/domain/validators/flow_validator.py`
- Create: `tests/unit/domain/test_flow_validator.py`

**Step 1: Write tests**

Create `tests/unit/domain/test_flow_validator.py`:
```python
"""Tests for flow validation"""
import pytest
from descope_mgmt.domain.validators.flow_validator import FlowValidator
from descope_mgmt.types.exceptions import ValidationError


def test_validate_flow_structure():
    """Should validate flow structure"""
    validator = FlowValidator()

    valid_flow = {
        "flow_id": "sign-up",
        "screens": [{"id": "email"}]
    }

    # Should not raise
    validator.validate(valid_flow)


def test_validate_flow_missing_id():
    """Should reject flow without ID"""
    validator = FlowValidator()

    invalid_flow = {
        "screens": []
    }

    with pytest.raises(ValidationError, match="flow_id"):
        validator.validate(invalid_flow)
```

**Step 2: Implement validator**

Create `src/descope_mgmt/domain/validators/flow_validator.py`:
```python
"""Flow validation."""
from descope_mgmt.types.exceptions import ValidationError


class FlowValidator:
    """Validates flow structure."""

    def validate(self, flow_data: dict) -> None:
        """Validate flow data structure."""
        if 'flow_id' not in flow_data:
            raise ValidationError("Flow must have flow_id")

        if 'screens' not in flow_data:
            raise ValidationError("Flow must have screens")
```

**Step 3: Commit**

```bash
git add src/descope_mgmt/domain/validators/flow_validator.py tests/unit/domain/test_flow_validator.py
git commit -m "feat: add flow validation"
```

---

## Chunk Complete Checklist

- [ ] FlowValidator
- [ ] 3 tests passing
