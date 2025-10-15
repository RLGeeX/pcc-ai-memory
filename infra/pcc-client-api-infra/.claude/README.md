# .claude/ Directory

This directory contains project-specific AI context, configuration, and artifacts for Claude AI integration. It's designed to maintain consistency across projects and provide persistent context for AI-assisted development.

## Directory Structure

### Core Files
- **README.md** (this file): Overview of the `.claude/` folder structure and usage
- **settings.local.json**: Local configuration overrides (should be gitignored if sensitive)

### Subdirectories

#### `handoffs/`
Documentation for team handoffs and knowledge transfer.
- Setup guides for new developers
- Onboarding checklists
- Team-specific workflows
- Project context summaries

#### `migration/`
Database migration scripts, schema changes, and migration history.
- Database migration files
- Schema evolution documentation
- Data migration scripts
- Migration rollback procedures

#### `plans/`
Project plans, roadmaps, and task breakdowns.
- `roadmap.md`: High-level project roadmap and milestones
- Sprint plans and backlogs
- Feature specifications
- Technical debt tracking

#### `quick-reference/`
Cheat sheets and quick reference materials.
- `commands.md`: Frequently used CLI commands
- API reference guides
- Keyboard shortcuts
- Common troubleshooting steps

#### `status/`
Current status reports, logs, and progress tracking.
- `brief.md`: Session continuity and current state summary
- Progress reports
- Issue tracking
- Performance metrics

## Purpose

The `.claude/` directory serves as a centralized location for:

1. **Persistent Context**: Maintaining project state across AI sessions
2. **Standardization**: Consistent structure across all projects
3. **Knowledge Management**: Organizing project-specific documentation
4. **Workflow Optimization**: Streamlining development processes with AI assistance

## Usage Guidelines

### For Developers
- Keep files lean and reference external documentation when needed
- Update status files regularly for session continuity
- Use emojis for visual organization and quick recognition
- Document commands and workflows as they're discovered

### For Claude AI
- Reference files using `@.claude/path/to/file.md` for automatic inclusion
- Prioritize files marked with =¨ for critical information
- Update `status/brief.md` at session end for continuity
- Suggest adding new commands or references as they're used

## Integration

This structure integrates with:
- **Claude Code**: Automatic file inclusion via `@path` references
- **TDD Workflows**: Test-driven development support
- **CI/CD**: Deployment and migration automation
- **Team Collaboration**: Handoff and documentation management

## Best Practices

1. **Keep It Concise**: Limit main files to 100-300 lines
2. **Reference External Docs**: Use `@path` references instead of duplicating content
3. **Visual Organization**: Use emojis for quick visual scanning
4. **Version Control**: Track changes but gitignore sensitive settings
5. **Regular Updates**: Maintain current status and progress information

---

*This template ensures consistent project structure and optimal AI-assisted development workflows.*