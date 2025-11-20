# Phase 6.20: Create App-of-Apps Manifests

**Tool**: [CC] Claude Code
**Estimated Duration**: 20 minutes

## Purpose

Create ArgoCD "app-of-apps" pattern manifests to enable ArgoCD self-management, automatically deploying NetworkPolicies and future applications from Git repository.

## Prerequisites

- Phase 6.19 completed (Git credentials configured)
- Phase 6.18 completed (NetworkPolicy manifests created)
- Git repo: `pcc-argocd-config-nonprod` cloned locally

## Detailed Steps

### Step 1: Create App-of-Apps Directory Structure

```bash
mkdir -p ~/pcc/core/pcc-argocd-config-nonprod/devtest/app-of-apps
cd ~/pcc/core/pcc-argocd-config-nonprod/devtest/app-of-apps
```

### Step 2: Create App-of-Apps Application Manifest

Create file: `root-app.yaml`

```yaml
# Root app-of-apps - Manages all ArgoCD applications for nonprod devtest
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd-nonprod-root
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-nonprod-root
    app.kubernetes.io/part-of: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io  # Cascade delete
spec:
  project: default

  source:
    repoURL: https://github.com/PORTCoCONNECT/pcc-argocd-config-nonprod.git
    targetRevision: main
    path: devtest/app-of-apps/apps

  destination:
    server: https://kubernetes.default.svc
    namespace: argocd

  syncPolicy:
    automated:
      prune: true       # Delete resources removed from Git
      selfHeal: true    # Sync when cluster state drifts from Git
      allowEmpty: false # Prevent accidental deletion of all resources
    syncOptions:
      - CreateNamespace=false  # Don't create argocd namespace (already exists)
      - PruneLast=true         # Prune after new resources are synced

  # Ignore differences in certain fields
  ignoreDifferences:
    - group: ""
      kind: Secret
      jsonPointers:
        - /data
```

**Key Configuration**:
- `finalizers`: Cascade delete when root app is deleted
- `automated.prune: true`: Remove resources deleted from Git
- `automated.selfHeal: true`: Fix manual changes automatically
- `PruneLast: true`: Deploy new resources before deleting old ones

### Step 3: Create Apps Directory

```bash
mkdir -p apps
```

### Step 4: Create NetworkPolicy Application Manifest

Create file: `apps/network-policies.yaml`

```yaml
# ArgoCD Application for NetworkPolicies
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd-network-policies
  namespace: argocd
  labels:
    app.kubernetes.io/name: network-policies
    app.kubernetes.io/part-of: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default

  source:
    repoURL: https://github.com/PORTCoCONNECT/pcc-argocd-config-nonprod.git
    targetRevision: main
    path: devtest/network-policies

  destination:
    server: https://kubernetes.default.svc
    namespace: argocd

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=false  # argocd namespace already exists
      - RespectIgnoreDifferences=true

  # Refresh every 3 minutes (default)
```

### Step 5: Create Ingress Application Manifest

Create file: `apps/ingress.yaml`

```yaml
# ArgoCD Application for Ingress resources
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: argocd-ingress
  namespace: argocd
  labels:
    app.kubernetes.io/name: ingress
    app.kubernetes.io/part-of: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default

  source:
    repoURL: https://github.com/PORTCoCONNECT/pcc-argocd-config-nonprod.git
    targetRevision: main
    path: devtest/ingress

  destination:
    server: https://kubernetes.default.svc
    namespace: argocd

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=false

  # Ignore load balancer IP assignment (managed by GCP)
  ignoreDifferences:
    - group: networking.k8s.io
      kind: Ingress
      jsonPointers:
        - /status/loadBalancer
```

### Step 6: Create Kustomization for Apps Directory

Create file: `apps/kustomization.yaml`

```yaml
# Kustomization for child applications
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: argocd

resources:
  - network-policies.yaml
  - ingress.yaml
  # Add future apps here:
  # - hello-world.yaml
  # - velero.yaml

commonLabels:
  managed-by: argocd-root
  environment: nonprod
```

### Step 7: Create README Documentation

Create file: `README.md`

```markdown
# ArgoCD App-of-Apps - NonProd DevTest

This directory implements the app-of-apps pattern for ArgoCD self-management.

## Structure

```
app-of-apps/
├── root-app.yaml          # Root application (deploy this manually)
├── apps/                  # Child applications (managed by root)
│   ├── network-policies.yaml
│   ├── ingress.yaml
│   └── kustomization.yaml
└── README.md
```

## Deployment

1. **Bootstrap**: Deploy root app manually (Phase 6.21):
   ```bash
   kubectl apply -f devtest/app-of-apps/root-app.yaml
   ```

2. **Self-Management**: Root app deploys all child apps automatically from `devtest/app-of-apps/apps/` directory

3. **Add New Apps**: Create new YAML in `apps/`, add to `kustomization.yaml`, commit to Git

## GitOps Workflow

1. Make changes to application manifests in Git
2. Commit and push to `main` branch
3. ArgoCD detects change within 3 minutes (default poll interval)
4. ArgoCD syncs changes automatically (`automated.selfHeal: true`)

## Application Hierarchy

```
argocd-nonprod-root (root app)
├── argocd-network-policies (NetworkPolicies)
├── argocd-ingress (Ingress + BackendConfig)
└── [future apps]
```

## Key Features

- **Automated Sync**: Changes in Git are automatically applied
- **Self-Healing**: Manual kubectl changes are reverted
- **Pruning**: Resources removed from Git are deleted from cluster
- **Cascade Delete**: Deleting root app deletes all child apps

## Notes

- Root app must be deployed manually once (bootstrap)
- Child apps are managed entirely by ArgoCD (GitOps)
- Do NOT use `kubectl apply` for child app resources (use Git instead)
- Use `argocd app sync` to force immediate sync (don't wait for poll)
```

### Step 8: Validate Manifests

```bash
# Validate root app
kubectl apply --dry-run=client -f root-app.yaml

# Validate child apps
kubectl apply --dry-run=client -k apps/

# Expected: All resources validated
```

### Step 9: Git Commit

```bash
git add .
git commit -m "feat(argocd): add app-of-apps for self-management

- Root app manages child applications
- NetworkPolicy app for GitOps-managed network policies
- Ingress app for GitOps-managed ingress resources
- Automated sync with self-healing enabled
- Cascade delete for cleanup
- Documentation for GitOps workflow"

git push origin main
```

## Success Criteria

- ✅ Root app manifest created
- ✅ Child app manifests created (NetworkPolicies, Ingress)
- ✅ Kustomization files validate successfully
- ✅ README documentation created
- ✅ Manifests committed to Git

## HALT Conditions

**HALT if**:
- YAML validation fails
- Kustomization build fails
- Git commit fails

**Resolution**:
- Check YAML syntax with `yamllint`
- Verify `repoURL` is `https://github.com/PORTCoCONNECT/pcc-argocd-config-nonprod.git` (HTTPS format, not SSH)
- Ensure `path` values point to correct directories (`devtest/app-of-apps/apps`, `devtest/network-policies`, `devtest/ingress`)
- Check namespace is `argocd`
- Verify git repo is clean: `git status`

## Next Phase

Proceed to **Phase 6.21**: Deploy App-of-Apps

## Notes

- **App-of-Apps Pattern**: Single root app manages multiple child apps
- **Bootstrap**: Root app deployed manually once, then manages itself
- **GitOps**: All child apps deployed automatically from Git
- **Self-Healing**: Manual `kubectl` changes are automatically reverted
- **Pruning**: Resources removed from Git are deleted from cluster
- **Cascade Delete**: Deleting root app deletes all child apps (be careful!)
- **Sync Policy**: `automated.selfHeal: true` enables full GitOps automation
- **Ignore Differences**: Prevents sync loops on managed fields (e.g., load balancer IPs)
- **CreateNamespace**: Set to false for argocd namespace (already exists)
- **CreateNamespace**: Will be true for application namespaces (Phase 6.24)
- **Poll Interval**: ArgoCD checks Git every 3 minutes (default)
- **Force Sync**: Use `argocd app sync APP_NAME` for immediate sync
- **Webhook**: Can configure Git webhooks for instant sync (optional)
- Root app source path points to `apps/` directory (child app manifests)
- Child apps source paths point to actual resource directories
- This enables ArgoCD to manage its own NetworkPolicies (self-management)
- Future applications (Velero, hello-world) will be added to `apps/` directory
