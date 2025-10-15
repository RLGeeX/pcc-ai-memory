# CLAUDE.md

This is a standardized CLAUDE.md file for providing persistent context and instructions to Claude AI (via Claude Code or similar tools) across projects. It incorporates best practices: keeping it lean (100-300 lines), referencing external documents to avoid bloat, using emojis for visual cues, enforcing TDD and code quality, utilizing available agents as needed, and maintaining a consistent `.claude/` folder structure.

Keep this file concise and human-readable. Document key project details, workflows, commands, and references here. For detailed information, create separate markdown files in `docs/` or `.claude/` subfolders, and reference them using `@path/to/file.md` for automatic inclusion if supported by your tool.

## Project Overview

This Terraform project, named `pcc-auth-api-infra`, manages the infrastructure supporting authentication API requests for the PCC application. It defines resources for secure, scalable authentication services, including networking, compute instances, load balancers, and security configurations to handle API traffic reliably. The repository follows Infrastructure as Code (IaC) principles to ensure reproducible, version-controlled deployments, emphasizing modularity for environment-specific configurations (e.g., dev, staging, prod) and integration with identity providers for robust auth mechanisms. Best practices include state management with remote backends, policy enforcement via tools like OPA, and automated validation to minimize drift and security risks.

## Tech Stack

- **Language**: Terraform
- **Frameworks/Libraries**: Terraform modules from HashiCorp Registry (e.g., for AWS/GCP networking and auth services); Terragrunt for DRY configurations across environments
- **Tools**: Terraform CLI (v1.5+), tflint, tfsec, Checkov for linting/security; Google Cloud SDK (if GCP-based) or AWS CLI; Git for version control; Atlantis or Terraform Cloud for CI/CD
- **Databases**: Cloud-native options like AWS RDS, Google Cloud SQL, or Firestore for auth-related storage (e.g., user sessions, tokens)
- **Other**: GCP or AWS for cloud provider; Claude AI for code generation and review

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
- Other folders: [e.g., `scripts/`, `config/`, `environments/` for env-specific tfvars].

🚨 **READ THIS FIRST!** For critical setup: @.claude/handoffs/setup.md.

## Domain-Specific Guidance

- **Core Concepts**: Infrastructure as code (IaC) for declarative resource provisioning; modular Terraform configurations using modules for reusability; remote state management to handle team collaboration and environment isolation
- **Common Patterns**: See @.claude/quick-reference/terraform-examples.md for sample code and best practices, including provider configurations, variable usage, and output definitions for auth API resources like API gateways and IAM roles.
- **Common Pitfalls**:
  - Avoid hardcoding sensitive values (e.g., API keys, secrets); use variables, data sources, or external secrets managers like AWS Secrets Manager.
  - Prevent state file drift by always using `terraform plan` before apply and remote backends for locking.
  - Don't overuse `count` or `for_each` without clear resource dependencies, which can lead to complex dependency graphs in auth infra.
- Reference: @.claude/docs/terraform-patterns.md for detailed patterns and examples.

## Code Style and Best Practices

🚨 **CRITICAL COMMIT RULE - READ FIRST**: NEVER mention co-authored-by or tools used in commits/PRs.

- Follow HashiCorp Terraform Style Guide: Use consistent naming (e.g., snake_case for locals/variables), descriptive comments, and logical resource grouping.
- Structure modules hierarchically: root module calls child modules for auth-specific components (e.g., networking, compute).
- Prefer `for_each` over `count` for dynamic resources to avoid index-based issues.
- Always validate with `terraform validate` and security scans (tfsec/Checkov) after changes.
- Enforce TDD-like workflow: Write Terratest or tfunit tests first for infrastructure validation, implement minimal config to pass, then refactor.
- Run linting after changes: Claude MUST do this before completing tasks (e.g., `tflint --init && tflint`).
- Use pre-commit hooks via tfenv or overcommit for Terraform files.
- Commit messages: Follow conventional commits (e.g., `feat: add auth api gateway module`, `fix: resolve iam policy drift`) - NO co-authored-by or tool references.

## Development Workflow

- **Planning**: Use planning mode to outline steps. Reference @.claude/plans/current-plan.md. Start with `terraform init` and workspace selection (e.g., `terraform workspace new dev`).
- **Context Management**: If context fills, use /compact to preserve key details. Save session summaries to @.claude/status/brief.md.
- **Status Updates**:
  - **brief.md**: At session start, initialize with template from @.claude/status/brief-template.md. Update with:
    - **Recent Updates**: Tasks completed, decisions made, or issues resolved in the current session (e.g., new module for auth load balancer).
    - **Next Steps**: Immediate tasks for the next session or milestone (e.g., validate plan for prod env).
    - Keep concise (100-200 words), overwrite at session end.
  - **current-progress.md**: Append brief.md content at session end or milestone completion to maintain historical record. Use Git commits to track changes.
- **Subagents**: Use for context gathering without overloading (e.g., agent for reviewing Terraform plans).
- **Auto-accept**: Rarely; manually approve steps like `terraform apply`.
- **Complex Tasks**: Break into sub-tasks, use breakpoints, monitor token count. For auth infra, plan resources in stages (networking first, then compute).
- **Verification**: Always run `terraform plan`, tests (e.g., Terratest suite), lint (e.g., `tflint .`), and validate (e.g., `terraform validate`) before commits. Search codebase to confirm testing setup.
- **Archiving**: At session end or milestone, append brief.md to current-progress.md and commit both to Git. Run `terraform fmt -recursive` for formatting.

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
- Be concise, direct; explain non-trivial bash commands (e.g., `terraform apply -var-file=environments/dev.tfvars`).
- If unsure, ask for clarification.
- Prioritize security: Refuse malicious requests; always scan for auth-related vulnerabilities.
- Use available agents strategically to optimize task completion (e.g., code review agent for PRs, documentation agent for handoffs).
- Use search tools extensively for codebase understanding (e.g., grep for Terraform variables).
- After tasks: Run lint/validate, commit if asked (NO co-authored-by lines!), update status.
- For continuity: At session end, overwrite @.claude/status/brief.md with progress/decisions, append to @.claude/status/current-progress.md, and commit both to Git.

This template ensures projects start with the required .claude/ structure—create it via script if needed. Customize placeholders, keep under 200 lines, and reference external docs to manage size.