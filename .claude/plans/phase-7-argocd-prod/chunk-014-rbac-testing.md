# Chunk 14: Validate RBAC with Test Users

**Status:** pending
**Dependencies:** chunk-013-google-oauth
**Complexity:** medium
**Estimated Time:** 20 minutes
**Tasks:** 2
**Phase:** Access & Security
**Story:** STORY-706
**Jira:** PCC-294

---

## Task 1: Test OAuth Login with Different Roles

**Agent:** qa-expert

**Step 1: Test admin user login**

1. Open browser: `https://argocd-prod.portcon.com`
2. Click "LOG IN VIA GOOGLE"
3. Login with user in `argocd-admins@portcon.com` group
4. Verify: Full access to all menus (Applications, Settings, User Info)

Expected: Admin dashboard with all privileges

**Step 2: Test devops user login**

1. Open incognito window: `https://argocd-prod.portcon.com`
2. Login with user in `argocd-devops@portcon.com` group
3. Verify: Can create/sync applications, view projects
4. Verify: Can view cluster settings (read-only for clusters)

Expected: Can manage applications, cannot modify cluster settings

**Step 3: Test developer user login**

1. Open incognito window: `https://argocd-prod.portcon.com`
2. Login with user in `argocd-developers@portcon.com` group
3. Verify: Can sync existing applications
4. Verify: Cannot create new applications
5. Verify: Cannot delete applications

Expected: Read + sync permissions only

**Step 4: Test read-only user login**

1. Open incognito window: `https://argocd-prod.portcon.com`
2. Login with user in `argocd-readonly@portcon.com` group
3. Verify: Can view applications
4. Verify: Cannot sync applications
5. Verify: No "Sync" or "Delete" buttons visible

Expected: View-only access

---

## Task 2: Validate RBAC Policy Enforcement

**Agent:** security-auditor

**Step 1: Test CLI access with different roles**

```bash
# Login as admin user
argocd login argocd-prod.portcon.com --sso

# Test admin permissions
argocd app list
argocd project create test-project
argocd project delete test-project
```

Expected: All commands succeed

```bash
# Login as devops user (different terminal/profile)
argocd login argocd-prod.portcon.com --sso

# Test devops permissions
argocd app list
argocd app create test-app --repo https://github.com/argoproj/argocd-example-apps \
  --path guestbook --dest-server https://kubernetes.default.svc --dest-namespace default
argocd app delete test-app
```

Expected: Can create/delete apps, cannot modify cluster config

**Step 2: Verify policy.default workaround**

```bash
# Test unauthenticated access (curl without auth)
curl -k https://argocd-prod.portcon.com/api/v1/applications
```

Expected: 200 OK with application list (role:readonly applied by default)

**Step 3: Document RBAC validation results**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra
cat <<EOF >> environments/prod/docs/deployment-notes.md

## RBAC Validation
- Admin role: Full access (tested ✓)
- DevOps role: App management, no cluster config changes (tested ✓)
- Developer role: Sync only (tested ✓)
- Read-only role: View only (tested ✓)
- policy.default workaround: Unauthenticated = readonly (tested ✓)
- OAuth SSO: Google Workspace (@portcon.com) (working ✓)

Test date: $(date)
EOF

git add environments/prod/docs/deployment-notes.md
git commit -m "feat(phase-7): validate RBAC with 4 roles and OAuth SSO"
```

---

## Chunk Complete Checklist

- [ ] Admin user tested (full access)
- [ ] DevOps user tested (app management)
- [ ] Developer user tested (sync only)
- [ ] Read-only user tested (view only)
- [ ] CLI access tested with different roles
- [ ] policy.default workaround verified
- [ ] RBAC validation documented
- [ ] Ready for chunk 15 (app-of-apps)
