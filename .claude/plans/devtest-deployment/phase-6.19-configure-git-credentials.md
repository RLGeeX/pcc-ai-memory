# Phase 6.19: Configure Git Credentials

**Tool**: [WARP] Partner Execution
**Estimated Duration**: 20 minutes

## Purpose

Create a dedicated nonprod ArgoCD configuration repository and configure Git credentials in ArgoCD to enable syncing from private GitHub repositories using Personal Access Token (PAT) method.

## Prerequisites

- Phase 6.18 completed (NetworkPolicy manifests created)
- Phase 6.17 completed (Google Workspace RBAC validated)
- GitHub account with admin access to create new repositories
- ArgoCD UI accessible

## Detailed Steps

### Step 1: Create GitHub Repository

1. Navigate to GitHub: `https://github.com/PORTCoCONNECT`
2. Click **New repository**
3. **Repository name**: `pcc-argocd-config-nonprod`
4. **Description**: `GitOps configuration for ArgoCD testing cluster (pcc-gke-devops-nonprod)`
5. **Visibility**: Private
6. **Initialize**: Do NOT check "Add a README file" (we'll push existing content)
7. Click **Create repository**

### Step 2: Initialize Local Repository

```bash
cd ~/pcc/core/

# Create new repo directory
mkdir pcc-argocd-config-nonprod
cd pcc-argocd-config-nonprod

# Initialize Git
git init
git remote add origin git@github.com:PORTCoCONNECT/pcc-argocd-config-nonprod.git

# Copy current nonprod content from old repo
cp -r ../pcc-app-argo-config/argocd-nonprod/devtest .

# Create README
cat > README.md << 'EOF'
# PCC ArgoCD Config - NonProd Testing Cluster

GitOps configuration for the ArgoCD testing cluster (`pcc-gke-devops-nonprod`).

**Purpose**: Testing ArgoCD and GKE upgrades only.

**Production configs**: See `pcc-app-argo-config` repo (future).

## Structure

- `devtest/` - DevTest environment configs
  - `ingress/` - Ingress and BackendConfig manifests
  - `network-policies/` - NetworkPolicy manifests
  - `app-of-apps/` - App-of-apps pattern (Phase 6.20)

## Usage

This repository is synced by ArgoCD running on `pcc-gke-devops-nonprod` cluster.

Changes to manifests trigger automatic sync within 3 minutes.
EOF

# Create .gitignore
cat > .gitignore << 'EOF'
# Terraform
*.tfstate
*.tfstate.backup
.terraform/
*.tfvars

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db
EOF

# Initial commit
git add .
git commit -m "feat: initialize nonprod ArgoCD config repo

- Extracted from pcc-app-argo-config for clean separation
- Contains Ingress and NetworkPolicies for testing cluster
- Dedicated to pcc-gke-devops-nonprod cluster only"

# Push to GitHub
git push -u origin main
```

**Expected Output**: Repository pushed successfully to GitHub

### Step 3: Create GitHub Personal Access Token

1. Navigate to GitHub: `https://github.com/settings/tokens`
2. Click **Generate new token → Generate new token (classic)**
3. **Note**: `ArgoCD NonProd Testing Cluster`
4. **Expiration**: 90 days
5. **Select scopes**:
   - ✅ `repo` (Full control of private repositories)
     - This grants: `repo:status`, `repo_deployment`, `public_repo`, `repo:invite`, `security_events`
6. Click **Generate token**
7. **COPY TOKEN IMMEDIATELY** (shown only once)
   - Format: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

**IMPORTANT**: Save token temporarily (will be stored in Secret Manager in next step)

### Step 4: Store PAT in Secret Manager

```bash
# Set variables
PROJECT_ID="pcc-prj-devops-nonprod"
PAT="ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"  # Replace with your actual token

# Create secret for GitHub PAT
echo -n "${PAT}" | gcloud secrets create argocd-github-pat \
  --project=${PROJECT_ID} \
  --replication-policy="user-managed" \
  --locations="us-east4" \
  --data-file=-

# Grant ArgoCD service accounts access
gcloud secrets add-iam-policy-binding argocd-github-pat \
  --project=${PROJECT_ID} \
  --member="serviceAccount:argocd-server@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

gcloud secrets add-iam-policy-binding argocd-github-pat \
  --project=${PROJECT_ID} \
  --member="serviceAccount:argocd-repo-server@${PROJECT_ID}.iam.gserviceaccount.com" \
  --role="roles/secretmanager.secretAccessor"

# Verify secret created
gcloud secrets describe argocd-github-pat --project=${PROJECT_ID}
```

**Expected Output**: Secret created with user-managed replication in us-east4

### Step 5: Add Repository to ArgoCD via CLI

```bash
# Retrieve PAT from Secret Manager
PAT=$(gcloud secrets versions access latest \
  --secret=argocd-github-pat \
  --project=${PROJECT_ID})

# Get ArgoCD admin password
ADMIN_PASSWORD=$(gcloud secrets versions access latest \
  --secret=argocd-admin-password \
  --project=${PROJECT_ID})

# Login to ArgoCD CLI
argocd login argocd.nonprod.pcconnect.ai \
  --username admin \
  --password "${ADMIN_PASSWORD}" \
  --grpc-web

# Add repository using HTTPS + PAT
argocd repo add https://github.com/PORTCoCONNECT/pcc-argocd-config-nonprod.git \
  --username git \
  --password "${PAT}" \
  --name pcc-argocd-config-nonprod
```

**Expected Output**:
```
Repository 'https://github.com/PORTCoCONNECT/pcc-argocd-config-nonprod.git' added
```

### Step 6: Verify Repository Connection

```bash
# List repositories
argocd repo list
```

**Expected Output**:
```
TYPE  NAME                         REPO                                                                   INSECURE  OCI    LFS    CREDS  STATUS      MESSAGE  PROJECT
git   pcc-argocd-config-nonprod    https://github.com/PORTCoCONNECT/pcc-argocd-config-nonprod.git         false     false  false  true   Successful           default
```

**Connection status**: "Successful" indicates ArgoCD can access repository

### Step 7: Test Repository Access

```bash
# Get repository details
argocd repo get https://github.com/PORTCoCONNECT/pcc-argocd-config-nonprod.git
```

**Expected**: Shows repository details with CONNECTION STATUS = "Successful"

### Step 8: Verify ArgoCD Can Clone Repository

```bash
# Trigger a test sync (validates clone operation)
# This will be used in Phase 6.21 when we deploy app-of-apps
argocd repo get https://github.com/PORTCoCONNECT/pcc-argocd-config-nonprod.git --refresh
```

**Expected**: Repository refreshes successfully without errors

**Note**: ArgoCD clones the repository using HTTPS with PAT credentials

## Success Criteria

- ✅ GitHub repository `pcc-argocd-config-nonprod` created
- ✅ Local repository initialized and content pushed to GitHub
- ✅ GitHub PAT created with `repo` scope
- ✅ PAT stored in Secret Manager (`argocd-github-pat`)
- ✅ ArgoCD service accounts granted secretAccessor role
- ✅ Repository added to ArgoCD successfully
- ✅ Connection status shows "Successful"
- ✅ ArgoCD can clone/refresh repository

## HALT Conditions

**HALT if**:
- Cannot create GitHub repository (insufficient permissions)
- Cannot push to GitHub (authentication issues)
- Cannot create GitHub PAT (insufficient permissions)
- PAT secret creation in Secret Manager fails
- ArgoCD repository connection fails
- Connection status shows error
- Cannot refresh repository

**Resolution**:
- **GitHub repo**: Verify organization admin permissions
- **Git push**: Check Git credentials: `git config --list | grep user`
- **PAT creation**: Verify account has permissions to create PATs
- **PAT scope**: Ensure `repo` scope is selected (read/write for private repos)
- **Secret Manager**: Verify project ID is correct: `pcc-prj-devops-nonprod`
- **IAM**: Verify ArgoCD service accounts exist:
  ```bash
  gcloud iam service-accounts list --project=pcc-prj-devops-nonprod | grep argocd
  ```
- **Repository URL**: Must use HTTPS format: `https://github.com/PORTCoCONNECT/pcc-argocd-config-nonprod.git`
- Check ArgoCD logs for authentication errors:
  ```bash
  kubectl logs -n argocd deployment/argocd-repo-server --tail=50 | grep -i auth
  ```
- Test PAT manually:
  ```bash
  PAT=$(gcloud secrets versions access latest --secret=argocd-github-pat)
  curl -H "Authorization: token ${PAT}" https://api.github.com/repos/PORTCoCONNECT/pcc-argocd-config-nonprod
  ```
  Expected: Repository JSON response (not 401/403 error)
- Verify network connectivity:
  ```bash
  kubectl exec -n argocd deployment/argocd-repo-server -- curl -I https://github.com
  ```

## Next Phase

Proceed to **Phase 6.20**: Create App-of-Apps Manifests

## Notes

- **Repository Separation**: `pcc-argocd-config-nonprod` is dedicated to testing cluster only
- **Future Production**: `pcc-app-argo-config` repo will be used for production ArgoCD cluster
- **PAT Method**: Uses Personal Access Token with HTTPS (simpler than SSH, works across multiple repos)
- **PAT Expiration**: GitHub PATs expire after 90 days, requiring manual rotation
- **PAT Rotation**: Calendar reminder to rotate PAT before expiration:
  1. Create new PAT in GitHub (Settings → Tokens)
  2. Update Secret Manager: `gcloud secrets versions add argocd-github-pat --data-file=<(echo -n "NEW_PAT")`
  3. ArgoCD automatically uses new version (no restart needed)
  4. Delete old PAT from GitHub after validation
- **Security**: PAT stored encrypted in Secret Manager, accessed via Workload Identity
- **Multi-Repo Access**: Single PAT can access all PORTCoCONNECT repos (unlike SSH deploy keys which are per-repo)
- **Do NOT commit**: PAT tokens to Git repositories or share publicly
- **Repository connection**: Tested immediately when added
- **Polling**: ArgoCD polls repository every 3 minutes (default) for changes
- **Single Repository**: Only one repo needed for this testing cluster (all configs in one place)
- **Future Enhancement**: Backlog item BL-004 created for GitHub App migration (no expiration, better audit logs)
- **Troubleshooting**: Check repo-server logs for detailed error messages if connection fails
- **Original repo**: `pcc-app-argo-config` will remain for future production use
- **Content copied**: Ingress and NetworkPolicy manifests from original repo's `argocd-nonprod/devtest/` directory
- **HTTPS vs SSH**: ArgoCD repo URL must use HTTPS format (`https://github.com/...`) not SSH (`git@github.com:...`)
- **Username**: Use `git` as username when adding repository (GitHub standard for PAT authentication)
