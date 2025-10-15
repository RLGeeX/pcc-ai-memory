# CLAUDE.md

This is a standardized CLAUDE.md file for providing persistent context and instructions to Claude AI (via Claude Code or similar tools) across projects. It incorporates best practices: keeping it lean (100-300 lines), referencing external documents to avoid bloat, using emojis for visual cues, enforcing TDD and code quality, utilizing available agents as needed, and maintaining a consistent `.claude/` folder structure.

Keep this file concise and human-readable. Document key project details, workflows, commands, and references here. For detailed information, create separate markdown files in `docs/` or `.claude/` subfolders, and reference them using `@path/to/file.md` for automatic inclusion if supported by your tool.

## Project Overview

This Terraform project, named `pcc-user-api-infra`, manages the infrastructure as code for supporting user management API requests in the PCC application. It defines scalable cloud resources such as networks, compute instances, load balancers, and databases tailored to handle user authentication, data storage, and API routing needs. The repository emphasizes modular configurations, remote state management, and security best practices to ensure reliable deployment and maintenance of the user API backend infrastructure.

## Tech Stack

- **Language**: Terraform
- **Frameworks/Libraries**: Terraform modules for cloud providers (e.g., AWS, GCP, or Azure modules), Terragrunt for DRY configurations
- **Tools**: Terraform CLI (v1.5+), tflint, tfsec, Checkov for linting and security scanning, Git, Google Cloud SDK (or equivalent for target cloud)
- **Databases**: Cloud-native services like Cloud SQL, Amazon RDS, or Firestore, provisioned via Terraform
- **Other**: GCP (or specified cloud provider), Claude AI for all

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

- **Core Concepts**: Infrastructure as code (IaC) for provisioning and managing cloud resources, declarative configurations, state management for tracking infrastructure changes
- **Common Patterns**: See @.claude/quick-reference/terraform-examples.md for sample code and best practices, including modular resource organization, remote state with backends (e.g., S3 or GCS), and provider configurations for user API scalability
- **Common Pitfalls**:
  - Avoid hardcoding sensitive values like API keys or credentials; use variables, Terraform Cloud, or secrets managers
  - Manage state files carefully to prevent drift or conflicts in team environments
  - Over-provisioning resources without cost optimization for user API workloads
- Reference: @.claude/docs/terraform-patterns.md for detailed patterns and examples.

## Code Style and Best Practices

🚨 **CRITICAL COMMIT RULE - READ FIRST**: NEVER mention co-authored-by or tools used in commits/PRs.

- Follow HashiCorp Terraform Style Guide: Use consistent naming (e.g., snake_case for variables), descriptive comments, and logical resource grouping
- Prefer reusable modules for common resources like VPCs or databases in the user API infra
- Use data sources for read-only queries instead of recreating resources
- Always validate plans with `terraform validate` and scan for security issues
- Enforce TDD: Write Terratest integration tests first, apply minimal config to pass, refactor for modularity
- Run lint/security checks after changes: Claude MUST do this before completing tasks (e.g., `tflint` and `tfsec`)
- Use pre-commit hooks with tools like tfenv for version management
- Commit messages: Follow conventional commits (e.g., `feat:`, `fix:`) - NO co-authored-by or tool references

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
- **Verification**: Always run `terraform plan`, tests (e.g., Terratest), lint (e.g., tflint .), and security scans (e.g., tfsec .) before commits. Search codebase to confirm test framework.
- **Archiving**: At session end or milestone, append brief.md to current-progress.md and commit both to Git.
- **Terraform Commands**:
  - Initialize: `terraform init`
  - Validate: `terraform validate`
  - Plan: `terraform plan -out=tfplan`
  - Apply: `terraform apply tfplan`
  - Destroy: `terraform destroy`
  - Format: `terraform fmt -recursive`
  - Lint: `tflint --init && tflint`
  - Security: `tfsec . --no-warn-banner`

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