# CLAUDE.md

This is a standardized CLAUDE.md file for providing persistent context and instructions to Claude AI (via Claude Code or similar tools) across projects. It incorporates best practices: keeping it lean (100-300 lines), referencing external documents to avoid bloat, using emojis for visual cues, enforcing TDD and code quality, utilizing available agents as needed, and maintaining a consistent `.claude/` folder structure.

Keep this file concise and human-readable. Document key project details, workflows, commands, and references here. For detailed information, create separate markdown files in `docs/` or `.claude/` subfolders, and reference them using `@path/to/file.md` for automatic inclusion if supported by your tool.

## Project Overview

The 'pcc-tf-library' is a centralized Terraform library repository housing reusable modules for all PCC (Platform for Cloud Computing) project deployments. It enables consistent, scalable infrastructure as code (IaC) management across environments by providing modular components like networking, compute, and storage resources that can be referenced and composed in deployment-specific configurations. This project emphasizes modularity, version control of modules, and adherence to Terraform best practices to reduce duplication, improve maintainability, and ensure secure, idempotent deployments on cloud platforms such as GCP or AWS.

## Tech Stack

- **Language**: Terraform
- **Frameworks/Libraries**: Terraform modules (e.g., core PCC modules for VPCs, IAM roles, and Kubernetes clusters); Terragrunt for DRY configurations (if used in consuming projects)
- **Tools**: Terraform CLI (v1.5+), tflint, terraform-docs, tfsec for security scanning, Git for version control, mise for tool management
- **Databases**: None (focus on infrastructure provisioning; database modules may be included as Terraform resources, e.g., for Cloud SQL or Firestore)
- **Other**: GCP/AWS providers for Terraform, Claude AI for code generation and review

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
- `modules/`: Reusable Terraform modules (e.g., `vpc/`, `iam/`, `compute/` with `main.tf`, `variables.tf`, `outputs.tf`).
- `examples/`: Sample usage of modules for testing and documentation.
- `tests/`: Terratest or integration test suites for modules.
- Other folders: `scripts/` for automation, `config/` for provider configurations.

🚨 **READ THIS FIRST!** For critical setup: @.claude/handoffs/setup.md.

## Domain-Specific Guidance

- **Core Concepts**: Infrastructure as code (IaC) with declarative configurations, modular reusable components, state management for tracking resources, providers for cloud integration, and remote state storage (e.g., in GCS or S3) to enable collaboration.
- **Common Patterns**: See @.claude/quick-reference/terraform-examples.md for sample code and best practices, including root module composition, variable passing between modules, data sources for dynamic inputs, and remote modules sourced via Git.
- **Common Pitfalls**:
  - Avoid hardcoding sensitive values (use variables, secrets managers like Vault or SSM); manage state files securely to prevent exposure.
  - Don't ignore resource dependencies—use explicit `depends_on` only when implicit ones fail.
  - Overlooking provider version pinning, leading to breaking changes; always validate plans before apply.
- Reference: @.claude/docs/terraform-patterns.md for detailed patterns and examples.

## Code Style and Best Practices

🚨 **CRITICAL COMMIT RULE - READ FIRST**: NEVER mention co-authored-by or tools used in commits/PRs.

- Follow HashiCorp Terraform Style Guide: Use consistent naming (e.g., snake_case for resources), organize files logically (`main.tf` for resources, `variables.tf` for inputs, `outputs.tf` for exports), and generate documentation with terraform-docs.
- Prefer remote state backends for team collaboration; use workspaces for environment isolation.
- Enforce security: Scan with tfsec/checkov; avoid inline credentials.
- Always add [your name] as a reviewer in PRs.
- Enforce TDD: Write Terratest integration tests first for modules, implement minimal configuration to pass, then refactor for reusability.
- Run lint/typecheck after changes: Claude MUST do this before completing tasks—e.g., `tflint .`, `terraform validate .`.
- Use pre-commit hooks with tflint and terraform-docs to auto-format and validate.
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
- **Verification**: Always run tests (`terratest` for modules), lint (`tflint .`), and validate (`terraform validate .`) before commits. Search codebase to confirm test framework. For changes: `terraform plan` to preview, never apply without review.
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
- After tasks: Run lint/typecheck, commit if asked (NO co-authored-by lines!), update status.
- For continuity: At session end, overwrite @.claude/status/brief.md with progress/decisions, append to @.claude/status/current-progress.md, and commit both to Git.

This template ensures projects start with the required .claude/ structure—create it via script if needed. Customize placeholders, keep under 200 lines, and reference external docs to manage size.