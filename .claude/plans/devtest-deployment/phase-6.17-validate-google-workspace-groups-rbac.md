# Phase 6.17: Validate Google Workspace Groups RBAC

**Tool**: [WARP] Partner Execution
**Estimated Duration**: 20 minutes

## Purpose

Test Google Workspace OIDC authentication and verify group-based RBAC policies are working correctly by logging in as users from each group (admins, devops, developers, read-only).

## Prerequisites

- Phase 6.16 completed (SSL certificate ACTIVE, DNS resolves)
- Phase 6.6 completed (Google OAuth credentials configured)
- Phase 6.12 completed (OAuth credentials in argocd-secret, Dex restarted)
- Test users available in each Google Workspace group

## Detailed Steps

### Step 1: Verify ArgoCD UI Accessible

```bash
# Check SSL certificate is ACTIVE
gcloud compute ssl-certificates describe argocd-nonprod-cert \
  --format="value(managed.status)"
```

**Expected**: `ACTIVE`

**HALT if**: Not ACTIVE

Open browser to: `https://argocd.nonprod.pcconnect.ai`

**Expected**: ArgoCD login page with "LOG IN VIA GOOGLE" button

**HALT if**: Browser security warning or page not loading

### Step 2: Test Admin Group (role:admin)

**Test User**: User from Google Workspace group `gcp-admins@pcconnect.ai`

1. Click **LOG IN VIA GOOGLE**
2. Authenticate with admin user credentials
3. Grant consent if prompted
4. Should redirect back to ArgoCD dashboard

**Expected Behavior**:
- Full access to all applications
- Can create/modify/delete applications
- Can create/modify/delete projects
- Settings menu visible
- User info shows: `role: admin`

**Test Operations**:
```bash
# Via UI:
- Navigate to Settings → Repositories (should be accessible)
- Navigate to Settings → Clusters (should be accessible)
- Create test project: "test-admin-access" (should succeed)
- Delete test project (should succeed)
```

**Expected**: All operations succeed

### Step 3: Test DevOps Group (role:devops)

**Test User**: User from Google Workspace group `gcp-devops@pcconnect.ai`

1. Log out from admin user
2. Click **LOG IN VIA GOOGLE**
3. Authenticate with devops user credentials

**Expected Behavior**:
- Can view all applications
- Can create/sync/refresh applications
- Can view application logs
- Cannot access Settings menu
- Cannot create/delete projects
- User info shows: `role: devops`

**Test Operations**:
```bash
# Via UI:
- Navigate to Applications (should see all apps)
- Try to access Settings → Repositories (should be blocked)
- Create test application in existing project (should succeed)
- Sync test application (should succeed)
- Delete test application (should succeed)
```

**Expected**: Can manage applications but NOT settings

### Step 4: Test Developer Group (readonly + specific apps)

**Test User**: User from Google Workspace group `gcp-developers@pcconnect.ai`

1. Log out from devops user
2. Click **LOG IN VIA GOOGLE**
3. Authenticate with developer user credentials

**Expected Behavior**:
- Can view applications
- Can view application details and logs
- Cannot create/modify/delete applications
- Cannot sync applications
- Cannot access Settings menu
- User info shows: `role: readonly`

**Test Operations**:
```bash
# Via UI:
- Navigate to Applications (should see apps)
- Try to create application (should be blocked/button disabled)
- Try to sync application (should be blocked/button disabled)
- Try to delete application (should be blocked/button disabled)
- View application logs (should succeed)
```

**Expected**: Read-only access, no modification allowed

### Step 5: Test Read-Only Group

**Test User**: User from Google Workspace group `gcp-read-only@pcconnect.ai`

1. Log out from developer user
2. Click **LOG IN VIA GOOGLE**
3. Authenticate with read-only user credentials

**Expected Behavior**:
- Can view applications
- Can view application details and logs
- Cannot create/modify/delete/sync applications
- Cannot access Settings menu
- User info shows: `role: readonly`

**Test Operations**: Same as Step 4

**Expected**: Complete read-only access

### Step 6: Test Unauthorized User (No Group Membership)

**Test User**: User NOT in any ArgoCD Google Workspace group

1. Log out from previous user
2. Click **LOG IN VIA GOOGLE**
3. Authenticate with unauthorized user credentials

**Expected Behavior**:
- Authentication succeeds with Google
- ArgoCD denies access with error: "Failed to get user info"
- User is NOT logged into ArgoCD

**HALT if**: Unauthorized user gains access

### Step 7: Verify Group Membership in ArgoCD

For each logged-in user, verify group assignments:

```bash
# Get admin password from Secret Manager (if needed for argocd CLI)
ADMIN_PASSWORD=$(kubectl exec -n argocd deployment/argocd-server -- \
  gcloud secrets versions access latest --secret=argocd-admin-password)

# Login via CLI
argocd login argocd.nonprod.pcconnect.ai \
  --username admin \
  --password "${ADMIN_PASSWORD}"

# Check user info for each test user email
argocd account get <user-email>
```

**Expected output shows**:
- Admin user: `Groups: gcp-admins@pcconnect.ai`
- DevOps user: `Groups: gcp-devops@pcconnect.ai`
- Developer user: `Groups: gcp-developers@pcconnect.ai`
- Read-only user: `Groups: gcp-read-only@pcconnect.ai`

### Step 8: Verify RBAC Policy Configuration

```bash
# View RBAC policy
kubectl get configmap argocd-rbac-cm -n argocd -o yaml
```

Verify policies match Phase 6.5 configuration:
```yaml
policy.csv: |
  g, gcp-admins@pcconnect.ai, role:admin
  g, gcp-devops@pcconnect.ai, role:devops
  g, gcp-developers@pcconnect.ai, role:readonly
  g, gcp-read-only@pcconnect.ai, role:readonly
```

### Step 9: Check Dex Logs for Authentication Events

```bash
kubectl logs -n argocd deployment/argocd-dex-server --tail=50 | grep -i oauth
```

**Expected**: Successful OAuth callback entries for each test user

**HALT if**: Errors related to `invalid_client`, `unauthorized_client`, or token validation

## Success Criteria

- ✅ ArgoCD UI accessible via HTTPS
- ✅ "LOG IN VIA GOOGLE" button works
- ✅ Admin users have full access (role:admin)
- ✅ DevOps users can manage apps but not settings (role:devops)
- ✅ Developer users have read-only access (role:readonly)
- ✅ Read-only users have read-only access (role:readonly)
- ✅ Unauthorized users cannot access ArgoCD
- ✅ Group memberships correctly mapped to roles
- ✅ No Dex authentication errors

## HALT Conditions

**HALT if**:
- SSL certificate not ACTIVE
- ArgoCD UI not accessible
- "LOG IN VIA GOOGLE" button missing or not working
- Admin users do not have full access
- DevOps users cannot sync applications
- Developer/read-only users can modify resources
- Unauthorized users gain access
- Dex logs show OAuth errors

**Resolution**:
- Verify SSL cert: `gcloud compute ssl-certificates describe argocd-nonprod-cert`
- Check DNS: `dig argocd.nonprod.pcconnect.ai +short`
- Verify OAuth credentials in argocd-secret: `kubectl get secret argocd-secret -n argocd -o yaml`
- Check Dex logs: `kubectl logs -n argocd deployment/argocd-dex-server`
- Verify RBAC ConfigMap: `kubectl get cm argocd-rbac-cm -n argocd -o yaml`
- Restart Dex if needed: `kubectl rollout restart deployment/argocd-dex-server -n argocd`
- Verify Google OAuth consent screen settings (Phase 6.6)
- Check redirect URI matches: `https://argocd.nonprod.pcconnect.ai/api/dex/callback`

## Next Phase

Proceed to **Phase 6.18**: Create NetworkPolicy Manifests

## Notes

- **CRITICAL**: Test with actual users from each Google Workspace group
- Admin password from Secret Manager is for emergency access only
- Regular users should ALWAYS authenticate via Google Workspace
- RBAC policies are evaluated on every request
- Group membership is synced from Google Workspace via OIDC claims
- Unauthorized users are denied AFTER Google authentication (ArgoCD checks groups)
- If OAuth fails, check Google Cloud Console OAuth consent screen configuration
- Redirect URI must EXACTLY match (trailing slashes matter)
- Dex caches tokens for 24 hours (default) - logout may not immediately revoke access
- Browser may cache OAuth tokens - use incognito mode for clean testing
- Group names are case-sensitive (must match Google Workspace exactly)
- If group mappings don't work, verify Dex connector config in Phase 6.5
- User info is visible in ArgoCD UI: Settings → Accounts (admin only)
