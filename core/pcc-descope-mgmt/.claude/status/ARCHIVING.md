# Archiving Guide

Documentation for maintaining the `.claude/status/` directory structure as the project grows.

## When to Archive

**Triggers:**
- `current-progress.md` exceeds ~500 lines
- Current progress spans more than 3 weeks
- A phase or major week is complete (e.g., Week 2, 4, 6, 8, 9, 10)

**Goal:** Keep recent 2-3 weeks in `current-progress.md`, move older content to `archives/`

## Archive Process

### 1. Identify Content to Archive

Determine which weeks/phases are complete and should be moved:

```bash
# Check current file size
wc -l .claude/status/current-progress.md

# Find section start lines
grep -n "^## 2025-" .claude/status/current-progress.md
```

**Example:** After Week 4 completes, archive Weeks 3-4 (keep only Week 5+ in current-progress.md)

### 2. Create Archive File

**Naming convention:** `phase{N}-week{S}-{E}.md` or `phase{N}-week{N}.md`

```bash
cd .claude/status

# Extract content (adjust line numbers based on grep output)
head -n 500 current-progress.md > archives/phase1-weeks3-4.md
```

**Add metadata header:**

```markdown
# Phase N: [Name] Archive (COMPLETE)

**Period:** YYYY-MM-DD to YYYY-MM-DD
**Status:** ✅ Complete
**Git Tag:** `weekN-complete` (commit: [hash])

## Summary

[1-2 paragraph overview]

**Deliverables:**
- [Key deliverable 1]
- [Key deliverable 2]

**Metrics:**
- Tests: X → Y (+Z)
- Coverage: X% → Y%
- Commits: N
- Time: N hours

## Key Decisions

1. **[Decision]:** [Explanation]

---

[Original content follows]
```

### 3. Trim current-progress.md

Remove archived content, keep only recent weeks:

```bash
# Remove first 500 lines (adjust as needed)
tail -n +501 current-progress.md > current-progress-new.md
mv current-progress-new.md current-progress.md
```

**Add navigation header:**

```bash
cat > header.tmp << 'EOF'
# Project Progress History (Recent)

**Navigation:** [Status Hub](./README.md) | [Timeline](./indexes/timeline.md) | [Topics](./indexes/topics.md) | [Metrics](./indexes/metrics.md)

This file contains recent progress (Weeks X-Y). For historical phases:
- [Phase 1: Weeks 1-2](./archives/phase1-weeks1-2.md) - Complete
- [Phase 1: Weeks 3-4](./archives/phase1-weeks3-4.md) - Complete

## Current Status

**Week:** X of 10
**Tests:** N passing (X% coverage)
**Commits:** N total

---

EOF

cat header.tmp current-progress.md > current-progress-tmp.md
mv current-progress-tmp.md current-progress.md
rm header.tmp
```

### 4. Update README.md

Add new archive entry:

```markdown
#### [Weeks 3-4: Configuration & Real API](./archives/phase1-weeks3-4.md) ✅ Complete
**Period:** 2025-11-17 to 2025-11-20
**Status:** ✅ Complete
**Git Tag:** `week4-complete` (commit: [hash])

**Deliverables:**
- Client factory pattern
- YAML tenant configuration
- Real Descope API integration
- Backup and restore functionality

**Metrics:**
- Tests: 109 → 145
- Coverage: 91% → 92%
- Commits: 12
- Time: 5 hours
```

Update "Current Status" section with new metrics.

### 5. Update Indexes (Optional)

#### timeline.md

Add new entries for archived weeks:

```markdown
## 2025-11-20

### Week 4 Complete
- **Session ID:** Claude-2025-11-20-XX-XX
- **Focus:** [summary]
- **Archive:** [phase1-weeks3-4.md](../archives/phase1-weeks3-4.md#2025-11-20)
```

#### topics.md

Add cross-references to new archive:

```markdown
### New Feature
- **Implementation:** Week 4
- **Archive:** [phase1-weeks3-4.md](../archives/phase1-weeks3-4.md#feature-name)
```

#### metrics.md

Update dashboard with completed phase metrics.

### 6. Verify Results

```bash
# Check file sizes
wc -l .claude/status/*.md .claude/status/archives/*.md

# Expected:
# - current-progress.md: <300 lines
# - New archive: ~500 lines
# - README.md: updated
```

## Archive Organization

Expected structure after each phase:

```
.claude/status/archives/
├── phase1-weeks1-2.md     # Design + Foundation (DONE - 905 lines)
├── phase1-weeks3-4.md     # Config + Real API (after Week 4)
├── phase2-weeks5-6.md     # Advanced features (after Week 6)
├── phase3-weeks7-8.md     # Production readiness (after Week 8)
├── phase4-week9.md        # Internal deployment (after Week 9)
└── phase5-week10.md       # Documentation (after Week 10)
```

## Maintenance Schedule

| Frequency | Task |
|-----------|------|
| **Daily/Session** | Append `brief.md` to `current-progress.md` |
| **Bi-weekly** | Archive completed weeks at phase completion |
| **Weekly (optional)** | Update indexes with recent progress |
| **Project end** | Create final archive with all content |

## Quick Commands

**Check if archiving needed:**
```bash
wc -l .claude/status/current-progress.md
# If > 500 lines, consider archiving
```

**Find week boundaries:**
```bash
grep -n "^## 2025-" .claude/status/current-progress.md
```

**Archive and trim (template):**
```bash
cd .claude/status

# 1. Create archive
head -n LINE_NUM current-progress.md > archives/phaseN-weekX-Y.md

# 2. Trim current
tail -n +LINE_NUM current-progress.md > current-progress-new.md

# 3. Add header (create header.tmp first)
cat header.tmp current-progress-new.md > current-progress.md
rm header.tmp current-progress-new.md

# 4. Update README.md (manually)

# 5. Verify
wc -l current-progress.md archives/*.md
```

## Token Impact

**Before archiving:** ~22,000 tokens (1000+ lines)
**After archiving:** ~6,000 tokens (250-300 lines)
**Savings:** ~73% reduction in normal token usage

## Notes

- Archives preserve full historical detail
- Indexes provide cross-references to archives
- README.md is the navigation hub
- `current-progress.md` stays lean and recent
- Archives loaded only when historical context needed
