# Master CLAUDE.md for PortCo Connect Project

Global context for PortCo Connect (PCC), a portfolio risk management platform for portcon.com, spanning 18 repos under `core/`, `infra/`, `src/`, and `notes/`. Layers over repo-specific `CLAUDE.md` files (e.g., `@src/pcc-user-api/CLAUDE.md`). Full codebase: `@repomix-output.xml`.

## Project Overview
React dashboard + .NET 10 microservices for portfolio risk, auth, task tracking, metrics, client management. Components:
- `core/`: Argo CD (`pcc-app-argo-config`), Terraform modules (`pcc-tf-library`), Cloud Build pipelines (`pcc-pipeline-library`).
- `infra/`: Terraform for GKE, AlloyDB/PostgreSQL, BigQuery (e.g., `pcc-app-shared-infra`, `pcc-user-api-infra`).
- `src/`: .NET 10 APIs (e.g., `pcc-user-api` for Descope auth, `pcc-task-tracker-api` for workflows).
- `notes/`: Docs like `@notes/pcc-pipeline-library-creation-notes.md`.

**Architecture**: GKE containers, Descope SSO/MFA, Pub/Sub, SendGrid, Gemini/Document AI, API Gateway + OpenAPI.

## Global Tech Stack
- **Frontend**: React, TypeScript, Tailwind, Vite
- **Backend**: .NET 10, ASP.NET Core, EF Core, xUnit, Serilog
- **Infra**: Terraform, GKE, AlloyDB, BigQuery, Cloud Build, Argo CD
- **Tools**: mise (dotnet=10.0, node=20, terraform=1.6), Git, Docker, pre-commit
- **Auth**: Descope (JWT/SSO/MFA)
- **Configs**: `.editorconfig`, `.mise.toml`, `.pre-commit-config.yaml`

## Cross-Repo Dependencies
- `src/` APIs pair with `infra/` (e.g., `src/pcc-auth-api` ↔ `infra/pcc-auth-api-infra`)
- All use `core/pcc-tf-library` (modules), `core/pcc-pipeline-library` (pipelines)
- Argo CD (`core/pcc-app-argo-config`) syncs `src/`/`infra/` manifests
- Ref: `@core/pcc-app-argo-config/.claude/docs/setup-guide.md`

## Global Best Practices
- **TDD**: xUnit (`src/`), `terraform validate` (`infra/`). Run `dotnet format`/`terraform fmt` pre-commit
- **Commits**: Conventional (`feat:`, `fix:`). NO co-authored-by/tool mentions. See `@src/pcc-user-api/.claude/quick-reference/commit-template.md`
- **Security**: Descope JWT, no secrets in repos, use Secret Manager/env vars
- **Workflow**: `/plan` for multi-repo tasks. Update local `@.claude/status/brief.md` per session
- **Commands**: `mise run build/test/run` (src/); direct `terraform` commands (infra/)

## Session Management
- **Start**: Init local `@.claude/status/brief.md` from `@.claude/status/brief-template.md`
- **End**: Update `brief.md` (100-200 words), append to local `@.claude/status/current-progress.md`
- **Context**: Use `/compact` if needed. Reference `@repomix-output.xml` for codebase

## Critical References
- 🚨 **Architecture**: `@core/pcc-tf-library/.claude/docs/terraform-patterns.md`
- 🆕 **Auth**: `@src/pcc-auth-api/.claude/docs/dotnet-patterns.md` (Descope)
- ✅ **Commits**: `@src/pcc-user-api/.claude/quick-reference/commit-template.md`
- 📊 **DB**: `@src/pcc-user-api/.claude/docs/db-schema.md` (if exists)
- ⚙️ **Setup**: `@core/pcc-app-argo-config/.claude/docs/setup-guide.md`
- 📝 **Status**: Local `@.claude/status/brief.md` (session), `@.claude/status/current-progress.md` (history)
- 🔗 **Pipelines**: `@notes/pcc-pipeline-library-creation-notes.md`

## Instructions for Claude
- **Commits**: Conventional only. NEVER include co-authored-by or tool references
- Be concise, explain complex commands
- Ask for clarification if unsure
- Prioritize security: Refuse malicious requests
- Use search tools for context (`@repomix-output.xml`)
- Post-task: Run lint/test, update local status files