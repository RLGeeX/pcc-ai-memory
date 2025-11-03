# Phase 6.21: Deploy App-of-Apps

**Tool**: [WARP] Partner Execution
**Estimated Duration**: 15 minutes

## Purpose

Deploy the root app-of-apps application to ArgoCD, triggering automatic deployment of NetworkPolicies and Ingress resources via GitOps, demonstrating ArgoCD self-management.

## Prerequisites

- Phase 6.20 completed (app-of-apps manifests created and committed to Git)
- Phase 6.19 completed (Git credentials configured)
- kubectl access to argocd namespace
- Git changes pushed to main branch

## Detailed Steps

### Step 1: Verify Git Repository Is Up-to-Date

```bash
cd ~/pcc/core/pcc-app-argo-config

# Pull latest changes
git pull origin main

# Verify app-of-apps files exist
ls -la argocd-nonprod/devtest/app-of-apps/
```

**Expected**: `root-app.yaml` and `apps/` directory exist

### Step 2: Deploy Root Application

```bash
kubectl apply -f argocd-nonprod/devtest/app-of-apps/root-app.yaml
```

**Expected Output**:
```
application.argoproj.io/argocd-nonprod-root created
```

### Step 3: Watch Root Application Sync

```bash
# Watch root app status
kubectl get application argocd-nonprod-root -n argocd --watch
```

Wait for SYNC STATUS to become "Synced" and HEALTH STATUS to become "Healthy" (~1-2 minutes).

Expected progression:
```
NAME                   SYNC STATUS   HEALTH STATUS
argocd-nonprod-root    OutOfSync     Missing
argocd-nonprod-root    Syncing       Progressing
argocd-nonprod-root    Synced        Healthy
```

Press `Ctrl+C` when both status columns show positive status.

### Step 4: List Child Applications

```bash
kubectl get applications -n argocd
```

**Expected Output**:
```
NAME                          SYNC STATUS   HEALTH STATUS
argocd-nonprod-root           Synced        Healthy
argocd-network-policies       Synced        Healthy
argocd-ingress                Synced        Healthy
```

**HALT if**: Child apps not created after 3 minutes

### Step 5: Verify NetworkPolicies Deployed

```bash
kubectl get networkpolicies -n argocd
```

**Expected Output**: 6 NetworkPolicies created:
```
NAME                              POD-SELECTOR
argocd-server                     app.kubernetes.io/name=argocd-server
argocd-application-controller     app.kubernetes.io/name=argocd-application-controller
argocd-repo-server                app.kubernetes.io/name=argocd-repo-server
argocd-dex-server                 app.kubernetes.io/name=argocd-dex-server
argocd-redis                      app.kubernetes.io/name=argocd-redis
external-dns                      app.kubernetes.io/name=external-dns
```

### Step 6: Verify Ingress Re-Synced

```bash
kubectl get ingress argocd-server -n argocd
```

**Expected**: Ingress exists with ADDRESS assigned (from Phase 6.16)

**Note**: Ingress was deployed manually in Phase 6.16, now managed by ArgoCD

### Step 7: Check Application Details via CLI

```bash
# Get admin password if using CLI
ADMIN_PASSWORD=$(kubectl exec -n argocd deployment/argocd-server -- \
  gcloud secrets versions access latest --secret=argocd-admin-password)

# Login via CLI
argocd login argocd.nonprod.pcconnect.ai \
  --username admin \
  --password "${ADMIN_PASSWORD}"

# View root app details
argocd app get argocd-nonprod-root
```

**Expected**: Shows 2 child applications (network-policies, ingress)

### Step 8: Verify Self-Healing Enabled

Check sync policy:
```bash
argocd app get argocd-nonprod-root -o yaml | grep -A 5 syncPolicy
```

**Expected Output**:
```yaml
syncPolicy:
  automated:
    prune: true
    selfHeal: true
    allowEmpty: false
```

### Step 9: Test Self-Healing (Optional but Recommended)

```bash
# Manually modify a NetworkPolicy (should be reverted automatically)
kubectl label networkpolicy argocd-server -n argocd test=manual-change

# Wait 3 minutes (ArgoCD poll interval)
sleep 180

# Check if label was removed by ArgoCD self-heal
kubectl get networkpolicy argocd-server -n argocd --show-labels
```

**Expected**: Label `test=manual-change` is removed (self-healed)

### Step 10: View Application Tree in UI

1. Log into ArgoCD UI: `https://argocd.nonprod.pcconnect.ai`
2. Click on **argocd-nonprod-root** application
3. View application tree showing child apps

**Expected**:
- Root app shows 2 child applications
- Each child app shows deployed resources (NetworkPolicies, Ingress)
- All resources show "Healthy" and "Synced" status

## Success Criteria

- ✅ Root app deployed successfully
- ✅ Root app SYNC STATUS = Synced
- ✅ Root app HEALTH STATUS = Healthy
- ✅ Child apps (network-policies, ingress) created automatically
- ✅ NetworkPolicies deployed via ArgoCD
- ✅ Ingress managed by ArgoCD
- ✅ Self-healing enabled and verified
- ✅ Application tree visible in UI

## HALT Conditions

**HALT if**:
- Root app deployment fails
- Root app stuck in OutOfSync status
- Child apps not created after 5 minutes
- NetworkPolicies not deployed
- Self-healing test fails (label not removed)

**Resolution**:
- Check application status: `kubectl describe application argocd-nonprod-root -n argocd`
- View application events: `kubectl get events -n argocd --sort-by='.lastTimestamp'`
- Check ArgoCD logs: `kubectl logs -n argocd deployment/argocd-application-controller --tail=50`
- Verify Git repository access: `argocd repo list`
- Test Git connection:
  ```bash
  kubectl exec -n argocd deployment/argocd-repo-server -- \
    git ls-remote git@github.com:ORG/pcc-app-argo-config.git
  ```
- Check application controller logs for sync errors:
  ```bash
  kubectl logs -n argocd statefulset/argocd-application-controller -c application-controller
  ```
- Force sync: `argocd app sync argocd-nonprod-root`
- Delete and recreate if needed: `kubectl delete -f root-app.yaml && kubectl apply -f root-app.yaml`

## Next Phase

Proceed to **Phase 6.22**: Validate NetworkPolicies Applied

## Notes

- **Bootstrap**: Root app is deployed manually ONCE, then manages itself
- **GitOps**: All changes to child apps happen via Git commits
- **Self-Healing**: Manual kubectl changes are reverted automatically within 3 minutes
- **Poll Interval**: ArgoCD checks Git every 3 minutes (default)
- **Sync Wave**: All apps deployed in parallel (no wave annotations)
- **Prune**: Resources removed from Git are deleted from cluster
- **Cascade Delete**: Deleting root app deletes all child apps (be careful!)
- Root app creates Application resources (child apps) in argocd namespace
- Child apps create actual K8s resources (NetworkPolicies, Ingress, etc.)
- Application tree shows nested relationships in ArgoCD UI
- Self-healing test demonstrates GitOps enforcement (manual changes reverted)
- If child apps fail to sync, check repo-server logs for Git access issues
- NetworkPolicies managed by ArgoCD (not manually via kubectl)
- Ingress now managed by ArgoCD (was deployed manually in Phase 6.16)
- Future apps added by creating YAML in `apps/` directory and committing to Git
- Do NOT use `kubectl apply` for child app resources - use Git instead
