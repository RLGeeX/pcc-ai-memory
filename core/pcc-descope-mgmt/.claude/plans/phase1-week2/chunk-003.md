# Chunk 3: Diff Calculation Service

**Status:** pending
**Dependencies:** chunk-001, chunk-002
**Estimated Time:** 45-60 minutes

---

## Task 1: Create Diff Models

**Files:**
- Create: `src/descope_mgmt/domain/models/diff.py`
- Create: `tests/unit/domain/test_diff_models.py`

**Step 1: Write failing tests**

Create `tests/unit/domain/test_diff_models.py`:
```python
"""Tests for diff models"""
import pytest
from descope_mgmt.domain.models.diff import (
    ChangeType,
    FieldDiff,
    TenantDiff,
    ProjectDiff
)


def test_change_type_enum():
    """ChangeType should have expected values"""
    assert ChangeType.CREATE.value == "create"
    assert ChangeType.UPDATE.value == "update"
    assert ChangeType.DELETE.value == "delete"
    assert ChangeType.NO_CHANGE.value == "no_change"


def test_field_diff_creation():
    """FieldDiff should capture field changes"""
    diff = FieldDiff(
        field_name="name",
        old_value="Acme Corp",
        new_value="Acme Corporation"
    )
    assert diff.field_name == "name"
    assert diff.old_value == "Acme Corp"
    assert diff.new_value == "Acme Corporation"


def test_tenant_diff_create():
    """TenantDiff for new tenant"""
    diff = TenantDiff(
        tenant_id="acme-corp",
        change_type=ChangeType.CREATE,
        field_diffs=[]
    )
    assert diff.tenant_id == "acme-corp"
    assert diff.change_type == ChangeType.CREATE
    assert len(diff.field_diffs) == 0


def test_tenant_diff_update():
    """TenantDiff for updated tenant"""
    field_diffs = [
        FieldDiff("name", "Old Name", "New Name"),
        FieldDiff("domains", ["old.com"], ["old.com", "new.com"])
    ]
    diff = TenantDiff(
        tenant_id="acme-corp",
        change_type=ChangeType.UPDATE,
        field_diffs=field_diffs
    )
    assert diff.change_type == ChangeType.UPDATE
    assert len(diff.field_diffs) == 2


def test_project_diff_creation():
    """ProjectDiff should hold all resource diffs"""
    tenant_diffs = [
        TenantDiff("tenant1", ChangeType.CREATE, []),
        TenantDiff("tenant2", ChangeType.UPDATE, [
            FieldDiff("name", "Old", "New")
        ])
    ]
    diff = ProjectDiff(tenant_diffs=tenant_diffs, flow_diffs=[])
    assert len(diff.tenant_diffs) == 2
    assert diff.tenant_diffs[0].change_type == ChangeType.CREATE
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/domain/test_diff_models.py -v`

Expected: FAIL with import errors

**Step 3: Implement diff models**

Create `src/descope_mgmt/domain/models/diff.py`:
```python
"""Models for representing differences between states."""
from dataclasses import dataclass
from enum import Enum
from typing import Any


class ChangeType(Enum):
    """Type of change detected."""
    CREATE = "create"
    UPDATE = "update"
    DELETE = "delete"
    NO_CHANGE = "no_change"


@dataclass(frozen=True)
class FieldDiff:
    """Difference in a single field."""
    field_name: str
    old_value: Any
    new_value: Any


@dataclass(frozen=True)
class TenantDiff:
    """Difference between current and desired tenant state."""
    tenant_id: str
    change_type: ChangeType
    field_diffs: list[FieldDiff]


@dataclass(frozen=True)
class FlowDiff:
    """Difference between current and desired flow state."""
    flow_id: str
    change_type: ChangeType
    field_diffs: list[FieldDiff]


@dataclass(frozen=True)
class ProjectDiff:
    """All differences for a project."""
    tenant_diffs: list[TenantDiff]
    flow_diffs: list[FlowDiff]

    def has_changes(self) -> bool:
        """Check if there are any changes."""
        return any(
            d.change_type != ChangeType.NO_CHANGE
            for d in self.tenant_diffs + self.flow_diffs
        )

    def count_by_type(self, change_type: ChangeType) -> int:
        """Count changes of specific type."""
        return sum(
            1 for d in self.tenant_diffs + self.flow_diffs
            if d.change_type == change_type
        )
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/unit/domain/test_diff_models.py -v`

Expected: PASS (all 5 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/models/diff.py tests/unit/domain/test_diff_models.py
git commit -m "feat: add diff models for change detection"
```

---

## Task 2: Create Diff Service

**Files:**
- Create: `src/descope_mgmt/domain/services/diff_service.py`
- Create: `tests/unit/domain/test_diff_service.py`

**Step 1: Write failing tests**

Create `tests/unit/domain/test_diff_service.py`:
```python
"""Tests for diff calculation service"""
import pytest
from datetime import datetime
from descope_mgmt.domain.services.diff_service import DiffService
from descope_mgmt.domain.models.state import TenantState, ProjectState
from descope_mgmt.domain.models.config import TenantConfig, DescopeConfig
from descope_mgmt.domain.models.diff import ChangeType


def test_diff_new_tenant():
    """Should detect new tenant to create"""
    # Empty current state
    current = ProjectState(
        project_id="P2abc",
        tenants={},
        flows={},
        fetched_at=datetime.now()
    )

    # Desired config with one tenant
    desired = DescopeConfig(
        version="1.0",
        tenants=[
            TenantConfig(id="acme-corp", name="Acme Corporation")
        ]
    )

    service = DiffService()
    diff = service.calculate_diff(current, desired)

    assert len(diff.tenant_diffs) == 1
    assert diff.tenant_diffs[0].tenant_id == "acme-corp"
    assert diff.tenant_diffs[0].change_type == ChangeType.CREATE


def test_diff_no_changes():
    """Should detect when tenant unchanged"""
    now = datetime.now()
    current = ProjectState(
        project_id="P2abc",
        tenants={
            "acme-corp": TenantState(
                id="acme-corp",
                name="Acme Corporation",
                domains=["acme.com"],
                self_provisioning=True,
                custom_attributes={},
                created_at=now,
                updated_at=now
            )
        },
        flows={},
        fetched_at=now
    )

    desired = DescopeConfig(
        version="1.0",
        tenants=[
            TenantConfig(
                id="acme-corp",
                name="Acme Corporation",
                domains=["acme.com"],
                self_provisioning=True
            )
        ]
    )

    service = DiffService()
    diff = service.calculate_diff(current, desired)

    assert len(diff.tenant_diffs) == 1
    assert diff.tenant_diffs[0].change_type == ChangeType.NO_CHANGE


def test_diff_updated_tenant():
    """Should detect tenant updates"""
    now = datetime.now()
    current = ProjectState(
        project_id="P2abc",
        tenants={
            "acme-corp": TenantState(
                id="acme-corp",
                name="Acme Corp",  # Old name
                domains=["acme.com"],
                self_provisioning=False,  # Was False
                custom_attributes={},
                created_at=now,
                updated_at=now
            )
        },
        flows={},
        fetched_at=now
    )

    desired = DescopeConfig(
        version="1.0",
        tenants=[
            TenantConfig(
                id="acme-corp",
                name="Acme Corporation",  # New name
                domains=["acme.com"],
                self_provisioning=True  # Now True
            )
        ]
    )

    service = DiffService()
    diff = service.calculate_diff(current, desired)

    assert len(diff.tenant_diffs) == 1
    tenant_diff = diff.tenant_diffs[0]
    assert tenant_diff.change_type == ChangeType.UPDATE
    assert len(tenant_diff.field_diffs) == 2  # name and self_provisioning


def test_diff_deleted_tenant():
    """Should detect tenant to delete"""
    now = datetime.now()
    current = ProjectState(
        project_id="P2abc",
        tenants={
            "old-tenant": TenantState(
                id="old-tenant",
                name="Old Tenant",
                domains=[],
                self_provisioning=False,
                custom_attributes={},
                created_at=now,
                updated_at=now
            )
        },
        flows={},
        fetched_at=now
    )

    # Empty desired config
    desired = DescopeConfig(version="1.0", tenants=[])

    service = DiffService()
    diff = service.calculate_diff(current, desired)

    assert len(diff.tenant_diffs) == 1
    assert diff.tenant_diffs[0].tenant_id == "old-tenant"
    assert diff.tenant_diffs[0].change_type == ChangeType.DELETE
```

**Step 2: Run tests to verify they fail**

Run: `pytest tests/unit/domain/test_diff_service.py -v`

Expected: FAIL with import errors

**Step 3: Implement diff service**

Create `src/descope_mgmt/domain/services/diff_service.py`:
```python
"""Service for calculating differences between states."""
from descope_mgmt.domain.models.state import ProjectState, TenantState
from descope_mgmt.domain.models.config import DescopeConfig, TenantConfig
from descope_mgmt.domain.models.diff import (
    ProjectDiff,
    TenantDiff,
    FieldDiff,
    ChangeType
)
import structlog

logger = structlog.get_logger()


class DiffService:
    """Calculates differences between current and desired state.

    Example:
        >>> service = DiffService()
        >>> diff = service.calculate_diff(current_state, desired_config)
        >>> print(f"Changes: {diff.count_by_type(ChangeType.UPDATE)}")
    """

    def calculate_diff(
        self,
        current_state: ProjectState,
        desired_config: DescopeConfig
    ) -> ProjectDiff:
        """Calculate differences between current and desired state.

        Args:
            current_state: Current state from Descope API
            desired_config: Desired state from config file

        Returns:
            ProjectDiff with all detected changes
        """
        logger.debug("Calculating diff")

        tenant_diffs = self._diff_tenants(
            current_state.tenants,
            {t.id: t for t in desired_config.tenants}
        )

        # TODO: Flow diffs in Phase 3
        flow_diffs = []

        logger.info(
            "Diff calculated",
            creates=sum(1 for d in tenant_diffs if d.change_type == ChangeType.CREATE),
            updates=sum(1 for d in tenant_diffs if d.change_type == ChangeType.UPDATE),
            deletes=sum(1 for d in tenant_diffs if d.change_type == ChangeType.DELETE)
        )

        return ProjectDiff(tenant_diffs=tenant_diffs, flow_diffs=flow_diffs)

    def _diff_tenants(
        self,
        current: dict[str, TenantState],
        desired: dict[str, TenantConfig]
    ) -> list[TenantDiff]:
        """Calculate tenant differences."""
        diffs = []

        # Find new and updated tenants
        for tenant_id, desired_config in desired.items():
            if tenant_id not in current:
                # New tenant to create
                diffs.append(TenantDiff(
                    tenant_id=tenant_id,
                    change_type=ChangeType.CREATE,
                    field_diffs=[]
                ))
            else:
                # Check for updates
                current_state = current[tenant_id]
                field_diffs = self._compare_tenant_fields(current_state, desired_config)
                if field_diffs:
                    diffs.append(TenantDiff(
                        tenant_id=tenant_id,
                        change_type=ChangeType.UPDATE,
                        field_diffs=field_diffs
                    ))
                else:
                    diffs.append(TenantDiff(
                        tenant_id=tenant_id,
                        change_type=ChangeType.NO_CHANGE,
                        field_diffs=[]
                    ))

        # Find deleted tenants
        for tenant_id in current:
            if tenant_id not in desired:
                diffs.append(TenantDiff(
                    tenant_id=tenant_id,
                    change_type=ChangeType.DELETE,
                    field_diffs=[]
                ))

        return diffs

    def _compare_tenant_fields(
        self,
        current: TenantState,
        desired: TenantConfig
    ) -> list[FieldDiff]:
        """Compare individual fields between current and desired tenant."""
        field_diffs = []

        # Compare name
        if current.name != desired.name:
            field_diffs.append(FieldDiff("name", current.name, desired.name))

        # Compare domains
        if set(current.domains) != set(desired.domains):
            field_diffs.append(FieldDiff("domains", current.domains, desired.domains))

        # Compare self_provisioning
        if current.self_provisioning != desired.self_provisioning:
            field_diffs.append(FieldDiff(
                "self_provisioning",
                current.self_provisioning,
                desired.self_provisioning
            ))

        # Compare custom_attributes
        if current.custom_attributes != desired.custom_attributes:
            field_diffs.append(FieldDiff(
                "custom_attributes",
                current.custom_attributes,
                desired.custom_attributes
            ))

        return field_diffs
```

**Step 4: Run tests to verify they pass**

Run: `pytest tests/unit/domain/test_diff_service.py -v`

Expected: PASS (all 4 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/services/diff_service.py tests/unit/domain/test_diff_service.py
git commit -m "feat: add diff service for calculating state differences"
```

---

## Chunk Complete Checklist

- [ ] Diff models (ChangeType, FieldDiff, TenantDiff, ProjectDiff) - 5 tests
- [ ] DiffService with tenant comparison - 4 tests
- [ ] Total: 9 tests passing
- [ ] Detects creates, updates, deletes, no-change
- [ ] Field-level diff tracking
- [ ] All commits made
