# Phase 6.19: Configure Git Credentials

**Tool**: [WARP] Partner Execution
**Estimated Duration**: 15 minutes

## Purpose

Configure Git repository credentials in ArgoCD to enable syncing from private GitHub repositories, using either SSH key or Personal Access Token (PAT) method.

## Prerequisites

- Phase 6.18 completed (NetworkPolicy manifests created)
- Phase 6.17 completed (Google Workspace RBAC validated)
- GitHub account with access to `pcc-app-argo-config` repository
- ArgoCD UI accessible

## Detailed Steps

### Method A: SSH Key (Recommended)

#### Step 1: Generate SSH Key Pair

```bash
# Generate ED25519 key (more secure than RSA)
ssh-keygen -t ed25519 -C "argocd-nonprod@pcconnect.ai" -f ~/.ssh/argocd-nonprod-ed25519 -N ""

# Display public key
cat ~/.ssh/argocd-nonprod-ed25519.pub
```

**Expected**: Public key starting with `ssh-ed25519 AAAA...`

#### Step 2: Add Public Key to GitHub

1. Navigate to GitHub repository: `https://github.com/ORG/pcc-app-argo-config`
2. Go to **Settings → Deploy keys**
3. Click **Add deploy key**
4. **Title**: `ArgoCD NonProd (DevTest)`
5. **Key**: Paste public key from Step 1
6. **Allow write access**: Leave UNCHECKED (read-only)
7. Click **Add key**

#### Step 3: Add Private Key to ArgoCD via UI

1. Log into ArgoCD UI: `https://argocd.nonprod.pcconnect.ai`
2. Navigate to **Settings → Repositories**
3. Click **Connect Repo**
4. Select **VIA SSH**
5. Fill in details:
   - **Repository URL**: `git@github.com:ORG/pcc-app-argo-config.git`
   - **SSH private key**: Paste contents of `~/.ssh/argocd-nonprod-ed25519`
   - **Skip server verification**: Leave UNCHECKED
6. Click **Connect**

**Expected**: Connection status shows "Successful"

#### Step 4: Verify Repository Connection

```bash
# Get admin password if using CLI
ADMIN_PASSWORD=$(gcloud secrets versions access latest --secret=argocd-admin-password)

# Login via CLI
argocd login argocd.nonprod.pcconnect.ai \
  --username admin \
  --password "${ADMIN_PASSWORD}"

# List repositories
argocd repo list
```

**Expected**: Repository shows CONNECTION STATUS = "Successful"

**Note**: Retrieves password from Secret Manager using your workstation gcloud credentials.

### Method B: Personal Access Token (PAT) - Alternative

#### Step 1: Create GitHub PAT

1. Navigate to GitHub: **Settings → Developer settings → Personal access tokens → Tokens (classic)**
2. Click **Generate new token (classic)**
3. **Note**: `ArgoCD NonProd (DevTest)`
4. **Expiration**: 90 days (or custom)
5. **Scopes**:
   - ✅ `repo` (full control of private repositories)
6. Click **Generate token**
7. **CRITICAL**: Copy token immediately (only shown once)

Example token format: `ghp_xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx`

#### Step 2: Store Token in Secret Manager

```bash
# Store token temporarily
export GITHUB_PAT="ghp_YOUR_TOKEN_HERE"

# Check if secret exists, create or add version accordingly
if gcloud secrets describe github-argocd-pat --project=pcc-prj-devops-nonprod >/dev/null 2>&1; then
  # Secret exists, add new version
  echo -n "${GITHUB_PAT}" | gcloud secrets versions add github-argocd-pat \
    --data-file=-
else
  # Secret doesn't exist, create it
  echo -n "${GITHUB_PAT}" | gcloud secrets create github-argocd-pat \
    --data-file=- \
    --replication-policy=user-managed \
    --locations=us-east4 \
    --labels=environment=nonprod,managed-by=manual
fi

# Clear token from shell
unset GITHUB_PAT
```

**Expected**: Either `Created secret [github-argocd-pat]` or `Created version [1] of the secret [github-argocd-pat]`

**Note**: Runs from workstation using your gcloud credentials (not Workload Identity). This makes the step idempotent for re-runs.

#### Step 3: Add Repository via UI with HTTPS

1. Log into ArgoCD UI: `https://argocd.nonprod.pcconnect.ai`
2. Navigate to **Settings → Repositories**
3. Click **Connect Repo**
4. Select **VIA HTTPS**
5. Fill in details:
   - **Repository URL**: `https://github.com/ORG/pcc-app-argo-config.git`
   - **Username**: GitHub username
   - **Password**: Paste PAT from Step 1
6. Click **Connect**

**Expected**: Connection status shows "Successful"

### Step 5: Test Repository Access

```bash
# Via CLI
argocd repo get git@github.com:ORG/pcc-app-argo-config.git  # If SSH
# OR
argocd repo get https://github.com/ORG/pcc-app-argo-config.git  # If HTTPS
```

**Expected**: Shows repository details with CONNECTION STATUS = "Successful"

### Step 6: Verify ArgoCD Can List Branches

```bash
# This validates read access to the repository
argocd repo get git@github.com:ORG/pcc-app-argo-config.git --show-urls
```

**Expected**: Shows available branches (main, develop, etc.)

### Step 7: Clean Up Local Keys (SSH Method Only)

```bash
# Securely delete local private key (now stored in ArgoCD)
shred -u ~/.ssh/argocd-nonprod-ed25519

# Keep public key for reference
# Do NOT delete: ~/.ssh/argocd-nonprod-ed25519.pub
```

## Success Criteria

- ✅ SSH key generated (Method A) OR GitHub PAT created (Method B)
- ✅ Public key added to GitHub deploy keys (Method A) OR PAT stored in Secret Manager (Method B)
- ✅ Repository added to ArgoCD successfully
- ✅ Connection status shows "Successful"
- ✅ ArgoCD can list repository branches
- ✅ Local private key deleted (Method A)

## HALT Conditions

**HALT if**:
- Cannot generate SSH key
- GitHub deploy key addition fails (insufficient permissions)
- ArgoCD repository connection fails
- Connection status shows error
- Cannot list repository branches

**Resolution**:
- **SSH method**: Verify SSH key format (ED25519 or RSA)
- **SSH method**: Check GitHub deploy key has been added
- **SSH method**: Verify repository URL format: `git@github.com:ORG/REPO.git`
- **PAT method**: Verify PAT has `repo` scope
- **PAT method**: Check PAT has not expired
- **PAT method**: Verify repository URL format: `https://github.com/ORG/REPO.git`
- Check ArgoCD logs: `kubectl logs -n argocd deployment/argocd-repo-server`
- Test Git access manually:
  ```bash
  GIT_SSH_COMMAND="ssh -i ~/.ssh/argocd-nonprod-ed25519" git ls-remote git@github.com:ORG/pcc-app-argo-config.git
  ```
- Verify network connectivity: `kubectl exec -n argocd deployment/argocd-repo-server -- curl -I https://github.com`

## Next Phase

Proceed to **Phase 6.20**: Create App-of-Apps Manifests

## Notes

- **RECOMMENDATION**: Use SSH method (Method A) - more secure and no expiration
- **PAT method**: Token expires (90 days default) - requires manual renewal
- **SSH method**: Deploy keys are per-repository - need separate key for each repo
- **PAT method**: Single token can access multiple repositories
- GitHub deploy key is read-only by default (ArgoCD only needs read access)
- ArgoCD stores credentials encrypted in K8s secrets
- Private key stored in ArgoCD secret: `argocd-repo-creds-XXXXXX`
- Do NOT commit private keys or PATs to Git
- SSH key uses ED25519 algorithm (more secure than RSA 2048)
- If using PAT, rotate every 90 days (or use GitHub App for longer-lived tokens)
- Repository connection is tested immediately when added
- ArgoCD polls repository every 3 minutes (default) for changes
- Multiple repositories can be added (one per app or shared)
- For production, consider using GitHub App authentication (no expiration)
- If connection fails, check repo-server logs for detailed error messages
