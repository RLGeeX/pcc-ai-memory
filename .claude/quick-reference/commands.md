# Shared Commands for PortCo Connect

Global CLI commands for PortCo Connect. Run from `~/git/pcc/pcc-project` or sub-repos. Repo-specific commands in `@<repo>/.claude/quick-reference/commands.md`.

## Global Commands (Root Level)
```bash
# Install all tool versions
mise install

# List installed tools
mise ls --installed

# Activate mise environment
eval "$(mise activate)"

# View available tasks across repos
mise tasks --list
```

## .NET Commands (src/ repos)
```bash
# From any src/ repo (e.g., src/pcc-user-api)
mise run build      # dotnet build
mise run test       # dotnet test
mise run format     # dotnet format
mise run run        # dotnet run --project src
```

## Terraform Commands (infra/ repos)
```bash
# From any infra/ repo (e.g., infra/pcc-user-api-infra)
mise use terraform 1.6    # Ensure correct version
terraform init
terraform fmt -recursive
terraform validate
tflint
# Note: No mise tasks for terraform init/plan/apply - run directly
```

## Argo CD Commands (core/pcc-app-argo-config)
```bash
cd core/pcc-app-argo-config
argocd login <server> --username <user> --password <pass>
argocd app list
argocd app sync pcc-user-api
argocd app get pcc-user-api
```

## Cloud Build Commands
```bash
# Trigger pipeline from root
gcloud builds submit --config core/pcc-pipeline-library/cloudbuild.yaml .

# Or from specific repo
cd src/pcc-user-api
gcloud builds submit --config ../../core/pcc-pipeline-library/cloudbuild-api.yaml .
```

## Git Workflow Commands
```bash
# Install pre-commit hooks (each repo)
pre-commit install

# Run pre-commit checks
pre-commit run --all-files

# Conventional commit examples
git commit -m "feat: add user authentication endpoint"
git commit -m "fix: resolve descope token validation issue"
git commit -m "docs: update API documentation"
```

## Notes
- Always run `mise install` after cloning repos
- Use `mise tasks` in each repo for language-specific commands
- Terraform commands run directly (no mise tasks for init/plan/apply)
- See `@core/pcc-pipeline-library/.claude/quick-reference/commands.md` for pipeline details
- For Descope: Use Descope CLI or SDK methods in src/ repos