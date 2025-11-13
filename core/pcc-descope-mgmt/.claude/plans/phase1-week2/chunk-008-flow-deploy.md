# Chunk 8: Flow Deploy Command

**Status:** pending
**Dependencies:** chunk-007-flow-list
**Complexity:** medium
**Estimated Time:** 45 minutes
**Tasks:** 3

---

## Task 1: Add Deploy Method to FlowManager

**Files:**
- Modify: `src/descope_mgmt/domain/flow_manager.py`
- Modify: `tests/unit/domain/test_flow_manager.py`

**Step 1: Write failing tests**

Add to `tests/unit/domain/test_flow_manager.py`:
```python
def test_deploy_flow() -> None:
    """Test deploy_flow accepts flow configuration."""
    client = FakeDescopeClient()
    manager = FlowManager(client)

    flow_config = FlowConfig(
        id="test-flow", name="Test Flow", flow_type="sign-up"
    )

    # For Week 2, deploy just returns the config
    result = manager.deploy_flow(flow_config)
    assert result is not None
    assert result.id == "test-flow"


def test_deploy_flow_validates_config() -> None:
    """Test deploy_flow validates flow configuration."""
    client = FakeDescopeClient()
    manager = FlowManager(client)

    # Valid flow types: sign-up, sign-in, step-up, forgot-password
    flow_config = FlowConfig(
        id="test-flow", name="Test Flow", flow_type="sign-up"
    )

    result = manager.deploy_flow(flow_config)
    assert result.flow_type == "sign-up"
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/domain/test_flow_manager.py::test_deploy_flow -v
```
Expected: FAIL with "AttributeError: 'FlowManager' object has no attribute 'deploy_flow'"

**Step 3: Implement deploy method**

Add to `src/descope_mgmt/domain/flow_manager.py`:
```python
    def deploy_flow(self, flow: FlowConfig) -> FlowConfig:
        """Deploy a flow configuration.

        Args:
            flow: Flow configuration to deploy

        Returns:
            Deployed flow configuration

        Raises:
            DescopeApiError: If deployment fails
        """
        # TODO: In Week 4, implement actual API calls for flow deployment
        # For Week 2, we're just setting up the command structure
        # Validate flow type
        valid_types = {"sign-up", "sign-in", "step-up", "forgot-password"}
        if flow.flow_type not in valid_types:
            from descope_mgmt.types.exceptions import ValidationError

            raise ValidationError(
                f"Invalid flow type: {flow.flow_type}. Must be one of {valid_types}"
            )

        return flow
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/domain/test_flow_manager.py -v
```
Expected: PASS (5 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/domain/flow_manager.py tests/unit/domain/test_flow_manager.py
git commit -m "feat: add deploy_flow method to FlowManager"
```

---

## Task 2: Create Flow Deploy Command

**Files:**
- Modify: `src/descope_mgmt/cli/flow_cmds.py`
- Modify: `src/descope_mgmt/cli/main.py:51`
- Modify: `tests/unit/cli/test_flow_cmds.py`

**Step 1: Write failing tests**

Add to `tests/unit/cli/test_flow_cmds.py`:
```python
def test_flow_deploy_shows_help() -> None:
    """Test that flow deploy command shows help."""
    runner = CliRunner()
    result = runner.invoke(cli, ["flow", "deploy", "--help"])
    assert result.exit_code == 0
    assert "Deploy a flow" in result.output


def test_flow_deploy_with_required_args() -> None:
    """Test flow deploy with required arguments."""
    runner = CliRunner()
    result = runner.invoke(
        cli,
        [
            "--dry-run",
            "flow",
            "deploy",
            "--id",
            "test-flow",
            "--name",
            "Test Flow",
            "--type",
            "sign-up",
        ],
    )

    assert result.exit_code == 0
    assert "DRY RUN" in result.output or "test-flow" in result.output


def test_flow_deploy_invalid_type_shows_error() -> None:
    """Test flow deploy with invalid type shows error."""
    runner = CliRunner()
    result = runner.invoke(
        cli,
        [
            "--dry-run",
            "flow",
            "deploy",
            "--id",
            "test-flow",
            "--name",
            "Test Flow",
            "--type",
            "invalid-type",
        ],
    )

    # Should fail validation
    assert result.exit_code != 0
```

**Step 2: Run tests to verify they fail**

```bash
pytest tests/unit/cli/test_flow_cmds.py::test_flow_deploy_shows_help -v
```
Expected: FAIL with "No such command 'deploy'"

**Step 3: Implement flow deploy command**

Add to `src/descope_mgmt/cli/flow_cmds.py`:
```python
@click.command()
@click.option("--id", "flow_id", required=True, help="Flow ID (unique identifier)")
@click.option("--name", required=True, help="Flow display name")
@click.option(
    "--type",
    "flow_type",
    required=True,
    type=click.Choice(["sign-up", "sign-in", "step-up", "forgot-password"]),
    help="Flow type",
)
@click.option("--tenant", help="Associate flow with tenant ID")
@click.pass_context
def deploy_flow(
    ctx: click.Context,
    flow_id: str,
    name: str,
    flow_type: str,
    tenant: str | None,
) -> None:
    """Deploy a flow configuration to the current project."""
    console = get_console()
    verbose = ctx.obj.get("verbose", False)
    dry_run = ctx.obj.get("dry_run", False)

    # Build flow config
    from descope_mgmt.types.flow import FlowConfig

    flow_config = FlowConfig(
        id=flow_id,
        name=name,
        flow_type=flow_type,  # type: ignore[arg-type]
    )

    if verbose:
        console.log(f"Deploying flow: {flow_config.model_dump_json(indent=2)}")

    if dry_run:
        console.print("[yellow]DRY RUN: Would deploy flow[/yellow]")
        console.print(f"  ID: {flow_id}")
        console.print(f"  Name: {name}")
        console.print(f"  Type: {flow_type}")
        if tenant:
            console.print(f"  Tenant: {tenant}")
        return

    # Initialize services
    rate_limiter = DescopeRateLimiter()
    client = DescopeClient(
        project_id="placeholder",
        management_key="placeholder",
        rate_limiter=rate_limiter,
    )
    manager = FlowManager(client)

    # Deploy flow
    try:
        result = manager.deploy_flow(flow_config)
        console.print(f"[green]✓[/green] Deployed flow: {result.id}")
    except Exception as e:
        console.print(f"[red]✗[/red] Failed to deploy flow: {e}")
        raise click.Abort()
```

Update `src/descope_mgmt/cli/main.py`:
```python
from descope_mgmt.cli.flow_cmds import deploy_flow, list_flows

# Register flow commands
flow.add_command(list_flows, name="list")
flow.add_command(deploy_flow, name="deploy")
```

**Step 4: Run tests to verify they pass**

```bash
pytest tests/unit/cli/test_flow_cmds.py -v
```
Expected: PASS (6 tests)

**Step 5: Commit**

```bash
git add src/descope_mgmt/cli/flow_cmds.py src/descope_mgmt/cli/main.py tests/unit/cli/test_flow_cmds.py
git commit -m "feat: add flow deploy command with validation"
```

---

## Task 3: Verify Week 2 Complete

**Files:**
- None (verification and tagging)

**Step 1: Manual testing all commands**

```bash
# Test all tenant commands
descope-mgmt tenant list
descope-mgmt --help tenant
descope-mgmt tenant --help

# Test all flow commands
descope-mgmt flow list
descope-mgmt --help flow
descope-mgmt flow --help

# Test global options
descope-mgmt --verbose --dry-run tenant list
descope-mgmt --config test.yaml --help
```
Expected: All commands work correctly

**Step 2: Run complete test suite**

```bash
pytest tests/ -v --cov=src/descope_mgmt --cov-report=html --cov-report=term-missing
```
Expected: 100+ tests passing, >90% coverage

**Step 3: Run all quality checks**

```bash
mypy src/ --strict
ruff check .
ruff format --check .
lint-imports
pre-commit run --all-files
```
Expected: All checks pass

**Step 4: Review coverage report**

```bash
# Open HTML coverage report
open htmlcov/index.html  # or xdg-open on Linux
```
Expected: All modules >85% coverage

**Step 5: Create Week 2 completion tag**

```bash
git tag -a week2-complete -m "Week 2: CLI Commands Complete

- Global CLI options (--verbose, --dry-run, --config)
- Rich console output with tables
- Tenant commands: list, create, update, delete
- Flow commands: list, deploy
- TenantManager and FlowManager services
- 100+ tests passing (>90% coverage)
- All quality checks passing"

git push origin week2-complete
```

**Step 6: Update status files**

Update `.claude/status/brief.md` with Week 2 completion summary.

---

## Chunk Complete Checklist

- [ ] Flow deploy command implemented
- [ ] Flow type validation working
- [ ] Dry-run mode functional
- [ ] All commands tested manually
- [ ] Full test suite passing (100+ tests)
- [ ] All quality checks passing
- [ ] Coverage >90%
- [ ] Git tag created: `week2-complete`
- [ ] **CHECKPOINT 2**: Week 2 complete
- [ ] Status files updated
- [ ] Ready for Week 3 planning
