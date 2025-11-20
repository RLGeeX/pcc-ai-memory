# Phase 6.24: Deploy Hello-World via ArgoCD

**Tool**: [WARP] Partner Execution
**Estimated Duration**: 15 minutes

## Purpose

Wait for ArgoCD to automatically sync and deploy the hello-world application, demonstrating GitOps workflow, CreateNamespace capability, and cross-namespace application management.

## Prerequisites

- Phase 6.23 completed (hello-world manifests created and committed to Git)
- Phase 6.21 completed (app-of-apps deployed)
- Git changes pushed to main branch

## Detailed Steps

### Step 1: Verify Git Changes Are Pushed

```bash
cd ~/pcc/core/pcc-argocd-config-nonprod

# Verify clean working directory
git status

# Verify hello-world app manifest exists
cat devtest/app-of-apps/apps/hello-world.yaml
```

**Expected**: Working directory clean, hello-world.yaml exists

### Step 2: Wait for ArgoCD to Detect Changes

ArgoCD polls Git repository every 3 minutes (default). Wait up to 5 minutes for automatic sync.

**Alternative**: Force immediate sync:
```bash
argocd app sync argocd-nonprod-root
```

### Step 3: Watch for Hello-World Application Creation

```bash
kubectl get applications -n argocd --watch
```

Wait for `hello-world-nonprod` application to appear (~3-5 minutes).

Expected progression:
```
NAME                          SYNC STATUS   HEALTH STATUS
argocd-nonprod-root           Synced        Healthy
argocd-network-policies       Synced        Healthy
argocd-ingress                Synced        Healthy
hello-world-nonprod           OutOfSync     Missing
hello-world-nonprod           Syncing       Progressing
hello-world-nonprod           Synced        Healthy
```

Press `Ctrl+C` when hello-world-nonprod shows Synced/Healthy.

### Step 4: Verify Namespace Created by ArgoCD

```bash
kubectl get namespace hello-world
```

**Expected Output**:
```
NAME          STATUS   AGE
hello-world   Active   2m
```

**Key Point**: ArgoCD created this namespace automatically (CreateNamespace=true)

### Step 5: Verify Deployment Created

```bash
kubectl get deployment -n hello-world
```

**Expected Output**:
```
NAME          READY   UP-TO-DATE   AVAILABLE   AGE
hello-world   2/2     2            2           2m
```

**HALT if**: READY shows 0/2 or AVAILABLE shows 0

### Step 6: Verify Pods Running

```bash
kubectl get pods -n hello-world
```

**Expected Output**: 2 pods in Running state
```
NAME                           READY   STATUS    RESTARTS   AGE
hello-world-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
hello-world-xxxxxxxxxx-xxxxx   1/1     Running   0          2m
```

### Step 7: Verify Service Created

```bash
kubectl get service -n hello-world
```

**Expected Output**:
```
NAME          TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
hello-world   ClusterIP   10.x.x.x        <none>        80/TCP    2m
```

### Step 8: Test Application Responds

```bash
# Get pod name
POD_NAME=$(kubectl get pods -n hello-world -l app=hello-world -o jsonpath='{.items[0].metadata.name}')

# Test via service
kubectl exec -n argocd deployment/argocd-server -- \
  curl -sS http://hello-world.hello-world.svc.cluster.local
```

**Expected Output**:
```
Hello, world!
Version: 2.0.0
Hostname: hello-world-xxxxxxxxxx-xxxxx
```

### Step 9: Verify Application Health in ArgoCD

```bash
# Via CLI
argocd app get hello-world-nonprod
```

**Expected Output**:
```
Name:               hello-world-nonprod
Project:            default
Server:             https://kubernetes.default.svc
Namespace:          hello-world
URL:                https://argocd.nonprod.pcconnect.ai/applications/hello-world-nonprod
Repo:               git@github.com:PORTCoCONNECT/pcc-argocd-config-nonprod.git
Target:             main
Path:               hello-world
SyncWindow:         Sync Allowed
Sync Policy:        Automated (Prune)
Sync Status:        Synced to main (xxxxx)
Health Status:      Healthy
```

### Step 10: View Application in ArgoCD UI

1. Log into ArgoCD UI: `https://argocd.nonprod.pcconnect.ai`
2. Navigate to **Applications**
3. Click on **hello-world-nonprod**
4. View application tree showing:
   - Namespace: hello-world
   - Deployment: hello-world
   - ReplicaSet: hello-world-xxxxxxxxxx
   - Pods: 2 pods
   - Service: hello-world

**Expected**: All resources show green (Healthy and Synced)

### Step 11: Test Self-Healing (Optional)

```bash
# Manually scale deployment (should be reverted by ArgoCD)
kubectl scale deployment hello-world -n hello-world --replicas=3

# Wait 3 minutes for self-heal
sleep 180

# Check replica count
kubectl get deployment hello-world -n hello-world -o jsonpath='{.spec.replicas}'
```

**Expected**: Replica count reverted to `2` (self-healed)

### Step 12: Verify App-of-Apps Hierarchy

```bash
# View all applications
argocd app list
```

**Expected**: Shows 3-level hierarchy:
1. `argocd-nonprod-root` (root)
2. `argocd-network-policies`, `argocd-ingress`, `hello-world-nonprod` (children)

## Success Criteria

- ✅ Hello-world application created automatically by ArgoCD
- ✅ Namespace `hello-world` created by ArgoCD (CreateNamespace)
- ✅ Deployment shows 2/2 READY
- ✅ 2 pods in Running state
- ✅ Service created with ClusterIP
- ✅ Application responds to HTTP requests
- ✅ ArgoCD shows Synced and Healthy status
- ✅ Self-healing verified (optional test)
- ✅ 3-level app-of-apps hierarchy visible

## HALT Conditions

**HALT if**:
- Application not created after 5 minutes
- Namespace not created by ArgoCD
- Deployment shows 0/2 READY
- Pods not in Running state
- Application does not respond to HTTP
- ArgoCD shows OutOfSync or Unhealthy status
- Self-healing test fails

**Resolution**:
- Force sync root app: `argocd app sync argocd-nonprod-root`
- Check application status: `argocd app get hello-world-nonprod`
- View application events: `kubectl get events -n hello-world --sort-by='.lastTimestamp'`
- Check pod logs: `kubectl logs -n hello-world -l app=hello-world`
- Describe deployment: `kubectl describe deployment hello-world -n hello-world`
- Check ArgoCD application controller logs:
  ```bash
  kubectl logs -n argocd statefulset/argocd-application-controller -c application-controller --tail=50 | grep hello-world
  ```
- Verify Git repository access: `argocd repo list`
- Check resource requests meet Autopilot minimums
- Delete and recreate if needed:
  ```bash
  argocd app delete hello-world-nonprod
  argocd app sync argocd-nonprod-root
  ```

## Next Phase

Proceed to **Phase 6.25**: Install Velero for Backup/Restore

## Notes

- **GitOps**: Application deployed automatically from Git (no kubectl apply)
- **CreateNamespace**: Demonstrates cluster-scoped ArgoCD (NOT namespace-scoped)
- **Cross-Namespace**: ArgoCD (argocd namespace) manages app (hello-world namespace)
- **3-Level Hierarchy**: Root → child apps (including hello-world app) → K8s resources
- **Automatic Sync**: ArgoCD detected Git changes within 3 minutes (default poll)
- **Self-Healing**: Manual kubectl changes reverted automatically
- **Autopilot**: Application meets all GKE Autopilot requirements
- Application controller creates namespace before deploying resources
- CreateNamespace=true is safe even if namespace already exists
- Service is ClusterIP (internal only) - no external access yet
- To expose externally, would need to add Ingress (future enhancement)
- Application tree in UI shows all resources and their relationships
- Green checkmarks indicate Healthy and Synced status
- Self-healing test demonstrates ArgoCD enforces desired state from Git
- If application fails to sync, check repo-server logs for Git access issues
- Application sync can take 1-2 minutes for pod readiness
- Readiness probes must pass before Deployment shows READY
