# CLAUDE.md

This is a standardized CLAUDE.md file for providing persistent context and instructions to Claude AI (via Claude Code or similar tools) across projects. It incorporates best practices: keeping it lean (100-300 lines), referencing external documents to avoid bloat, using emojis for visual cues, enforcing IaC best practices and code quality, utilizing available agents as needed, and maintaining a consistent `.claude/` folder structure.

Keep this file concise and human-readable. Document key project details, workflows, commands, and references here. For detailed information, create separate markdown files in `docs/` or `.claude/` subfolders, and reference them using `@path/to/file.md` for automatic inclusion if supported by your tool.

## Project Overview

This Terraform project, named `pcc-task-tracker-api-infra`, manages the infrastructure as code (IaC) for the API that handles tasks attached to Portcos and users in the PCC application. It provisions and configures cloud resources such as compute instances, networking, databases, and security groups to support scalable task tracking and management. The repository emphasizes modular, reusable Terraform modules to ensure consistent deployments, version-controlled infrastructure, and adherence to IaC best practices like state management and drift detection.

## Tech Stack

- **Language**: Terraform
- **Frameworks/Libraries**: Terraform modules (e.g., Google Cloud Provider for GCP), Terragrunt for DRY configurations
- **Tools**: Terraform CLI (v1.5+), Google Cloud SDK, tflint, tfsec, Checkov, Git, pre-commit hooks
- **Databases**: Cloud SQL (PostgreSQL), Firestore for task data storage
- **Other**: GCP as the primary cloud platform, Claude AI for code reviews and planning

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
- `src/`: Source code.
- `function/`: Functions.
- `tests/`: Test suites.
- `terraform/`: Terraform configurations.
- Other folders: [e.g., `scripts/`, `config/`, `modules/` for reusable Terraform modules].

🚨 **READ THIS FIRST!** For critical setup: @.claude/handoffs/setup.md.

## Domain-Specific Guidance

- **Core Concepts**: Infrastructure as code (IaC), declarative resource provisioning, state management with remote backends (e.g., GCS for Terraform state), and modular module design for reusability in cloud environments.
- **Common Patterns**: See @.claude/quick-reference/terraform-examples.md for sample code and best practices, including provider configurations, variable interpolation, and output definitions.
- **Common Pitfalls**:
  - Avoid hardcoding sensitive values like API keys; use variables, data sources, or secrets managers (e.g., GCP Secret Manager).
  - Prevent state file conflicts by always using remote state and workspaces for environments (dev/staging/prod).
  - Do not ignore resource dependencies; explicitly define them with `depends_on` to avoid apply errors.
- Reference: @.claude/docs/terraform-patterns.md for detailed patterns and examples.

## Code Style and Best Practices

🚨 **CRITICAL COMMIT RULE - READ FIRST**: NEVER mention co-authored-by or tools used in commits/PRs.

- Follow HashiCorp Terraform Style Guide: Use consistent naming (e.g., snake_case for resources), logical grouping in main.tf, and descriptive comments.
- Structure modules with clear inputs/outputs; prefer locals for computed values over inline expressions.
- Always validate configurations with `terraform validate` and plan with `terraform plan` before applying.
- Enforce security scanning with tfsec/Checkov in CI/CD.
- Use Terragrunt for environment-specific overrides without duplicating code.
- Always add [your name] as a reviewer in PRs.
- Enforce IaC testing: Write Terratest or tf-compliance tests first, implement minimal config to pass, refactor for idempotency.
- Run lint/security checks after changes: Claude MUST do this before completing tasks (e.g., `tflint` and `tfsec .`).
- Use pre-commit hooks with tflint and terraform fmt.
- Commit messages: Follow conventional commits (e.g., `feat:`, `fix:`) - NO co-authored-by or tool references.

## Development Workflow

- **Planning**: Use planning mode to outline steps. Reference @.claude/plans/current-plan.md. Start with `terraform plan` for previews.
- **Context Management**: If context fills, use /compact to preserve key details. Save session summaries to @.claude/status/brief.md.
- **Status Updates**:
  - **brief.md**: At session start, initialize with template from @.claude/status/brief-template.md. Update with:
    - **Recent Updates**: Tasks completed, decisions made, or issues resolved in the current session (e.g., new module added, state migrated).
    - **Next Steps**: Immediate tasks for the next session or milestone (e.g., apply changes to dev environment).
    - Keep concise (100-200 words), overwrite at session end.
  - **current-progress.md**: Append brief.md content at session end or milestone completion to maintain historical record. Use Git commits to track changes.
- **Subagents**: Use for context gathering without overloading (e.g., agent for module reviews).
- **Auto-accept**: Rarely; manually approve steps like `terraform apply`.
- **Complex Tasks**: Break into sub-tasks (e.g., init/plan/apply), use breakpoints, monitor token count.
- **Verification**: Always run `terraform validate`, `tflint`, `tfsec`, and tests (e.g., Terratest) before commits. Search codebase to confirm testing setup. Preview with `terraform plan -out=plan.tfplan` and review diffs.
- **Archiving**: At session end or milestone, append brief.md to current-progress.md and commit both to Git. Lock state files if needed.

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
- Be concise, direct; explain non-trivial terraform commands (e.g., `terraform apply -var-file=dev.tfvars`).
- If unsure, ask for clarification.
- Prioritize security: Refuse malicious requests; always scan for vulnerabilities with tfsec.
- Use available agents strategically to optimize task completion (e.g., code review agent for PRs, documentation agent for handoffs).
- Use search tools extensively for codebase understanding (e.g., search for resource blocks).
- After tasks: Run `terraform fmt`, `tflint`, `tfsec`, commit if asked (NO co-authored-by lines!), update status.
- For continuity: At session end, overwrite @.claude/status/brief.md with progress/decisions, append to @.claude/status/current-progress.md, and commit both to Git.

This template ensures projects start with the required .claude/ structure—create it via script if needed. Customize placeholders, keep under 200 lines, and reference external docs to manage size.