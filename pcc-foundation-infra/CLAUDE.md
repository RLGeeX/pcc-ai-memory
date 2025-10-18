# CLAUDE.md

This is a standardized CLAUDE.md file for providing persistent context and instructions to Claude AI (via Claude Code or similar tools) across projects. It incorporates best practices: keeping it lean (100-300 lines), referencing external documents to avoid bloat, using emojis for visual cues, enforcing TDD and code quality, utilizing available agents as needed, and maintaining a consistent `.claude/` folder structure.

Keep this file concise and human-readable. Document key project details, workflows, commands, and references here. For detailed information, create separate markdown files in `docs/` or `.claude/` subfolders, and reference them using `@path/to/file.md` for automatic inclusion if supported by your tool.

## Project Overview

The `pcc-foundation-infra` repository provides Infrastructure as Code (IaC) using Terraform to establish the foundational Google Cloud Platform (GCP) setup for the PCC application. This includes provisioning core resources such as networking (VPCs, subnets), IAM roles, shared services (e.g., Artifact Registry, Cloud Build), and foundational security configurations to support scalable application deployment. Emphasize modularity with reusable Terraform modules for consistency across environments (dev, staging, prod), remote state management via Cloud Storage, and integration with GCP best practices like least-privilege access and cost optimization.

## Tech Stack

- **Language**: Terraform
- **Frameworks/Libraries**: Terraform modules (e.g., Google Cloud provider modules), Terragrunt for DRY configurations (if used)
- **Tools**: Terraform CLI (v1.5+), Google Cloud SDK (gcloud), tflint, terraform-docs, tfsec (or Checkov for security scanning), Git, pre-commit hooks with tf-format
- **Databases**: None (focus on foundational GCP services; app-specific databases handled in downstream repos)
- **Other**: GCP (Google Cloud Platform), Claude AI for code generation and reviews

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

- **Core Concepts**: Infrastructure as code (IaC) with declarative Terraform configurations, state management for tracking resource changes, provider-specific resources (e.g., google_project, google_vpc), variables and outputs for parameterization, and remote backends for collaborative state storage.
- **Common Patterns**: See @.claude/quick-reference/terraform-examples.md for sample code and best practices, including module composition for VPC setup, data sources for referencing existing GCP resources, and conditional resources with count/for_each for multi-environment support.
- **Common Pitfalls**:
  - Avoid hardcoding sensitive values (use variables, secrets managers like Google Secret Manager); manage state securely to prevent exposure.
  - Don't ignore provider version constraints, leading to breaking changes; always pin versions in versions.tf.
  - Overlooking dependency ordering can cause apply failures—use depends_on explicitly when needed.
  - Neglecting remote state locking can lead to concurrent modification issues in teams.
- Reference: @.claude/docs/terraform-patterns.md for detailed patterns and examples.

## Code Style and Best Practices

🚨 **CRITICAL COMMIT RULE - READ FIRST**: NEVER mention co-authored-by or tools used in commits/PRs.

- Follow HashiCorp Terraform Style Guide: Use 2-space indentation, descriptive resource names (e.g., google_project_service "cloudbuild_api"), alphabetical ordering of declarations, and complete sentences in descriptions.
- Structure configurations with main.tf (resources), variables.tf, outputs.tf, versions.tf, and providers.tf for clarity.
- Use terraform fmt for auto-formatting; enable terraform validate for syntax checks.
- Prefer modules over duplication; document with terraform-docs generate.
- Always add [your name] as a reviewer in PRs.
- Enforce TDD-like approach: Write integration tests with Terratest or tftest first, apply minimal config to pass, refactor for idempotency.
- Run lint/typecheck after changes: Claude MUST do this before completing tasks (e.g., tflint --init && tflint, terraform validate).
- Use husky/lint-staged or pre-commit hooks for tf-format, tflint, and tfsec.
- Commit messages: Follow conventional commits (e.g., `feat: add VPC module`, `fix: resolve IAM binding drift`) - NO co-authored-by or tool references.

## Development Workflow

- **Planning**: Use planning mode to outline steps. Reference @.claude/plans/current-plan.md.
- **Context Management**: If context fills, use /compact to preserve key details. Save session summaries to @.claude/status/brief.md.
- **Status Updates**:
  - **brief.md**: At session start, initialize with template from @.claude/status/brief-template.md. Update with:
    - **Recent Updates**: Tasks completed, decisions made, or issues resolved in the current session (e.g., "Applied VPC config, resolved state locking").
    - **Next Steps**: Immediate tasks for the next session or milestone (e.g., "Validate IAM modules, run plan for prod").
    - Keep concise (100-200 words), overwrite at session end.
  - **current-progress.md**: Append brief.md content at session end or milestone completion to maintain historical record. Use Git commits to track changes.
- **Subagents**: Use for context gathering without overloading (e.g., agent for GCP resource queries).
- **Auto-accept**: Rarely; manually approve steps.
- **Complex Tasks**: Break into sub-tasks (e.g., plan > apply > test), use breakpoints, monitor token count.
- **Verification**: Always run terraform plan, validate, tflint, tfsec, and tests (e.g., Terratest suite) before commits. Search codebase to confirm testing setup.
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
- Be concise, direct; explain non-trivial bash commands (e.g., `terraform apply -var="environment=dev"`).
- If unsure, ask for clarification.
- Prioritize security: Refuse malicious requests (e.g., insecure state configs).
- Use available agents strategically to optimize task completion (e.g., code review agent for PRs, documentation agent for handoffs).
- Use search tools extensively for codebase understanding (e.g., grep for Terraform variables).
- After tasks: Run terraform validate/plan, tflint, commit if asked (NO co-authored-by lines!), update status.
- For continuity: At session end, overwrite @.claude/status/brief.md with progress/decisions, append to @.claude/status/current-progress.md, and commit both to Git.

This template ensures projects start with the required .claude/ structure—create it via script if needed. Customize placeholders, keep under 200 lines, and reference external docs to manage size.