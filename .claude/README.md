# .claude/ Folder Overview

The `.claude/` folder in the PortCo Connect project root organizes **local-only** Claude AI context for the entire application (18 repos). These files are **NEVER committed** to Git and exist only for local development sessions.

## Structure (Local Only)
- `docs/`: Global docs (architecture, shared patterns) - local reference only
- `handoffs/`: Local handoff notes for personal/team transitions - never committed
- `quick-reference/`: Shared command templates - local reference only
- `reference/`: Reference information that affects the whole project - local reference only
- `status/`: Session tracking (`brief.md`, `current-progress.md`) - local only
- `settings.local.json`: Local config overrides - gitignored

## Usage
- Reference with `@.claude/path/to/file.md` in Claude Code sessions
- Update `status/brief.md` per local session; append to `current-progress.md`
- **NEVER commit** any `.claude/` files to Git repositories
- Use repo-specific `.claude/` folders for repo-level context (also never committed)
- For team handoffs, use committed docs (README.md, notes/, PR descriptions)

## Important Notes
- `.claude/` contents are for personal AI context management only
- Team knowledge transfer uses committed files (README.md, docs/, notes/)
- See `@CLAUDE.md` for project-wide context and workflow guidance