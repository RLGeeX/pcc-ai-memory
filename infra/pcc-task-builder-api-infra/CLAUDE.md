# CLAUDE.md

This is a standardized CLAUDE.md file for providing persistent context and instructions to Claude AI (via Claude Code or similar tools) across projects. It incorporates best practices: keeping it lean (100-300 lines), referencing external documents to avoid bloat, using emojis for visual cues, enforcing TDD and code quality, utilizing available agents as needed, and maintaining a consistent `.claude/` folder structure.

Keep this file concise and human-readable. Document key project details, workflows, commands, and references here. For detailed information, create separate markdown files in `docs/` or `.claude/` subfolders, and reference them using `@path/to/file.md` for automatic inclusion if supported by your tool.

## Project Overview

This Terraform repository, named `pcc-task-builder-api-infra`, defines the infrastructure as code for supporting the PCC Task Builder API. The API manages task grouping and attachment to metrics, surveys, and other elements within the PCC application, enabling scalable and configurable task workflows. It provisions cloud resources like compute instances, networking, databases, and security configurations to ensure reliable API operations, emphasizing modularity, idempotency, and compliance with infrastructure best practices. The setup supports the PCC application's backend needs, focusing on high availability, cost optimization, and secure data handling for task-related entities.

## Tech Stack

- **Language**: Terraform
- **Frameworks/Libraries**: Terraform modules (e.g., for AWS/GCP resources), Terragrunt for multi-environment management (if used)
- **Tools**: Terraform CLI (v1.5+), tflint, tfsec, Checkov for linting/security, Git for version control, Google Cloud SDK or AWS CLI depending on provider
- **Databases**: Provisioned via Terraform (e.g., Cloud SQL for PostgreSQL, Firestore for NoSQL) to support task metadata and attachments
- **Other**: GCP (primary provider for PCC infra), Claude AI for code generation and reviews

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
- Other folders: [e.g., `scripts/`, `config/`, `environments/` for dev/staging/prod].

🚨 **READ THIS FIRST!** For critical setup: @.claude/handoffs/setup.md.

## Domain-Specific Guidance

- **Core Concepts**: Infrastructure as code (IaC) for provisioning and managing cloud resources; declarative configuration using HCL (HashiCorp Configuration Language); state management with remote backends (e.g., Terraform Cloud or GCS bucket) to track infrastructure changes.
- **Common Patterns**: See @.claude/quick-reference/terraform-examples.md for sample code and best practices, including modular resource composition (e.g., reusable modules for networking, compute), remote state data sources for cross-environment dependencies, and variables/outputs for parameterization.
- **Common Pitfalls**:
  - Avoid hardcoding sensitive values like credentials or API keys—use variables, Terraform Cloud variables, or secrets managers (e.g., GCP Secret Manager).
  - Do not ignore state drift; always run `terraform plan` before `apply` to detect changes.
  - Prevent resource duplication by using `count` or `for_each` for dynamic blocks instead of repetitive code.
  - Ensure provider version pinning to avoid breaking changes during upgrades.
- Reference: @.claude/docs/terraform-patterns.md for detailed patterns and examples, including task-builder API-specific modules for API gateways, load balancers, and database schemas.

## Code Style and Best Practices

🚨 **CRITICAL COMMIT RULE - READ FIRST**: NEVER mention co-authored-by or tools used in commits/PRs.

- Follow HashiCorp Terraform Style Guide: Use consistent naming (e.g., snake_case for locals/variables), organize resources logically (inputs > locals > resources > outputs), and keep files under 300-500 lines for readability.
- Prefer modular design: Break configurations into reusable modules (e.g., one for VPC, one for API services) and use `module` blocks.
- Use `terraform fmt` for auto-formatting and `tflint` for style enforcement.
- Parameterize everything: Define input variables with descriptions/types, use `validate` blocks for constraints, and avoid provider-specific hardcoding.
- Always add [your name] as a reviewer in PRs.
- Enforce testing: Use Terratest or terraform-compliance for integration tests; write tests for modules to verify resource creation and outputs.
- Run lint/security scans after changes: Claude MUST do this before completing tasks (e.g., `tflint --init && tflint`, `tfsec .`, `checkov -d .`).
- Use pre-commit hooks with tools like pre-commit + tflint for Terraform validation.
- Commit messages: Follow conventional commits (e.g., `feat: add module for task api load balancer`, `fix: resolve vpc peering dependency`) - NO co-authored-by or tool references.

## Development Workflow

- **Planning**: Use planning mode to outline steps. Reference @.claude/plans/current-plan.md. For Terraform, start with `terraform init` and `plan` to model changes.
- **Context Management**: If context fills, use /compact to preserve key details. Save session summaries to @.claude/status/brief.md.
- **Status Updates**:
  - **brief.md**: At session start, initialize with template from @.claude/status/brief-template.md. Update with:
    - **Recent Updates**: Tasks completed, decisions made, or issues resolved in the current session (e.g., "Added module for task database; resolved state locking").
    - **Next Steps**: Immediate tasks for the next session or milestone (e.g., "Test API gateway integration").
    - Keep concise (100-200 words), overwrite at session end.
  - **current-progress.md**: Append brief.md content at session end or milestone completion to maintain historical record. Use Git commits to track changes.
- **Subagents**: Use for context gathering without overloading (e.g., agent for reviewing Terraform plans).
- **Auto-accept**: Rarely; manually approve steps, especially `terraform apply`.
- **Complex Tasks**: Break into sub-tasks (e.g., init > validate > plan > apply), use breakpoints, monitor token count. For the task-builder API, sequence networking before compute.
- **Verification**: Always run `terraform validate`, `fmt`, lint (e.g., tflint .), and security scans (e.g., tfsec .) before commits. Execute tests with `terratest` if configured. Search codebase to confirm module structure.
- **Archiving**: At session end or milestone, append brief.md to current-progress.md and commit both to Git. Tag releases with semantic versioning for Terraform state.

## Critical Document References

List important docs with emojis for priority. Use @path to include content automatically if supported. Keep this list short; move details to separate files.

- 🚨 **Architecture**: @.claude/docs/architecture.md (READ FIRST for structure, including PCC task API flow).
- 🆕 **Password/Auth Truth**: @.claude/docs/password-truth.md.
- ✅ **JWT Authentication**: @.claude/docs/jwt-authentication-architecture.md.
- 📊 **Database Schema**: @.claude/docs/db-schema.md (for task metrics and surveys).
- 🔍 **Problem/Solution Log**: @.claude/docs/problems-solved.md (add new issues here instead of bloating this file).
- ⚙️ **Setup Guide**: @.claude/handoffs/setup.md (includes `terraform init` steps).
- 📅 **Project Plan**: @.claude/plans/roadmap.md.
- 📋 **Status Files**:
  - @.claude/status/brief.md: Recent updates and next steps (session-focused).
  - @.claude/status/current-progress.md: Full project history (archive brief.md here).
- 🔗 **Quick Ref**: `@.claude/quick-reference/commands.md` (Terraform-specific commands).
- 📝 **Commit Template**: `@.claude/quick-reference/commit-template.md` (REQUIRED reading for commits).
- 📋 **Handoff Guide**: `@.claude/handoffs/handoff-guide.md`.

**Pro Tip**: For large docs, use a knowledge graph or Heimdall MCP for better recall. Mark completed items with ✅.

## Tone and Instructions for Claude

- 🚨 **COMMIT MESSAGES**: Follow conventional commits (feat:, fix:) - NEVER include co-authored-by or tool references
- Be concise, direct; explain non-trivial bash commands (e.g., `terraform apply -var="env=dev"` for environment-specific deploys).
- If unsure, ask for clarification (e.g., on PCC-specific requirements like task attachment logic).
- Prioritize security: Refuse malicious requests; always scan for secrets in Terraform code.
- Use available agents strategically to optimize task completion (e.g., code review agent for PRs, documentation agent for handoffs).
- Use search tools extensively for codebase understanding (e.g., grep for module usages).
- After tasks: Run lint/security checks, commit if asked (NO co-authored-by lines!), update status.
- For continuity: At session end, overwrite @.claude/status/brief.md with progress/decisions, append to @.claude/status/current-progress.md, and commit both to Git.

This template ensures projects start with the required .claude/ structure—create it via script if needed. Customize placeholders, keep under 200 lines, and reference external docs to manage size.