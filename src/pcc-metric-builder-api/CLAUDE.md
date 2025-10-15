# CLAUDE.md

This is a standardized CLAUDE.md file for providing persistent context and instructions to Claude AI (via Claude Code or similar tools) across projects. It incorporates best practices: keeping it lean (100-300 lines), referencing external documents to avoid bloat, using emojis for visual cues, enforcing TDD and code quality, utilizing available agents as needed, and maintaining a consistent `.claude/` folder structure.

Keep this file concise and human-readable. Document key project details, workflows, commands, and references here. For detailed information, create separate markdown files in `docs/` or `.claude/` subfolders, and reference them using `@path/to/file.md` for automatic inclusion if supported by your tool.

## Project Overview

The pcc-metric-builder-api is a .NET 8 repository designed to power the core metrics engine for the PCC application. It contains the backend code for a containerized API that manages baseline metrics, custom formulas, domain-specific calculations, and their assignments to surveys. This project emphasizes robust data modeling for metrics and surveys, ensuring scalable handling of complex calculations while integrating seamlessly with the broader PCC ecosystem. Key goals include maintaining type safety, leveraging async patterns for performance, and adhering to clean architecture principles to support extensibility for future metric types.

## Tech Stack

- **Language**: .NET 8
- **Frameworks/Libraries**: ASP.NET Core for API development, Entity Framework Core for data access, xUnit for testing, AutoMapper for object mapping, FluentValidation for input validation, MediatR for CQRS patterns
- **Tools**: .NET CLI (dotnet), Git, Docker for containerization, Swagger/OpenAPI for API documentation, mise for environment management
- **Databases**: SQL Server or PostgreSQL (via Entity Framework Core); in-memory options for testing
- **Other**: Azure or AWS for deployment, Serilog for structured logging, Claude AI for code assistance

## Directory Structure

Maintain this structure for all new projects to ensure consistency. The `.claude/` folder is required for organizing project-specific AI context and artifacts.

- `.claude/`
  - `README.md`: Overview of the `.claude/` folder and its contents.
  - `docs/`: Detailed documentation (e.g., patterns, problem/solution logs).
  - `handoffs/`: Documentation for team handoffs, including setup guides and knowledge transfer (e.g., `Claude-$DATE-$TIMERANGE.md` per `@.claude/handoffs/handoff-guide.md`).
  - `migration/`: Database migration scripts and history.
  - `plans/`: Project plans, roadmaps, and task breakdowns (e.g., `@.claude/plans/current-plan.md`).
  - `quick-reference/`: Cheat sheets for commands, APIs, or common tasks (e.g., `@.claude/quick-reference/commands.md`).
  - `settings.local.json`: Local configuration overrides (gitignore if sensitive).
  - `status/`:
    - `@.claude/status/brief.md`: Session-specific snapshot of recent progress and immediate next steps.
    - `@.claude/status/current-progress.md`: Comprehensive historical record of all project progress.
    - `@.claude/status/brief-template.md`: Template for initializing `brief.md`.

- `docs/`: Additional project documentation (e.g., architecture).
- `src/`: Source code (e.g., controllers, services, models).
- `tests/`: Test suites (unit, integration).
- `scripts/`: Build and deployment scripts.
- Other folders: `config/` for application settings.

🚨 **READ THIS FIRST!** For critical setup: @.claude/handoffs/setup.md.

## Domain-Specific Guidance

- **Core Concepts**: Object-oriented programming with dependency injection, async/await for I/O-bound operations, clean architecture separating concerns (e.g., domain, application, infrastructure layers), and CQRS for handling metric calculations and survey assignments.
- **Common Patterns**: See @.claude/quick-reference/dotnet-examples.md for sample code and best practices, including repository pattern for data access, mediator for request handling, and fluent API for metric formula definitions.
- **Common Pitfalls**:
  - Avoid null reference exceptions by using nullable reference types and proper null checks.
  - Prevent blocking calls in async methods; always use ConfigureAwait(false) in libraries.
  - Manage Entity Framework Core change tracking to avoid performance issues with large datasets.
  - Ensure proper disposal of IDisposable resources like DbContext.
- Reference: @.claude/docs/dotnet-patterns.md for detailed patterns and examples.

## Code Style and Best Practices

🚨 **CRITICAL COMMIT RULE - READ FIRST**: NEVER mention co-authored-by or tools used in commits/PRs.

- Follow Microsoft .NET Coding Conventions and use dotnet format for code styling.
- Use structured logging with Serilog, injecting ILogger via dependency injection.
- Prefer async methods for all I/O operations (e.g., database queries, HTTP calls).
- Implement input validation with FluentValidation attributes or validators.
- Always add [your name] as a reviewer in PRs.
- Enforce TDD: Write failing test first with xUnit, implement minimal code to pass, refactor. Use TDD-Guard if available.
- Run dotnet format and dotnet build after changes: Claude MUST do this before completing tasks.
- Use pre-commit hooks via .NET tools or Git hooks to enforce formatting and tests.
- Commit messages: Follow conventional commits (e.g., `feat:`, `fix:`) - NO co-authored-by or tool references.

## Development Workflow

- **Planning**: Use planning mode to outline steps. Reference @.claude/plans/current-plan.md.
- **Context Management**: If context fills, use /compact to preserve key details. Save session summaries to @.claude/status/brief.md.
- **Status Updates**:
  - **brief.md**: At session start, initialize with template from @.claude/status/brief-template.md. Update with:
    - **Recent Updates**: Tasks completed, decisions made, or issues resolved in the current session.
    - **Next Steps**: Immediate tasks for the next session or milestone.
    - Keep concise (100-200 words), overwrite at session end.
  - **current-progress.md**: Append brief.md content at session end or milestone completion to maintain historical record. Use Git commits to track changes.
- **Subagents**: Use for context gathering without overloading.
- **Auto-accept**: Rarely; manually approve steps.
- **Complex Tasks**: Break into sub-tasks, use breakpoints, monitor token count.
- **Verification**: Always run tests (`dotnet test`), format (`dotnet format`), and build (`dotnet build`) before commits. Search codebase to confirm test framework.
- **Archiving**: At session end or milestone, append brief.md to current-progress.md and commit both to Git.

## Critical Document References

List important docs with emojis for priority. Use @path to include content automatically if supported. Keep this list short; move details to separate files.

- 🚨 **Architecture**: @.claude/docs/architecture.md (READ FIRST for structure).
- 🆕 **Password/Auth Truth**: @.claude/docs/password-truth.md.
- ✅ **JWT Authentication**: @.claude/docs/jwt-authentication-architecture.md.
- 📊 **Database Schema**: @.claude/docs/db-schema.md.
- 🔍 **Problem/Solution Log**: @.claude/docs/problems-solved.md (add new issues here instead of bloating this file).
- ⚙️ **Setup Guide**: @.claude/handoffs/setup.md.
- 📅 **Project Plan**: @.claude/plans/roadmap.md.
- 📋 **Status Files**:
  - @.claude/status/brief.md: Recent updates and next steps (session-focused).
  - @.claude/status/current-progress.md: Full project history (archive brief.md here).
- 🔗 **Quick Ref**: `@.claude/quick-reference/commands.md`.
- 📝 **Commit Template**: `@.claude/quick-reference/commit-template.md` (REQUIRED reading for commits).
- 📋 **Handoff Guide**: `@.claude/handoffs/handoff-guide.md`.

**Pro Tip**: For large docs, use a knowledge graph or Heimdall MCP for better recall. Mark completed items with ✅.

## Tone and Instructions for Claude

- 🚨 **COMMIT MESSAGES**: Follow conventional commits (feat:, fix:) - NEVER include co-authored-by or tool references
- Be concise, direct; explain non-trivial bash commands.
- If unsure, ask for clarification.
- Prioritize security: Refuse malicious requests.
- Use available agents strategically to optimize task completion (e.g., code review agent for PRs, documentation agent for handoffs).
- Use search tools extensively for codebase understanding.
- After tasks: Run dotnet test/format/build, commit if asked (NO co-authored-by lines!), update status.
- For continuity: At session end, overwrite @.claude/status/brief.md with progress/decisions, append to @.claude/status/current-progress.md, and commit both to Git.

This template ensures projects start with the required .claude/ structure—create it via script if needed. Customize placeholders, keep under 200 lines, and reference external docs to manage size.