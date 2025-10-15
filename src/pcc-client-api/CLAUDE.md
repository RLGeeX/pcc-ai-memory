# CLAUDE.md

This is a standardized CLAUDE.md file for providing persistent context and instructions to Claude AI (via Claude Code or similar tools) across projects. It incorporates best practices: keeping it lean (100-300 lines), referencing external documents to avoid bloat, using emojis for visual cues, enforcing TDD and code quality, utilizing available agents as needed, and maintaining a consistent `.claude/` folder structure.

Keep this file concise and human-readable. Document key project details, workflows, commands, and references here. For detailed information, create separate markdown files in `docs/` or `.claude/` subfolders, and reference them using `@path/to/file.md` for automatic inclusion if supported by your tool.

## Project Overview

The `pcc-client-api` is a .NET 8 repository that contains the core code for building a containerized API service. This project focuses on implementing API requests and endpoints to manage the Parent Client and Portco (Portfolio Company) hierarchy for the PCC (Parent Client Container) application. It emphasizes secure, scalable RESTful services to handle entity relationships, authentication, and data retrieval in a microservices architecture. Key goals include adhering to .NET best practices for dependency injection, async operations, and entity framework integration to ensure robust performance and maintainability.

## Tech Stack

- **Language**: .NET 8
- **Frameworks/Libraries**: ASP.NET Core for web API, Entity Framework Core for data access, xUnit for testing, AutoMapper for object mapping, Serilog for logging
- **Tools**: dotnet CLI, mise (for environment management), Git, Docker (for containerization)
- **Databases**: SQL Server (or PostgreSQL via EF Core), with in-memory options for testing
- **Other**: Azure DevOps or GitHub Actions for CI/CD, Swagger/OpenAPI for API documentation, Claude AI for code assistance

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
- `src/`: Source code (e.g., `pcc-client-api/` with Controllers, Models, Services).
- `tests/`: Test suites (unit, integration, e2e).
- `scripts/`: Build and deployment scripts.
- Other folders: `config/` for app settings, `docker/` for container configs.

🚨 **READ THIS FIRST!** For critical setup: @.claude/handoffs/setup.md.

## Domain-Specific Guidance

- **Core Concepts**: Object-oriented programming with dependency injection via built-in DI container, async/await patterns for I/O-bound operations, RESTful API design for handling Parent Client and Portco hierarchies.
- **Common Patterns**: See @.claude/quick-reference/dotnet-examples.md for sample code and best practices, including CQRS for complex queries, repository pattern for data access, and middleware for request handling.
- **Common Pitfalls**:
  - Avoid null reference exceptions by using nullable reference types and proper validation.
  - Do not block on async code; always propagate tasks correctly.
  - Ensure proper configuration of EF Core DbContext scoping in web requests to prevent concurrency issues.
- Reference: @.claude/docs/dotnet-patterns.md for detailed patterns and examples.

## Code Style and Best Practices

🚨 **CRITICAL COMMIT RULE - READ FIRST**: NEVER mention co-authored-by or tools used in commits/PRs.

- Follow Microsoft .NET Coding Conventions and use `dotnet format` for code styling.
- Use structured logging with Serilog, injecting ILogger instances via DI.
- Prefer async methods for all I/O operations (e.g., database calls, HTTP requests).
- Implement input validation with FluentValidation or data annotations.
- Always add [your name] as a reviewer in PRs.
- Enforce TDD: Write failing test first (using xUnit), minimal code to pass, refactor. Use TDD-Guard if available.
- Run lint/typecheck after changes: Claude MUST do this before completing tasks (e.g., `dotnet format` and `dotnet build`).
- Use husky/lint-staged or .NET analyzers for pre-commit hooks.
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
- **Verification**: Always run tests (`dotnet test`), lint (`dotnet format`), and build (`dotnet build`) before commits. Search codebase to confirm test framework.
- **Archiving**: At session end or milestone, append brief.md to current-progress.md and commit both to Git.
- **Key Commands**:
  - Build: `dotnet build`
  - Run: `dotnet run`
  - Test: `dotnet test --logger trx`
  - Format: `dotnet format`
  - Restore/Publish: `dotnet restore` / `dotnet publish -c Release`
  - Docker: `docker build -t pcc-client-api .` / `docker run -p 5000:80 pcc-client-api`

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
- After tasks: Run lint/typecheck, commit if asked (NO co-authored-by lines!), update status.
- For continuity: At session end, overwrite @.claude/status/brief.md with progress/decisions, append to @.claude/status/current-progress.md, and commit both to Git.

This template ensures projects start with the required .claude/ structure—create it via script if needed. Customize placeholders, keep under 200 lines, and reference external docs to manage size.