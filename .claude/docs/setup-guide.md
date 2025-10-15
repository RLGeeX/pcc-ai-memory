# Setup Guide for PortCo Connect Project

Setting up the PortCo Connect (PCC) development environment for the multi-repo project at `~/git/pcc/pcc-project`. Covers shared tools across 18 repos (`core/`, `infra/`, `src/`, `notes/`).

## Prerequisites
- **Tools**:
  - mise: `curl https://mise.run | sh` then `eval "$(mise activate)"`
  - Git, Docker, kubectl, gcloud CLI
  - .NET 10 SDK, Node.js 20, Terraform 1.6, tflint 0.48
  - Argo CD CLI: `curl -sSL -o argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64 && chmod +x argocd && sudo mv argocd /usr/local/bin/`
- **APIs**: Google Cloud SDK (`gcloud init`), Descope CLI, GitHub tokens (`GITHUB_PCC_TOKEN`)

## Setup Steps
1. **Clone All Repos**:
   ```bash
   cd ~/git/pcc/pcc-project
   # Clone each repo individually or use a script
   git clone git@github-pcc:PORTCoCONNECT/core/pcc-app-argo-config.git core/pcc-app-argo-config
   # ... repeat for all 18 repos
   ```

2. **Install Tool Versions with mise**:
   ```bash
   cd ~/git/pcc/pcc-project
   mise install  # Installs .NET 10, Node 20, Terraform 1.6, etc. from .mise.toml
   eval "$(mise activate)"
   ```

3. **Setup .NET Projects (src/)**:
   ```bash
   cd src/pcc-user-api
   mise run build    # Runs: dotnet build
   mise run test     # Runs: dotnet test
   mise run format   # Runs: dotnet format
   ```

4. **Setup Terraform Projects (infra/)**:
   ```bash
   cd infra/pcc-user-api-infra
   mise use terraform 1.6  # Ensure correct Terraform version
   terraform init
   terraform fmt -recursive
   tflint --init
   ```

5. **Setup Argo CD (core/)**:
   ```bash
   cd core/pcc-app-argo-config
   argocd login <argo-server> --username <user> --password <pass>
   argocd app list
   ```

6. **Install Pre-commit Hooks** (in each repo):
   ```bash
   cd src/pcc-user-api  # or any repo
   pre-commit install
   ```

7. **Verify Setup**:
   ```bash
   # .NET repos
   cd src/pcc-user-api && mise run test

   # Terraform repos
   cd infra/pcc-user-api-infra && terraform validate

   # Check mise tools
   mise ls --installed
   ```

## Environment Configuration
Create `.env` (gitignored) in project root:
```bash
GITHUB_PCC_TOKEN=your_token
GOOGLE_CLOUD_PROJECT=your-gcp-project
DESCOPE_PROJECT_ID=your-descope-id
```

## Notes
- Repo-specific setup: See `@src/pcc-user-api/.claude/docs/dotnet-patterns.md`, `@infra/pcc-user-api-infra/.claude/docs/terraform-patterns.md`
- Use `@repomix-output.xml` for full codebase context
- Run `mise tasks` in each repo for available commands
- For Cloud Build: `gcloud builds submit --config core/pcc-pipeline-library/cloudbuild.yaml .`