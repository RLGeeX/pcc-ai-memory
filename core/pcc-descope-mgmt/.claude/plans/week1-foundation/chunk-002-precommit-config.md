# Chunk 2: Pre-commit Hooks and EditorConfig

**Status:** pending
**Dependencies:** chunk-001-project-setup
**Complexity:** simple
**Estimated Time:** 10 minutes
**Tasks:** 2

---

## Task 1: Configure Pre-commit Hooks

**Files:**
- Create: `.pre-commit-config.yaml`

**Step 1: Create pre-commit configuration**

```yaml
repos:
  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v4.5.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-added-large-files
      - id: check-merge-conflict
      - id: detect-private-key

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.1.6
    hooks:
      - id: ruff
        args: [--fix, --exit-non-zero-on-fix]
      - id: ruff-format

  - repo: https://github.com/pre-commit/mirrors-mypy
    rev: v1.7.1
    hooks:
      - id: mypy
        additional_dependencies:
          - pydantic>=2.0.0
          - types-pyyaml>=6.0.12
          - types-requests>=2.31.0
        args: [--strict]

  - repo: local
    hooks:
      - id: import-linter
        name: Check layer boundaries
        entry: lint-imports
        language: system
        pass_filenames: false
        always_run: true

      - id: pytest
        name: Run unit tests
        entry: pytest tests/unit
        language: system
        pass_filenames: false
        always_run: true
```

**Step 2: Install pre-commit hooks**

```bash
pre-commit install
```

Expected output: `pre-commit installed at .git/hooks/pre-commit`

**Step 3: Run pre-commit on all files**

```bash
pre-commit run --all-files
```

Expected output: All hooks pass (files are mostly empty right now)

**Step 4: Commit**

```bash
git add .pre-commit-config.yaml
git commit -m "feat: add pre-commit hooks for ruff, mypy, and import-linter"
```

---

## Task 2: Configure EditorConfig

**Files:**
- Modify: `.editorconfig` (if exists) or Create: `.editorconfig`

**Step 1: Create/update .editorconfig**

```ini
root = true

[*]
charset = utf-8
end_of_line = lf
insert_final_newline = true
trim_trailing_whitespace = true

[*.py]
indent_style = space
indent_size = 4
max_line_length = 88

[*.{yaml,yml}]
indent_style = space
indent_size = 2

[*.{json,toml}]
indent_style = space
indent_size = 2

[*.md]
trim_trailing_whitespace = false
```

**Step 2: Commit**

```bash
git add .editorconfig
git commit -m "feat: add editorconfig for consistent formatting"
```

---

## Chunk Complete Checklist

- [ ] Pre-commit hooks configured with ruff, mypy, import-linter
- [ ] Pre-commit hooks installed
- [ ] EditorConfig created
- [ ] All pre-commit checks pass
- [ ] 2 commits created
- [ ] Ready for chunk 3
