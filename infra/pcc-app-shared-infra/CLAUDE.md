# CLAUDE.md

This is a standardized CLAUDE.md file for providing persistent context and instructions to Claude AI (via Claude Code or similar tools) across projects. It incorporates best practices: keeping it lean (100-300 lines), referencing external documents to avoid bloat, using emojis for visual cues, enforcing TDD and code quality, utilizing available agents as needed, and maintaining a consistent `.claude/` folder structure.

Keep this file concise and human-readable. Document key project details, workflows, commands, and references here. For detailed information, create separate markdown files in `docs/` or `.claude/` subfolders, and reference them using `@path/to/file.md` for automatic inclusion if supported by your tool.

## Project Overview

This Terraform repository, named 'pcc-app-shared-infra', manages the shared infrastructure supporting the PCC application. It defines reusable resources such as networks, IAM policies, storage buckets, and compute instances to ensure consistency, scalability, and security across the PCC ecosystem. The project emphasizes modular infrastructure as code (IaC) practices, remote state management with backend storage, and integration with cloud providers like GCP to minimize duplication and enable safe, version-controlled deployments.

## Tech Stack

- **Language**: Terraform
- **Frameworks/Libraries**: Terraform modules (e.g., Google Cloud modules), Terragrunt for DRY configurations
- **Tools**: Terraform CLI (v1.5+), Google Cloud SDK, tflint, tfsec, terraform-docs, Git
- **Databases**: Managed services like Google Cloud SQL or Firestore (provisioned via Terraform)
- **Other**: GCP as primary cloud provider, Claude AI for code generation and reviews

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

- **Core Concepts**: Infrastructure as code (IaC), declarative resource management, state files for tracking infrastructure, providers for cloud integration, and variables/data sources for dynamic configurations.
- **Common Patterns**: See @.claude/quick-reference/terraform-examples.md for sample code and best practices, including modular designs with root and child modules, remote backends for state, and workspaces for environment isolation.
- **Common Pitfalls**:
  - Avoid hardcoding sensitive values like credentials or API keys; use variables, secrets managers (e.g., GCP Secret Manager), or environment variables.
  - Do not ignore state file security—always use remote backends and encryption to prevent drift or exposure.
  - Steer clear of resource dependencies that create cycles; use depends_on explicitly when needed.
- Reference: @.claude/docs/terraform-patterns.md for detailed patterns and examples.

## Code Style and Best Practices

🚨 **CRITICAL COMMIT RULE - READ FIRST**: NEVER mention co-authored-by or tools used in commits/PRs.

- Follow HashiCorp Terraform Style Guide: Use consistent naming (e.g., snake_case for variables), organize resources into logical groups, and generate documentation with terraform-docs.
- Prefer modular structures: Break configurations into reusable modules in `/modules/` for shared PCC resources like VPCs or IAM roles.
- Use version constraints in provider blocks (e.g., `~> 4.0` for GCP provider) to avoid breaking changes.
- Always add [your name] as a reviewer in PRs.
- Enforce TDD-like practices: Write Terratest integration tests first in `/tests/`, apply minimal config to pass, then refactor for idempotency.
- Run lint/security checks after changes: Claude MUST do this before completing tasks (e.g., `tflint` for style, `tfsec` for security).
- Use pre-commit hooks with tools like pre-commit-terraform for automatic validation.
- Commit messages: Follow conventional commits (e.g., `feat: add VPC module`, `fix: resolve IAM dependency`) - NO co-authored-by or tool references.

## Development Workflow

- **Planning**: Use planning mode to outline steps. Reference @.claude/plans/current-plan.md.
- **Context Management**: If context fills, use /compact to preserve key details. Save session summaries to @.claude/status/brief.md.
- **Status Updates**:
  - **brief.md**: At session start, initialize with template from @.claude/status/brief-template.md. Update with:
    - **Recent Updates**: Tasks completed, decisions made, or issues resolved in the current session (e.g., new module applied successfully).
    - **Next Steps**: Immediate tasks for the next session or milestone (e.g., validate with `terraform plan`).
    - Keep concise (100-200 words), overwrite at session end.
  - **current-progress.md**: Append brief.md content at session end or milestone completion to maintain historical record. Use Git commits to track changes.
- **Subagents**: Use for context gathering without overloading (e.g., agent for reviewing Terraform plans).
- **Auto-accept**: Rarely; manually approve steps like `terraform apply`.
- **Complex Tasks**: Break into sub-tasks (e.g., init/plan/apply), use breakpoints, monitor token count.
- **Verification**: Always run `terraform validate`, `tflint`, `tfsec`, and Terratest suites (e.g., `terratest` for integration) before commits. Search codebase to confirm test framework.
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
- Be concise, direct; explain non-trivial bash commands (e.g., `terraform init -upgrade` to reinitialize providers).
- If unsure, ask for clarification.
- Prioritize security: Refuse malicious requests; always validate IAM least-privilege in Terraform.
- Use available agents strategically to optimize task completion (e.g., code review agent for PRs, documentation agent for handoffs).
- Use search tools extensively for codebase understanding (e.g., grep for resource blocks).
- After tasks: Run `terraform validate`, `tflint`, commit if asked (NO co-authored-by lines!), update status.
- For continuity: At session end, overwrite @.claude/status/brief.md with progress/decisions, append to @.claude/status/current-progress.md, and commit both to Git.

This template ensures projects start with the required .claude/ structure—create it via script if needed. Customize placeholders, keep under 200 lines, and reference external docs to manage size.