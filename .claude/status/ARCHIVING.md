# Archiving Guide

Documentation for maintaining the `.claude/status/` directory structure as the PCC project grows.

## When to Archive

**Triggers:**
- `current-progress.md` exceeds ~500 lines (or ~15,000 tokens)
- Current progress spans more than 2-3 weeks
- A phase or major milestone is complete (e.g., Phase 3, Phase 6, Phase 7)

**Goal:** Keep recent 2-3 weeks in `current-progress.md`, move older content to `archives/`

## Archive Process

### 1. Identify Content to Archive

Determine which phases/weeks are complete and should be moved:

```bash
# Check current file size
wc -l .claude/status/current-progress.md

# Find section start lines
grep -n "^## " .claude/status/current-progress.md | head -30
```

**Example:** After Phase 6 completes, archive Phases 2-3-6 initial work (keep only recent Phase 4/7 planning)

### 2. Create Archive File

**Naming convention:** `phases-{N}-{M}-{name}.md` or `phase-{N}-{name}.md`

```bash
cd .claude/status

# Extract content (adjust line numbers based on grep output)
head -n 1643 current-progress.md > archives/phases-2-3-6-initial.md
```

**Add metadata header:**

```markdown
# Phase N: [Name] Archive (COMPLETE)

**Period:** YYYY-MM-DD to YYYY-MM-DD
**Status:** ✅ Complete

## Summary

[1-2 paragraph overview]

**Deliverables:**
- [Key deliverable 1]
- [Key deliverable 2]

**Metrics:**
- Infrastructure: X resources deployed
- Commits: N
- Time: N hours/days

## Key Decisions

1. **[Decision]:** [Explanation]

---

# Original Progress Content

[Original content follows]
```

### 3. Trim current-progress.md

Remove archived content, keep only recent weeks:

```bash
# Remove first N lines (adjust as needed)
tail -n +1644 current-progress.md > current-progress-new.md
```

**Add navigation header:**

```bash
cat > header.tmp << 'EOF'
# Project Progress History (Recent)

**Navigation:** [Status Hub](./README.md) | [Archives](./archives/)

This file contains recent progress (Recent weeks). For historical phases:
- [Phase X: Name](./archives/phase-x-name.md) - Complete

## Current Status

**Phase:** [Current phase]
**Infrastructure:** [Current state]
**Next:** [Next steps]

---

EOF

cat header.tmp current-progress-new.md > current-progress.md
rm header.tmp current-progress-new.md
```

### 4. Update README.md

Add new archive entry:

```markdown
### [Phases 2-3-6 Initial Implementation](./archives/phases-2-3-6-initial.md) ✅ Complete
**Period:** 2025-10-22 to 2025-11-18
**Status:** ✅ Complete

**Deliverables:**
- AlloyDB cluster deployed
- GKE Autopilot cluster (nonprod)
- ArgoCD with GitOps patterns
- Terraform modules (gke-autopilot v0.1.0)

**Metrics:**
- Infrastructure: 3 phases complete
- Commits: ~50
- Time: ~40 hours
```

Update "Current Status" section with new metrics.

### 5. Verify Results

```bash
# Check file sizes
wc -l .claude/status/*.md .claude/status/archives/*.md

# Expected:
# - current-progress.md: <500 lines
# - New archive: ~1600+ lines
# - README.md: updated
```

## Archive Organization

Expected structure:

```
.claude/status/archives/
├── phases-2-3-6-initial.md     # Initial infrastructure (Oct-Nov)
├── phase-4-gke-prod.md         # Production GKE cluster (future)
├── phase-7-argocd-prod.md      # ArgoCD production (future)
└── ...
```

## Maintenance Schedule

| Frequency | Task |
|-----------|------|
| **Daily/Session** | Append `brief.md` summary to `current-progress.md` |
| **After Major Phase** | Archive completed phase at milestone completion |
| **Monthly (optional)** | Create indexes for navigation |
| **Project milestones** | Create comprehensive archive summaries |

## Quick Commands

**Check if archiving needed:**
```bash
wc -l .claude/status/current-progress.md
# If > 500 lines, consider archiving
```

**Find phase boundaries:**
```bash
grep -n "^## " .claude/status/current-progress.md
```

**Archive and trim (template):**
```bash
cd .claude/status

# 1. Create archive
head -n LINE_NUM current-progress.md > archives/phase-name.md

# 2. Add header to archive (create header content first)
cat header.tmp archives/phase-name.md > archives/temp.md
mv archives/temp.md archives/phase-name.md
rm header.tmp

# 3. Trim current
tail -n +LINE_NUM current-progress.md > current-progress-new.md

# 4. Add header (create header.tmp first)
cat header.tmp current-progress-new.md > current-progress.md
rm header.tmp current-progress-new.md

# 5. Update README.md (manually)

# 6. Verify
wc -l current-progress.md archives/*.md
```

## Token Impact

**Before archiving:** ~32,000 tokens (2700+ lines)
**After archiving:** ~6,000-8,000 tokens (300-400 lines)
**Savings:** ~75-80% reduction in normal token usage

## Notes

- Archives preserve full historical detail
- README.md is the navigation hub
- `current-progress.md` stays lean and recent (2-3 weeks max)
- Archives loaded only when historical context needed
- User manages .claude files separately (not in git)
