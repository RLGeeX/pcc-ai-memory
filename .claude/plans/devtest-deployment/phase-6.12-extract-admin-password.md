# Phase 6.12: Extract Admin Password to Secret Manager

**Tool**: [WARP] Partner Execution
**Estimated Duration**: 15 minutes

## Purpose

Extract ArgoCD initial admin password from K8s secret, store in GCP Secret Manager via Workload Identity, populate Google OAuth credentials, then delete the K8s secret for security.

## Prerequisites

- Phase 6.11 completed (Workload Identity validated)
- Phase 6.6 completed (Google OAuth credentials created)
- argocd-server SA has `secretmanager.admin` role (Phase 6.7)
- OAuth credentials available from Phase 6.6

## Detailed Steps

### Step 1: Extract Admin Password

```bash
ADMIN_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo "Admin password extracted (length: ${#ADMIN_PASSWORD} chars)"
```

**Expected**: Password length ~30-40 characters

**HALT if**: Secret not found or password empty

### Step 2: Store in Secret Manager (Idempotent)

```bash
# Check if secret exists, create or add version accordingly
if gcloud secrets describe argocd-admin-password --project=pcc-prj-devops-nonprod >/dev/null 2>&1; then
  # Secret exists, add new version
  echo -n "${ADMIN_PASSWORD}" | gcloud secrets versions add argocd-admin-password \
    --data-file=-
else
  # Secret doesn't exist, create it
  echo -n "${ADMIN_PASSWORD}" | gcloud secrets create argocd-admin-password \
    --data-file=- \
    --replication-policy=user-managed \
    --locations=us-east4 \
    --labels=environment=nonprod,managed-by=terraform
fi
```

**Expected**: Either `Created secret [argocd-admin-password]` or `Created version [1] of the secret [argocd-admin-password]`

**Note**: Runs from workstation using your gcloud credentials (not Workload Identity). This makes the step idempotent for re-runs.

### Step 3: Verify Secret Created

```bash
gcloud secrets describe argocd-admin-password --format=json
```

Expected output showing replication in us-east4.

### Step 4: Delete K8s Admin Secret (Security)

```bash
kubectl delete secret argocd-initial-admin-secret -n argocd
```

**Expected**: `secret "argocd-initial-admin-secret" deleted`

**CRITICAL**: Only delete AFTER confirming Step 2 succeeded.

### Step 5: Update ArgoCD Secret with Google OAuth Credentials from Secret Manager

**Fetch OAuth credentials from Secret Manager:**
```bash
# Retrieve credentials from Secret Manager (populated in Phase 6.6)
CLIENT_ID=$(gcloud secrets versions access latest \
  --secret=argocd-oauth-client-id \
  --project=pcc-prj-devops-nonprod)

CLIENT_SECRET=$(gcloud secrets versions access latest \
  --secret=argocd-oauth-client-secret \
  --project=pcc-prj-devops-nonprod)

# Verify credentials were retrieved
echo "Client ID length: ${#CLIENT_ID} chars"
echo "Client Secret length: ${#CLIENT_SECRET} chars"
```

**Expected:**
```
Client ID length: 72 chars (typical for Google OAuth)
Client Secret length: 35 chars (typical GOCSPX- format)
```

**HALT if**: Either value is empty or Secret Manager access fails

**Patch the argocd-secret:**
```bash
kubectl patch secret argocd-secret -n argocd \
  --type='json' \
  -p="[
    {\"op\": \"add\", \"path\": \"/data/dex.google.clientID\", \"value\": \"$(echo -n ${CLIENT_ID} | base64 -w0)\"},
    {\"op\": \"add\", \"path\": \"/data/dex.google.clientSecret\", \"value\": \"$(echo -n ${CLIENT_SECRET} | base64 -w0)\"}
  ]"

# Clear variables from memory
unset CLIENT_ID CLIENT_SECRET
```

**Expected**: `secret/argocd-secret patched`

### Step 6: Restart Dex to Pick Up OAuth Config

```bash
kubectl rollout restart deployment/argocd-dex-server -n argocd
```

Wait for rollout to complete:
```bash
kubectl rollout status deployment/argocd-dex-server -n argocd
```

**Expected**: `deployment "argocd-dex-server" successfully rolled out`

### Step 7: Verify OAuth Config in ArgoCD

```bash
kubectl exec -n argocd deployment/argocd-server -- \
  argocd-util settings validate
```

**Expected**: No errors related to Dex or OAuth configuration.

## Success Criteria

- ✅ Admin password extracted successfully
- ✅ Password stored in Secret Manager (us-east4)
- ✅ K8s argocd-initial-admin-secret deleted
- ✅ **Google OAuth clientID and clientSecret fetched from Secret Manager**
- ✅ OAuth credentials added to argocd-secret K8s secret
- ✅ Dex restarted and healthy
- ✅ ArgoCD settings validation passes

## HALT Conditions

**HALT if**:
- argocd-initial-admin-secret not found
- Secret Manager creation fails (permission denied)
- **OAuth credentials not found in Secret Manager** (Step 5 fails)
- OAuth credential fetch returns empty values
- Dex fails to restart after OAuth update

**Resolution**:
- Verify secret exists: `kubectl get secret -n argocd`
- Check argocd-server SA IAM: `gcloud projects get-iam-policy pcc-prj-devops-nonprod --flatten="bindings[].members" --filter="bindings.members:argocd-server@"`
- **Verify OAuth secrets in Secret Manager**: `gcloud secrets list --filter="name:argocd-oauth" --project=pcc-prj-devops-nonprod`
- **Re-run Phase 6.6** if OAuth secrets are missing
- Check Dex logs: `kubectl logs -n argocd deployment/argocd-dex-server`

## Next Phase

Proceed to **Phase 6.13**: Configure Cloudflare API Token

## Secret Handling Security Procedures

### Admin Password Storage Strategy

**Why two locations?**
1. **K8s Secret** (initial): Generated by ArgoCD Helm chart, ephemeral storage
2. **Secret Manager** (permanent): Durable, encrypted, audited, emergency access

**Migration Flow**:
```
ArgoCD Helm Install
  ↓
K8s Secret Created (argocd-initial-admin-secret)
  ↓
Extract Password ← YOU ARE HERE
  ↓
Store in Secret Manager (argocd-admin-password)
  ↓
Delete K8s Secret (security best practice)
  ↓
Future Admin Access: gcloud secrets versions access latest
```

### Security Checklist

Before deleting K8s secret, verify:
- ✅ Step 2 completed without errors
- ✅ Step 3 shows secret exists in Secret Manager
- ✅ Can retrieve password: `gcloud secrets versions access latest --secret=argocd-admin-password`
- ✅ Password length matches original (30-40 chars)

**If any check fails**: HALT. Do NOT delete K8s secret. Debug Secret Manager issue first.

### Emergency Recovery Procedures

**If you deleted K8s secret before confirming Secret Manager storage**:

1. **Attempt password retrieval**:
   ```bash
   gcloud secrets versions access latest --secret=argocd-admin-password
   ```

2. **If retrieval fails**, reset admin password:
   ```bash
   # Generate new password
   NEW_PASSWORD=$(openssl rand -base64 32)

   # Update ArgoCD admin account
   kubectl -n argocd patch secret argocd-secret \
     -p "{\"stringData\": {\"admin.password\": \"$(echo -n $NEW_PASSWORD | bcrypt -c 10)\"}}"

   # Store new password in Secret Manager
   echo -n "$NEW_PASSWORD" | gcloud secrets versions add argocd-admin-password --data-file=-

   # Clear from shell
   unset NEW_PASSWORD
   ```

3. **If Secret Manager doesn't exist**, recreate following Step 2

### OAuth Credentials Handling

**Storage Locations**:
1. **Secret Manager** (source of truth): `argocd-oauth-client-id` and `argocd-oauth-client-secret`
2. **K8s secret** (runtime): `argocd-secret` - Dex reads from here

**Why both?**
- Secret Manager: Secure storage, audit trail, versioning, rotation support
- K8s Secret: Dex requires local secret access (no Secret Manager integration)

**Flow**: Secret Manager → (this step) → K8s Secret → Dex reads at runtime

**Rotation Process**:
1. Create new OAuth credentials in Google Cloud Console
2. Store new credentials in Secret Manager: `gcloud secrets versions add argocd-oauth-client-id ...`
3. Re-run Step 5 to fetch latest version and update K8s secret
4. Restart Dex (Step 6)
5. Test authentication (Phase 6.17)
6. Revoke old credentials in Google Console

**Security Benefits**:
- ✅ Credentials never in shell history (fetched from Secret Manager)
- ✅ Audit trail of access in Cloud Logging
- ✅ Automatic encryption at rest
- ✅ Version control for rollback

### Access Control Best Practices

**Admin Password**:
- Use ONLY for emergency access
- Regular users: Google Workspace SSO
- Rotate every 90 days (nonprod) or 30 days (prod)
- Audit access: `gcloud secrets versions list argocd-admin-password`

**OAuth Credentials**:
- Rotate every 90 days
- Monitor OAuth consent screen for suspicious apps
- Keep clientSecret in K8s secret only (never commit to Git)

## Notes

- **CRITICAL**: Delete K8s secret ONLY after Secret Manager storage confirmed
- Admin password stored in Secret Manager is used for emergency access
- Regular users authenticate via Google Workspace (configured in Phase 6.5)
- **OAuth credentials**: Stored in Secret Manager (source of truth), fetched and copied to K8s secret for Dex runtime
- **Security improvement**: OAuth credentials never touch shell history or temp files (fetched directly from Secret Manager)
- Dex restart required to load new OAuth credentials
- Secret creation runs from workstation (uses your gcloud credentials)
- If Secret Manager creation fails, admin secret remains in K8s (can retry)
- **Password rotation**: Use `gcloud secrets versions add` to create new version
- **OAuth rotation**: Add new version to Secret Manager → re-run Step 5 → restart Dex
- **Audit trail**: All Secret Manager access logged in Cloud Audit Logs
- **Backup**: Secret Manager provides automatic versioning (can rollback)
- **Terraform managed**: Secret Manager resources created in Phase 6.7, values populated manually
