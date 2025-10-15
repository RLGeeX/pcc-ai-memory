# CLAUDE.md

This is a standardized CLAUDE.md file for providing persistent context and instructions to Claude AI (via Claude Code or similar tools) across projects. It incorporates best practices: keeping it lean (100-300 lines), referencing external documents to avoid bloat, using emojis for visual cues, enforcing TDD and code quality, utilizing available agents as needed, and maintaining a consistent `.claude/` folder structure.

Keep this file concise and human-readable. Document key project details, workflows, commands, and references here. For detailed information, create separate markdown files in `docs/` or `.claude/` subfolders, and reference them using `@path/to/file.md` for automatic inclusion if supported by your tool.

## Project Overview

This Terraform project, named 'pcc-metric-tracker-api-infra', manages the infrastructure as code for the API supporting the PCC (Portco Compliance Checker) application. It provisions resources to handle results from specific survey questions attached to Portcos (portfolio companies), enabling secure data storage, processing, and retrieval. The setup emphasizes modular, scalable designs using GCP services like Cloud Run, Cloud SQL, and Secret Manager to ensure reliability, security, and cost-efficiency for the metric tracking API.

## Tech Stack

- **Language**: Terraform
- **Frameworks/Libraries**: Terraform modules from the Terraform Registry (e.g., google-cloud-platform modules for GCP resources); Terragrunt for DRY configurations (if applicable)
- **Tools**: Terraform CLI (v1.5+), Google Cloud SDK (gcloud), tflint, tfsec, Checkov for security scanning, Git for version control
- **Databases**: Google Cloud SQL (PostgreSQL for survey results), Firestore for lightweight metric storage
- **Other**: GCP (Google Cloud Platform) as the primary cloud provider, Claude AI for code generation and review

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
- Other folders: [e.g., `scripts/`, `config/`, `environments/` for dev/stage/prod].

🚨 **READ THIS FIRST!** For critical setup: @.claude/handoffs/setup.md.

## Domain-Specific Guidance

- **Core Concepts**: Infrastructure as code (IaC) for declarative provisioning of GCP resources; modular Terraform configurations using modules for reusability; state management with remote backends (e.g., GCS) to handle team collaboration and drift detection.
- **Common Patterns**: See @.claude/quick-reference/terraform-examples.md for sample code and best practices, including remote state data sources, provider aliases for multi-region setups, and output variables for cross-module dependencies.
- **Common Pitfalls**:
  - Avoid hardcoding sensitive values like API keys—use variables and GCP Secret Manager integration.
  - Manage resource dependencies explicitly with `depends_on` to prevent apply-time errors.
  - Regularly run `terraform validate` and `plan` to catch syntax or drift issues early.
- Reference: @.claude/docs/terraform-patterns.md for detailed patterns and examples.

## Code Style and Best Practices

🚨 **CRITICAL COMMIT RULE - READ FIRST**: NEVER mention co-authored-by or tools used in commits/PRs.

- Follow HashiCorp Terraform Style Guide: Use consistent naming (e.g., snake_case for resources), group resources logically in files, and document variables/outputs with descriptions.
- Prefer local-exec provisioners sparingly; use null_resource only when necessary.
- Always version providers and modules with constraints (e.g., `~> 4.0` for google provider).
- Enforce security: Integrate tfsec/Checkov scans; avoid inline secrets.
- Always add [your name] as a reviewer in PRs.
- Enforce TDD: Write integration tests with Terratest first, implement minimal config to pass, refactor for modularity.
- Run lint/security checks after changes: Claude MUST do this before completing tasks (e.g., `tflint --init && tflint`).
- Use pre-commit hooks with tfenv for Terraform version management.
- Commit messages: Follow conventional commits (e.g., `feat:`, `fix:`) - NO co-authored-by or tool references.

## Development Workflow

- **Planning**: Use planning mode to outline steps. Reference @.claude/plans/current-plan.md.
- **Context Management**: If context fills, use /compact to preserve key details. Save session summaries to @.claude/status/brief.md.
- **Status Updates**:
  - **brief.md**: At session start, initialize with template from @.claude/status/brief-template.md. Update with:
    - **Recent Updates**: Tasks completed, decisions made, or issues resolved in the current session (e.g., new module for Cloud SQL).
    - **Next Steps**: Immediate tasks for the next session or milestone (e.g., validate plan for prod environment).
    - Keep concise (100-200 words), overwrite at session end.
  - **current-progress.md**: Append brief.md content at session end or milestone completion to maintain historical record. Use Git commits to track changes.
- **Subagents**: Use for context gathering without overloading (e.g., agent for tfplan analysis).
- **Auto-accept**: Rarely; manually approve steps.
- **Complex Tasks**: Break into sub-tasks (e.g., init > plan > apply), use breakpoints, monitor token count.
- **Verification**: Always run `terraform validate`, `tflint`, `tfsec`, and `terraform plan` before applies/commits. For tests, use Terratest: `go test ./tests/...`. Search codebase to confirm testing setup.
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
- Be concise, direct; explain non-trivial bash commands (e.g., `terraform apply -var-file=environments/dev.tfvars` for environment-specific deploys).
- If unsure, ask for clarification.
- Prioritize security: Refuse malicious requests; always scan for secrets with tfsec.
- Use available agents strategically to optimize task completion (e.g., code review agent for PRs, documentation agent for handoffs).
- Use search tools extensively for codebase understanding (e.g., search for resource blocks).
- After tasks: Run lint/security checks, commit if asked (NO co-authored-by lines!), update status.
- For continuity: At session end, overwrite @.claude/status/brief.md with progress/decisions, append to @.claude/status/current-progress.md, and commit both to Git.

This template ensures projects start with the required .claude/ structure—create it via script if needed. Customize placeholders, keep under 200 lines, and reference external docs to manage size.