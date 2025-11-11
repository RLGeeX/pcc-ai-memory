# Phase 3 Week 7 Implementation Plan

**Feature**: Drift Detection - Detect configuration drift, reporting, notifications
**Total Chunks**: 4
**Target**: 15+ tests passing by end of week
**Estimated Time**: 5-6 hours total
**Prerequisites**: Phase 2 Week 6 complete (196 tests passing)

---

## Chunk Overview

### Chunk 1: Drift Detection Service (60 min)
**Dependencies**: phase2-week6 complete
**Tasks**: 3 | **Tests**: 6

- DriftDetector service
- Compare current state vs config
- Drift severity classification
- DriftReport model

**Deliverables**:
- ✅ DriftDetector implementation
- ✅ Severity classification (critical, warning, info)
- ✅ 6 tests passing

---

### Chunk 2: Drift Detect Command (45-60 min)
**Dependencies**: chunk-001
**Tasks**: 2 | **Tests**: 4

- drift detect command
- Rich diff display for drift
- Severity-based coloring
- Summary statistics

**Deliverables**:
- ✅ drift detect command working
- ✅ Rich formatted drift report
- ✅ 4 integration tests passing

---

### Chunk 3: Drift Report Generation (45 min)
**Dependencies**: chunk-001, chunk-002
**Tasks**: 2 | **Tests**: 3

- drift report command
- Export to JSON/HTML/Markdown
- Historical drift tracking
- Trend analysis

**Deliverables**:
- ✅ drift report with multiple formats
- ✅ Historical tracking
- ✅ 3 tests passing

---

### Chunk 4: Scheduled Drift Checks (Optional) (30 min)
**Dependencies**: chunk-001, chunk-002, chunk-003
**Tasks**: 1 | **Tests**: 2

- drift watch command (background monitoring)
- Configurable check interval
- Notification on drift detected
- Email/webhook integration

**Deliverables**:
- ✅ drift watch command (optional)
- ✅ Notification system hooks
- ✅ 2 tests passing
- ✅ **Phase 3 Week 7 COMPLETE**

---

## Total Test Count: 15 Tests

- Chunk 1: 6 tests (drift detector)
- Chunk 2: 4 tests (drift detect command)
- Chunk 3: 3 tests (report generation)
- Chunk 4: 2 tests (scheduled checks)

**Total: 15 tests** (meets target)

---

## Key Features

### Drift Detection

**drift detect**:
```bash
descope-mgmt drift detect --config descope.yaml
descope-mgmt drift detect --config descope.yaml --severity critical
```
- Compare current state with desired config
- Identify configuration drift
- Color-coded by severity:
  - 🔴 Critical (security-related, SSO config)
  - 🟡 Warning (deprecated settings)
  - 🔵 Info (minor differences)

**drift report**:
```bash
descope-mgmt drift report --output drift-report.html
descope-mgmt drift report --format markdown --output report.md
```
- Generate drift reports in multiple formats
- Historical drift tracking
- Trend analysis over time

**drift watch** (optional):
```bash
descope-mgmt drift watch --interval 3600 --notify email
```
- Background monitoring for drift
- Configurable check interval
- Email/webhook notifications

### Drift Severity

- **CRITICAL**: Security settings, SSO config, API keys
- **WARNING**: Deprecated features, suboptimal settings
- **INFO**: Minor differences, cosmetic changes

---

## Success Criteria

**Phase 3 Week 7 is complete when:**

- ✅ All 4 chunks completed
- ✅ 15+ tests passing (plan has 15)
- ✅ DriftDetector service working
- ✅ drift detect command functional
- ✅ drift report generation operational
- ✅ drift watch (optional) implemented
- ✅ mypy type checking passes
- ✅ ruff formatting/linting passes
- ✅ All code committed with conventional commits

**Expected deliverables**:
- Drift detection service
- drift detect command with severity classification
- Report generation (JSON/HTML/Markdown)
- Optional scheduled checks
- 15 tests passing
- ~400 lines of code + tests

---

## What's NOT in Week 7

Deferred to future weeks:
- ❌ Advanced error recovery → Week 8
- ❌ Performance optimization → Week 9
- ❌ Documentation → Week 10

---

**Status**: Ready for execution after Week 6 complete
**Next Session**: Execute `/cc-unleashed:plan-next` in `.claude/plans/phase3-week7/`
