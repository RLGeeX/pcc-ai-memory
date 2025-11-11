# Chunk 1: Flow Template System

**Status:** pending
**Dependencies:** phase1-week4 complete
**Estimated Time:** 60 minutes

---

## Task 1: Create Flow Template Model

**Files:**
- Create: `src/descope_mgmt/domain/models/template.py`
- Create: `tests/unit/domain/test_template.py`

**Step 1: Write failing tests**

Create `tests/unit/domain/test_template.py`:
```python
"""Tests for flow templates"""
import pytest
from descope_mgmt.domain.models.template import FlowTemplate


def test_template_variable_substitution():
    """Should substitute variables in template"""
    template = FlowTemplate(
        template_id="sign-up-template",
        flow_data={
            "flow_id": "${TENANT_ID}-sign-up",
            "name": "Sign Up for ${TENANT_NAME}"
        },
        variables=["TENANT_ID", "TENANT_NAME"]
    )

    rendered = template.render({
        "TENANT_ID": "acme-corp",
        "TENANT_NAME": "Acme Corporation"
    })

    assert rendered["flow_id"] == "acme-corp-sign-up"
    assert rendered["name"] == "Sign Up for Acme Corporation"
```

**Step 2: Implement template model**

Create `src/descope_mgmt/domain/models/template.py`:
```python
"""Flow template models."""
from dataclasses import dataclass
from typing import Any
from jinja2 import Template as Jinja2Template
import json


@dataclass(frozen=True)
class FlowTemplate:
    """Flow template with variable substitution."""
    template_id: str
    flow_data: dict[str, Any]
    variables: list[str]

    def render(self, context: dict[str, str]) -> dict[str, Any]:
        """Render template with variable substitution.

        Args:
            context: Variable values

        Returns:
            Rendered flow data
        """
        # Convert to JSON string for template rendering
        template_str = json.dumps(self.flow_data)

        # Replace variables
        for var_name, var_value in context.items():
            template_str = template_str.replace(f"${{{var_name}}}", var_value)

        return json.loads(template_str)
```

**Step 3: Run tests and commit**

```bash
pytest tests/unit/domain/test_template.py -v
git add src/descope_mgmt/domain/models/template.py tests/unit/domain/test_template.py
git commit -m "feat: add flow template with variable substitution"
```

---

## Chunk Complete Checklist

- [ ] FlowTemplate model
- [ ] Variable substitution
- [ ] 6 tests passing
