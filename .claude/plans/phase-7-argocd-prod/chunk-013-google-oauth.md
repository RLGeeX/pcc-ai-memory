# Chunk 13: Configure Google OAuth and Create Workspace Groups

**Status:** pending
**Dependencies:** chunk-012-ssl-cert-validation
**Complexity:** medium
**Estimated Time:** 25 minutes
**Tasks:** 3
**Phase:** Access & Security
**Story:** STORY-706
**Jira:** PCC-293

---

## Task 1: Create Google Workspace Groups

**Agent:** general-purpose

**Step 1: Document required groups (manual creation)**

Create in Google Workspace Admin Console (`admin.google.com`):

1. **argocd-admins@portcon.com**
   - Description: "ArgoCD Production Administrators"
   - Members: DevOps leads, platform admins

2. **argocd-devops@portcon.com**
   - Description: "ArgoCD Production DevOps Team"
   - Members: DevOps engineers

3. **argocd-developers@portcon.com**
   - Description: "ArgoCD Production Developers"
   - Members: Application developers

4. **argocd-readonly@portcon.com**
   - Description: "ArgoCD Production Read-Only Users"
   - Members: Stakeholders, observers

**Step 2: Verify groups created**

```bash
# Manual verification in Google Workspace Admin Console
# Confirm all 4 groups exist
```

---

## Task 2: Configure Google OAuth in GCP

**Agent:** cloud-architect

**Step 1: Create OAuth 2.0 Client ID (if not exists)**

```bash
# Navigate to: GCP Console > APIs & Services > Credentials
# Or use gcloud (if OAuth consent screen already configured)

# Create OAuth client for ArgoCD
gcloud alpha iap oauth-clients create \
  --project=pcc-prj-devops-prod \
  --display-name="ArgoCD Production" \
  --oauth2-client-secret-create
```

Note: If command fails, create manually in GCP Console:
1. Go to: APIs & Services > Credentials > Create Credentials > OAuth 2.0 Client ID
2. Application type: Web application
3. Name: "ArgoCD Production"
4. Authorized redirect URIs: `https://argocd-prod.portcon.com/api/dex/callback`

**Step 2: Get Client ID and Secret**

```bash
# From GCP Console > Credentials, copy:
CLIENT_ID="xxxx-xxxx.apps.googleusercontent.com"
CLIENT_SECRET="GOCSPX-xxxxx"
```

**Step 3: Store secrets in Secret Manager**

```bash
echo -n "$CLIENT_ID" | gcloud secrets create argocd-prod-oauth-client-id \
  --project=pcc-prj-devops-prod \
  --data-file=-

echo -n "$CLIENT_SECRET" | gcloud secrets create argocd-prod-oauth-client-secret \
  --project=pcc-prj-devops-prod \
  --data-file=-
```

---

## Task 3: Update ArgoCD Configuration with OAuth

**Agent:** gitops-engineer

**Step 1: Update argocd-cm ConfigMap**

```bash
kubectl patch configmap argocd-cm -n argocd --type merge -p "$(cat <<EOF
data:
  dex.config: |
    connectors:
    - type: google
      id: google
      name: Google
      config:
        clientID: $CLIENT_ID
        clientSecret: $CLIENT_SECRET
        redirectURI: https://argocd-prod.portcon.com/api/dex/callback
        hostedDomains:
        - portcon.com
  url: https://argocd-prod.portcon.com
EOF
)"
```

**Step 2: Restart ArgoCD server to apply OAuth config**

```bash
kubectl rollout restart deployment argocd-server -n argocd
kubectl rollout status deployment argocd-server -n argocd --timeout=300s
```

Expected: Deployment rolled out successfully

**Step 3: Document OAuth configuration**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra
cat <<EOF >> environments/prod/docs/deployment-notes.md

## OAuth Configuration
- Provider: Google Workspace (portcon.com)
- Client ID: Stored in Secret Manager (argocd-prod-oauth-client-id)
- Redirect URI: https://argocd-prod.portcon.com/api/dex/callback
- Groups: 4 Google Workspace Groups (admins, devops, developers, readonly)
- Hosted Domain: portcon.com (only @portcon.com users)
EOF

git add environments/prod/docs/deployment-notes.md
git commit -m "feat(phase-7): configure Google OAuth for argocd-prod"
```

---

## Chunk Complete Checklist

- [ ] 4 Google Workspace Groups created
- [ ] OAuth 2.0 Client ID created in GCP
- [ ] Client ID/Secret stored in Secret Manager
- [ ] ArgoCD ConfigMap updated with OAuth config
- [ ] ArgoCD server restarted
- [ ] OAuth configuration documented
- [ ] Ready for chunk 14 (RBAC testing)
