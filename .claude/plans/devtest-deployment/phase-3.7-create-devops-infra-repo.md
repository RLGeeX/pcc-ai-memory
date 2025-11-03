# Phase 3.7: Create DevOps Infra Repo Structure

**Phase**: 3.7 (GKE Infrastructure - Repository Setup)
**Duration**: 10 minutes
**Type**: Configuration
**Status**: Ready for Execution

---

## Execution Tool

**Use WARP for this phase** - Git repository creation and initialization.

---

## Objective

Create `pcc-devops-infra` repository with standard structure and environment folders for nonprod/prod GKE deployments.

## Prerequisites

✅ Phase 3.6 completed (GKE module resources created)
✅ GitHub access configured
✅ Understanding of environment folder pattern (ADR-008)

---

## Step 1: Create Repository

```bash
cd ~/pcc/infra
mkdir pcc-devops-infra
cd pcc-devops-infra

git init
git branch -M main
```

---

## Step 2: Create Directory Structure

```bash
# Environment folders (ADR-008 pattern)
mkdir -p environments/nonprod
mkdir -p environments/prod

# Documentation
mkdir -p .claude/docs
mkdir -p .claude/status
mkdir -p .claude/plans
mkdir -p .claude/quick-reference
```

---

## Step 3: Create .gitignore

**File**: `pcc-devops-infra/.gitignore`

```gitignore
# Terraform
**/.terraform/*
*.tfstate
*.tfstate.*
*.tfvars.backup
*.tfplan
.terraform.lock.hcl

# Sensitive files
**/*.pem
**/*.key
**/.env
**/credentials.json

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db
```

---

## Step 4: Create README.md

**File**: `pcc-devops-infra/README.md`

```markdown
# PCC DevOps Infrastructure

Terraform infrastructure for PCC DevOps GKE clusters (nonprod and prod).

## Structure

\`\`\`
pcc-devops-infra/
├── environments/
│   ├── nonprod/       # NonProd GKE cluster
│   └── prod/          # Prod GKE cluster
└── .claude/           # AI context and plans
\`\`\`

## Deployment

### NonProd
\`\`\`bash
cd environments/nonprod
terraform init -upgrade  # Always use -upgrade with force-pushed tags
terraform plan
terraform apply
\`\`\`

### Prod
\`\`\`bash
cd environments/prod
terraform init -upgrade  # Always use -upgrade with force-pushed tags
terraform plan
terraform apply
\`\`\`

## References

- **ADR-008**: Terraform Environment Folder Pattern
- **Module Source**: core/pcc-tf-library/modules/gke-autopilot
- **Phase 3 Plan**: .claude/plans/devtest-deployment/phase-3.x-*.md
```

---

## Step 5: Initialize Git Repository

```bash
git add .
git commit -m "feat: initialize pcc-devops-infra repository

- Add environment folder structure (nonprod, prod)
- Add .gitignore for Terraform
- Add README with deployment instructions
- Create .claude/ directory for AI context"

# Create GitHub repository (if not exists)
gh repo create portco-connect/pcc-devops-infra --private --source=. --remote=origin --push
```

**Note**: Adjust GitHub org name if different. Commit message follows conventional commits without tool attribution per CLAUDE.md policy.

---

## Validation Checklist

- [ ] Repository initialized with `git init`
- [ ] `environments/nonprod/` directory created
- [ ] `environments/prod/` directory created
- [ ] `.claude/` directory structure created
- [ ] `.gitignore` created with Terraform patterns
- [ ] `README.md` created with deployment instructions
- [ ] Initial commit created
- [ ] GitHub repository created (if needed)

---

## Directory Structure (Final)

```
pcc-devops-infra/
├── .git/
├── .gitignore
├── README.md
├── environments/
│   ├── nonprod/        # Phase 3.8 will populate
│   └── prod/           # Future phase will populate
└── .claude/
    ├── docs/
    ├── status/
    ├── plans/
    └── quick-reference/
```

---

## Next Phase Dependencies

**Phase 3.8** will:
- Populate `environments/nonprod/` with terraform files
- Create backend.tf, providers.tf, variables.tf, gke.tf, outputs.tf, terraform.tfvars
- Claude Code execution (file creation)

---

## References

- **ADR-008**: Terraform Environment Folder Pattern
- **GitHub CLI**: https://cli.github.com/manual/gh_repo_create

---

## Time Estimate

- **Create directories**: 2 minutes
- **Create .gitignore**: 2 minutes
- **Create README**: 3 minutes
- **Git init and commit**: 3 minutes
- **Total**: 10 minutes

---

**Status**: Ready for execution
**Next**: Phase 3.8 - Create Environment Configuration (Claude Code)
