# Phase 6.27: E2E Validation

**Tool**: [WARP] Partner Execution
**Estimated Duration**: 30 minutes

## Purpose

Perform comprehensive end-to-end validation of the entire ArgoCD deployment, testing GitOps pipeline, self-healing, namespace creation, backup/restore, and upgrade workflow.

## Prerequisites

- Phase 6.26 completed (monitoring configured)
- All previous phases completed successfully
- kubectl access to argocd namespace
- ArgoCD CLI logged in

## Detailed Steps

### Test 1: GitOps Pipeline - Modify and Sync (10 minutes)

#### Step 1.1: Modify Hello-World Replicas via Git

```bash
cd ~/pcc/core/pcc-app-argo-config/hello-world-nonprod

# Change replicas from 2 to 3
sed -i 's/replicas: 2/replicas: 3/' deployment.yaml

git add deployment.yaml
git commit -m "test: increase hello-world replicas to 3 for E2E validation"
git push origin main
```

#### Step 1.2: Wait for ArgoCD to Detect and Sync

```bash
# Watch for sync (up to 3 minutes for poll)
kubectl get application hello-world-nonprod -n argocd --watch
```

**Expected**: SYNC STATUS changes to "OutOfSync" then "Synced"

#### Step 1.3: Verify Replicas Updated

```bash
kubectl get deployment hello-world -n hello-world -o jsonpath='{.spec.replicas}'
```

**Expected**: `3`

#### Step 1.4: Revert Change

```bash
cd ~/pcc/core/pcc-app-argo-config/hello-world-nonprod
sed -i 's/replicas: 3/replicas: 2/' deployment.yaml
git add deployment.yaml
git commit -m "test: revert hello-world replicas to 2"
git push origin main

# Wait for sync
sleep 180

# Verify reverted
kubectl get deployment hello-world -n hello-world -o jsonpath='{.spec.replicas}'
```

**Expected**: `2`

**✅ GitOps Pipeline**: Changes in Git automatically applied to cluster

---

### Test 2: Self-Healing - Manual Changes Reverted (5 minutes)

#### Step 2.1: Manually Modify Deployment

```bash
# Manually scale deployment (violates Git desired state)
kubectl scale deployment hello-world -n hello-world --replicas=5
```

#### Step 2.2: Wait for Self-Heal

```bash
# Wait 3 minutes for self-heal
sleep 180

# Verify reverted to 2 (Git desired state)
kubectl get deployment hello-world -n hello-world -o jsonpath='{.spec.replicas}'
```

**Expected**: `2` (reverted by ArgoCD self-heal)

**✅ Self-Healing**: Manual kubectl changes automatically reverted

---

### Test 3: Namespace Creation - Deploy New App (5 minutes)

#### Step 3.1: Create Test App Manifests

```bash
mkdir -p ~/pcc/core/pcc-app-argo-config/test-app-nonprod

cat > ~/pcc/core/pcc-app-argo-config/test-app-nonprod/deployment.yaml <<'EOF'
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-test
  namespace: test-app
spec:
  replicas: 1
  selector:
    matchLabels:
      app: nginx-test
  template:
    metadata:
      labels:
        app: nginx-test
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
      containers:
      - name: nginx
        image: nginx:1.27-alpine
        ports:
        - containerPort: 8080
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop: [ALL]
EOF
```

#### Step 3.2: Create ArgoCD Application

```bash
cat > ~/pcc/core/pcc-app-argo-config/argocd-nonprod/devtest/app-of-apps/apps/test-app.yaml <<'EOF'
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: test-app-nonprod
  namespace: argocd
spec:
  project: default
  source:
    repoURL: git@github.com:ORG/pcc-app-argo-config.git
    targetRevision: main
    path: test-app-nonprod
  destination:
    server: https://kubernetes.default.svc
    namespace: test-app
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

# Add to kustomization
cd ~/pcc/core/pcc-app-argo-config/argocd-nonprod/devtest/app-of-apps/apps
echo "  - test-app.yaml" >> kustomization.yaml

# Commit and push
cd ~/pcc/core/pcc-app-argo-config
git add .
git commit -m "test: add test-app for E2E namespace creation validation"
git push origin main
```

#### Step 3.3: Wait for Deployment

```bash
# Wait for ArgoCD to detect and sync (up to 5 minutes)
sleep 300

# Verify namespace created
kubectl get namespace test-app
```

**Expected**: Namespace `test-app` exists

#### Step 3.4: Verify Application Deployed

```bash
kubectl get deployment nginx-test -n test-app
```

**Expected**: Deployment exists and shows 1/1 READY

**✅ CreateNamespace**: ArgoCD created namespace automatically (cluster-scoped mode works)

---

### Test 4: Backup and Restore (5 minutes)

#### Step 4.1: Create Backup of Hello-World

```bash
velero backup create e2e-test-backup \
  --include-namespaces hello-world \
  --wait
```

**Expected**: Backup completes successfully

#### Step 4.2: Delete Hello-World Namespace

```bash
kubectl delete namespace hello-world
```

**Expected**: Namespace deleted (including all resources)

#### Step 4.3: Restore from Backup

```bash
velero restore create e2e-test-restore \
  --from-backup e2e-test-backup \
  --wait
```

**Expected**: Restore completes successfully

#### Step 4.4: Verify Hello-World Restored

```bash
kubectl get deployment hello-world -n hello-world
```

**Expected**: Deployment exists and shows 2/2 READY

**✅ Backup/Restore**: Velero successfully backed up and restored namespace

---

### Test 5: ArgoCD Upgrade Workflow (5 minutes)

#### Step 5.1: Verify Current ArgoCD Version

```bash
kubectl get deployment argocd-server -n argocd -o jsonpath='{.spec.template.spec.containers[0].image}'
```

**Expected**: Shows current version (e.g., `quay.io/argoproj/argocd:v2.13.x`)

#### Step 5.2: Check for Available Upgrades

```bash
helm search repo argo/argo-cd --versions | head -10
```

**Expected**: Shows available chart versions

**Note**: Do NOT actually upgrade in E2E test (just verify workflow is understood)

**✅ Upgrade Workflow**: Documented process for future upgrades (Phase 6.28)

---

### Test 6: External Access and Authentication (3 minutes)

#### Step 6.1: Test HTTPS Access

```bash
curl -I https://argocd.nonprod.pcconnect.ai
```

**Expected**: HTTP 200 or 302 (redirect to login)

#### Step 6.2: Test Google OAuth Login

1. Open browser: `https://argocd.nonprod.pcconnect.ai`
2. Click "LOG IN VIA GOOGLE"
3. Authenticate with test user
4. Verify access based on group membership

**Expected**: Login succeeds, proper permissions enforced

**✅ External Access**: HTTPS, DNS, OAuth all working

---

### Test 7: Monitoring and Alerting (2 minutes)

#### Step 7.1: Verify Metrics Collected

```bash
gcloud monitoring time-series list \
  --filter='metric.type="kubernetes.io/container/ready" AND resource.labels.namespace_name="argocd"' \
  --format=json \
  --limit=1
```

**Expected**: Returns time series data

#### Step 7.2: Check Dashboard

Navigate to: https://console.cloud.google.com/monitoring/dashboards

**Expected**: ArgoCD dashboard shows current metrics

**✅ Monitoring**: Metrics collected, dashboard working

---

## Success Criteria

- ✅ **Test 1**: GitOps pipeline works (Git changes → cluster sync)
- ✅ **Test 2**: Self-healing works (manual changes reverted)
- ✅ **Test 3**: CreateNamespace works (new namespace created)
- ✅ **Test 4**: Backup/restore works (Velero functional)
- ✅ **Test 5**: Upgrade workflow documented
- ✅ **Test 6**: External access works (HTTPS + OAuth)
- ✅ **Test 7**: Monitoring works (metrics + dashboard)

## HALT Conditions

**HALT if**:
- GitOps sync fails
- Self-healing does not revert changes
- CreateNamespace fails (namespace-scoped mode issue)
- Backup or restore fails
- External access fails (DNS, SSL, or OAuth issues)
- No metrics data collected

**Resolution**:
- Check ArgoCD application controller logs:
  ```bash
  kubectl logs -n argocd statefulset/argocd-application-controller -c application-controller --tail=100
  ```
- Verify Git repository access: `argocd repo list`
- Check self-heal enabled: `argocd app get <app-name> -o yaml | grep selfHeal`
- Verify Velero logs: `kubectl logs -n velero deployment/velero --tail=50`
- Test DNS: `dig argocd.nonprod.pcconnect.ai +short`
- Check SSL cert: `gcloud compute ssl-certificates describe argocd-nonprod-cert`
- Verify OAuth config: `kubectl get secret argocd-secret -n argocd -o yaml`
- Check monitoring: `gcloud monitoring time-series list ...`

## Next Phase

Proceed to **Phase 6.28**: Phase 6 Completion Documentation

## Notes

- **Comprehensive**: Tests all major ArgoCD features in one workflow
- **GitOps**: Validates core GitOps principle (Git as source of truth)
- **Self-Healing**: Demonstrates automated drift correction
- **CreateNamespace**: Proves cluster-scoped mode (NOT namespace-scoped)
- **Backup/Restore**: Validates disaster recovery capability
- **External Access**: Confirms production-ready ingress
- **Monitoring**: Ensures observability for operations
- Total test time: ~30 minutes (includes wait times)
- All tests are non-destructive (changes are reverted)
- Test app (test-app-nonprod) can be deleted after E2E: `kubectl delete app test-app-nonprod -n argocd`
- E2E backup (e2e-test-backup) auto-deletes after 72 hours (TTL)
- If any test fails, DO NOT proceed to Phase 6.28 - fix the issue first
- E2E validation proves Phase 6 objectives achieved
- Document any test failures for troubleshooting
- Can re-run E2E anytime to validate system health
