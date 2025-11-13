# Phase 6.6: Configure Google Workspace OAuth

**Tool**: [CC] Claude Code (Documentation)
**Estimated Duration**: 15 minutes

## Purpose

Document the process for creating Google Workspace OAuth 2.0 credentials that ArgoCD will use for OIDC authentication. These credentials enable Google Workspace users to log into ArgoCD using their Google accounts.

## Prerequisites

- Google Cloud Console access with permissions to create OAuth credentials
- Google Workspace admin access (or coordination with admin)
- Understanding of OAuth 2.0 redirect URIs

## Detailed Steps

### Step 1: Navigate to OAuth Consent Screen

1. Open Google Cloud Console: https://console.cloud.google.com
2. Select project: `pcc-prj-devops-nonprod`
3. Navigate to: **APIs & Services** → **OAuth consent screen**
4. If not already configured, create OAuth consent screen:
   - User Type: **Internal** (Google Workspace users only)
   - App name: `ArgoCD NonProd`
   - User support email: `gcp-devops@pcconnect.ai`
   - Developer contact: `gcp-devops@pcconnect.ai`
   - Scopes: Default (email, profile, openid)
   - Click **Save and Continue**

### Step 2: Create OAuth 2.0 Client ID

1. Navigate to: **APIs & Services** → **Credentials**
2. Click **+ CREATE CREDENTIALS** → **OAuth client ID**
3. Application type: **Web application**
4. Name: `argocd-nonprod-oidc`
5. **Authorized redirect URIs**:
   - Add: `https://argocd.nonprod.pcconnect.ai/api/dex/callback`
   - **CRITICAL**: This URI must exactly match the domain from Phase 6.5 dex.config
6. Click **Create**

### Step 3: Record Credentials and Store in Secret Manager

After clicking Create, Google will display:
- **Client ID**: A long string like `123456789-abc...xyz.apps.googleusercontent.com`
- **Client Secret**: A string like `GOCSPX-abc...xyz`

**IMPORTANT**: Copy these credentials immediately and store securely in Secret Manager.

**Store in Secret Manager (RECOMMENDED):**
```bash
# Set credentials (paste the actual values from Google Console)
CLIENT_ID="<paste-client-id-here>"
CLIENT_SECRET="<paste-client-secret-here>"

# Store OAuth Client ID in Secret Manager
echo -n "${CLIENT_ID}" | \
  gcloud secrets versions add argocd-oauth-client-id \
    --project=pcc-prj-devops-nonprod \
    --data-file=-

# Store OAuth Client Secret in Secret Manager
echo -n "${CLIENT_SECRET}" | \
  gcloud secrets versions add argocd-oauth-client-secret \
    --project=pcc-prj-devops-nonprod \
    --data-file=-

# Clear variables from memory
unset CLIENT_ID CLIENT_SECRET

# Verify secrets were created
gcloud secrets describe argocd-oauth-client-id \
  --project=pcc-prj-devops-nonprod \
  --format="value(name)"

gcloud secrets describe argocd-oauth-client-secret \
  --project=pcc-prj-devops-nonprod \
  --format="value(name)"
```

**Expected Output:**
```
Created version [1] of the secret [argocd-oauth-client-id]
Created version [1] of the secret [argocd-oauth-client-secret]
```

**Note:** The Secret Manager resources were created by Terraform in Phase 6.7. This step just populates the secret values.

**Alternative (NOT RECOMMENDED - For reference only):**
```bash
# If you need a temporary local copy (NOT recommended, use Secret Manager instead)
cat > /tmp/argocd-oauth-creds.txt <<EOF
# ArgoCD NonProd Google OAuth Credentials
# Created: $(date)
# Project: pcc-prj-devops-nonprod

CLIENT_ID="<paste-client-id-here>"
CLIENT_SECRET="<paste-client-secret-here>"
REDIRECT_URI="https://argocd.nonprod.pcconnect.ai/api/dex/callback"
EOF

chmod 600 /tmp/argocd-oauth-creds.txt
```

### Step 4: Verify Redirect URI

**CRITICAL VALIDATION**: Ensure redirect URI exactly matches:
- Protocol: `https://`
- Domain: `argocd.nonprod.pcconnect.ai`
- Path: `/api/dex/callback`
- NO trailing slash
- NO query parameters

Incorrect URI will cause OAuth flow to fail with error:
```
Error: redirect_uri_mismatch
```

### Step 5: Test Domains Configuration

Verify `hostedDomains` in Phase 6.5 values-autopilot.yaml matches:
```yaml
dex.config: |
  connectors:
  - type: oidc
    config:
      hostedDomains:
      - pcconnect.ai  # ← Must match your Google Workspace domain
```

This restricts login to users with `@pcconnect.ai` email addresses only.

### Step 6: Document Credentials for Phase 6.12

Create a reminder note for Phase 6.12 execution:
```markdown
# OAuth Credentials for Phase 6.12

When executing Phase 6.12, you will need to update the argocd-secret ConfigMap with:

CLIENT_ID: <from Step 3>
CLIENT_SECRET: <from Step 3>

Store these in Secret Manager or pass directly to kubectl during Phase 6.12.
```

### Step 7: Security Best Practices

**DO**:
- ✅ Store credentials in Secret Manager or temporary encrypted file
- ✅ Use Internal OAuth consent screen (Google Workspace only)
- ✅ Restrict to pcconnect.ai domain via hostedDomains
- ✅ Rotate credentials if exposed

**DON'T**:
- ❌ Commit credentials to Git
- ❌ Use External OAuth consent screen (public access)
- ❌ Share credentials via unencrypted channels (email, Slack)
- ❌ Reuse credentials across environments

## Success Criteria

- ✅ OAuth consent screen configured (Internal, Google Workspace)
- ✅ OAuth client ID created with correct name
- ✅ Redirect URI exactly matches: `https://argocd.nonprod.pcconnect.ai/api/dex/callback`
- ✅ Client ID and Client Secret recorded securely
- ✅ **Credentials stored in Secret Manager** (`argocd-oauth-client-id` and `argocd-oauth-client-secret`)
- ✅ Secret Manager versions verified (version 1 created)
- ✅ hostedDomains verified to match Google Workspace domain

## HALT Conditions

**HALT if**:
- Google Cloud Console access denied (missing IAM permissions)
- Redirect URI cannot be added (domain not verified)
- OAuth consent screen cannot be created

**Resolution**:
- Request `roles/oauthconfig.editor` IAM role
- Verify domain ownership in Google Workspace
- Contact Google Workspace admin for assistance

## Next Phase

Proceed to **Phase 6.7**: Deploy ArgoCD Infrastructure (WARP execution begins)

**IMPORTANT**: Before Phase 6.7, ensure:
1. Credentials from Step 3 are saved securely
2. Redirect URI is correct
3. Partner executing Phase 6.12 has access to credentials

## Notes

- **Credentials stored in Secret Manager** for security, audit trail, and rotation
- These credentials will be fetched from Secret Manager in Phase 6.12 and populated into K8s secret
- Google Workspace Groups (gcp-admins, gcp-devops, etc.) must exist before Phase 6.17
- OAuth flow: User clicks "Login with Google" → Google auth → Dex validates → ArgoCD RBAC applied
- If redirect URI changes (domain change), you MUST update OAuth client settings and Phase 6.5 dex.config
- Internal OAuth consent screen = only @pcconnect.ai users can authenticate
- Secret Manager provides automatic encryption, versioning, and audit logging
- Credentials rotation: Create new OAuth client in Google Console → Add new version to Secret Manager → Update K8s secret (Phase 6.12) → Revoke old credentials
- **Security**: Never commit OAuth credentials to Git or store in plaintext files
