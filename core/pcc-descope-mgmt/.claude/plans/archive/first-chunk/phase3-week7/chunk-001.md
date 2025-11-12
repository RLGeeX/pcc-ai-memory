# Chunk 1: Drift Detection Service

**Status:** pending
**Dependencies:** phase2-week6 complete
**Estimated Time:** 60 minutes

---

## Task 1: Create DriftDetector Service

**Files:**
- Create: `src/descope_mgmt/domain/services/drift_detector.py`
- Create: `tests/unit/domain/test_drift_detector.py`

**Step 1: Write failing tests**

Create `tests/unit/domain/test_drift_detector.py`:
```python
"""Tests for drift detection"""
import pytest
from descope_mgmt.domain.services.drift_detector import DriftDetector, DriftSeverity
from descope_mgmt.domain.models.state import TenantState, ProjectState
from descope_mgmt.domain.models.config import TenantConfig, DescopeConfig
from datetime import datetime


def test_detect_no_drift():
    """Should detect no drift when states match"""
    current_state = ProjectState(
        project_id="P2test",
        tenants=[TenantState(
            id="acme-corp",
            name="Acme Corp",
            domains=[],
            self_provisioning=False,
            custom_attributes={},
            created_at=datetime.now(),
            updated_at=datetime.now()
        )]
    )

    config = DescopeConfig(
        version="1.0",
        tenants=[TenantConfig(id="acme-corp", name="Acme Corp")]
    )

    detector = DriftDetector()
    drift = detector.detect_drift(current_state, config)

    assert not drift.has_drift
    assert len(drift.drifts) == 0


def test_detect_critical_drift():
    """Should detect critical drift for security settings"""
    current_state = ProjectState(
        project_id="P2test",
        tenants=[TenantState(
            id="acme-corp",
            name="Acme Corp",
            domains=["acme.com"],  # Domain changed
            self_provisioning=False,
            custom_attributes={},
            created_at=datetime.now(),
            updated_at=datetime.now()
        )]
    )

    config = DescopeConfig(
        version="1.0",
        tenants=[TenantConfig(id="acme-corp", name="Acme Corp", domains=[])]
    )

    detector = DriftDetector()
    drift = detector.detect_drift(current_state, config)

    assert drift.has_drift
    assert any(d.severity == DriftSeverity.CRITICAL for d in drift.drifts)
```

**Step 2: Implement drift detector**

Create `src/descope_mgmt/domain/services/drift_detector.py`:
```python
"""Drift detection service."""
from dataclasses import dataclass
from enum import Enum
from descope_mgmt.domain.models.state import ProjectState
from descope_mgmt.domain.models.config import DescopeConfig
from descope_mgmt.domain.services.diff_service import DiffService


class DriftSeverity(Enum):
    """Drift severity levels."""
    INFO = "info"
    WARNING = "warning"
    CRITICAL = "critical"


@dataclass(frozen=True)
class DriftItem:
    """Single drift item."""
    resource_type: str
    resource_id: str
    field: str
    current_value: any
    expected_value: any
    severity: DriftSeverity


@dataclass(frozen=True)
class DriftReport:
    """Drift detection report."""
    has_drift: bool
    drifts: list[DriftItem]

    def count_by_severity(self, severity: DriftSeverity) -> int:
        """Count drifts by severity."""
        return sum(1 for d in self.drifts if d.severity == severity)


class DriftDetector:
    """Detects configuration drift."""

    def __init__(self):
        self.diff_service = DiffService()

    def detect_drift(
        self,
        current_state: ProjectState,
        desired_config: DescopeConfig
    ) -> DriftReport:
        """Detect drift between current state and desired configuration.

        Args:
            current_state: Current state from API
            desired_config: Desired configuration

        Returns:
            Drift report
        """
        # Use diff service to calculate differences
        diff = self.diff_service.calculate_diff(current_state, desired_config)

        drifts = []
        for tenant_diff in diff.tenant_diffs:
            for field_diff in tenant_diff.field_diffs:
                # Classify severity
                severity = self._classify_severity(field_diff.field_name)

                drifts.append(DriftItem(
                    resource_type="tenant",
                    resource_id=tenant_diff.tenant_id,
                    field=field_diff.field_name,
                    current_value=field_diff.old_value,
                    expected_value=field_diff.new_value,
                    severity=severity
                ))

        return DriftReport(
            has_drift=len(drifts) > 0,
            drifts=drifts
        )

    def _classify_severity(self, field_name: str) -> DriftSeverity:
        """Classify drift severity based on field.

        Args:
            field_name: Field that drifted

        Returns:
            Severity level
        """
        # Critical: security-related fields
        if field_name in ["domains", "self_provisioning"]:
            return DriftSeverity.CRITICAL

        # Warning: important but not critical
        if field_name in ["name"]:
            return DriftSeverity.WARNING

        # Info: minor changes
        return DriftSeverity.INFO
```

**Step 3: Commit**

```bash
git add src/descope_mgmt/domain/services/drift_detector.py tests/unit/domain/test_drift_detector.py
git commit -m "feat: implement drift detection service"
```

---

## Chunk Complete Checklist

- [ ] DriftDetector service
- [ ] Severity classification
- [ ] 6 tests passing
