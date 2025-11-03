# Phase 6.23: Create Hello-World App Manifests

**Tool**: [CC] Claude Code
**Estimated Duration**: 15 minutes

## Purpose

Create simple hello-world application manifests to demonstrate ArgoCD's ability to create namespaces via CreateNamespace sync option and deploy applications across namespaces.

## Prerequisites

- Phase 6.22 completed (NetworkPolicies validated)
- Git repo: `pcc-app-argo-config` cloned locally

## Detailed Steps

### Step 1: Create Hello-World Directory Structure

```bash
mkdir -p ~/pcc/core/pcc-app-argo-config/hello-world-nonprod
cd ~/pcc/core/pcc-app-argo-config/hello-world-nonprod
```

### Step 2: Create Namespace Manifest

Create file: `namespace.yaml`

```yaml
# Namespace for hello-world application
# This file is optional - ArgoCD can create namespace via syncOptions
apiVersion: v1
kind: Namespace
metadata:
  name: hello-world
  labels:
    name: hello-world
    environment: nonprod
    managed-by: argocd
```

### Step 3: Create Deployment Manifest

Create file: `deployment.yaml`

```yaml
# Hello-World Deployment
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hello-world
  namespace: hello-world
  labels:
    app: hello-world
    version: v1
spec:
  replicas: 2
  selector:
    matchLabels:
      app: hello-world
  template:
    metadata:
      labels:
        app: hello-world
        version: v1
    spec:
      # Security context (GKE Autopilot requirement)
      securityContext:
        runAsNonRoot: true
        runAsUser: 65534
        fsGroup: 65534

      containers:
      - name: hello-world
        image: gcr.io/google-samples/hello-app:2.0
        ports:
        - containerPort: 8080
          name: http
          protocol: TCP

        # Resource requests (GKE Autopilot requirement)
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi

        # Security context
        securityContext:
          allowPrivilegeEscalation: false
          capabilities:
            drop:
            - ALL
          readOnlyRootFilesystem: false

        # Liveness probe
        livenessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10

        # Readiness probe
        readinessProbe:
          httpGet:
            path: /
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

**Key Configuration**:
- GCR public image (no auth needed)
- Autopilot-compliant security contexts
- Resource requests/limits
- Health checks
- 2 replicas for HA

### Step 4: Create Service Manifest

Create file: `service.yaml`

```yaml
# Hello-World Service
apiVersion: v1
kind: Service
metadata:
  name: hello-world
  namespace: hello-world
  labels:
    app: hello-world
spec:
  type: ClusterIP
  selector:
    app: hello-world
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
```

### Step 5: Create Kustomization File

Create file: `kustomization.yaml`

```yaml
# Kustomization for hello-world application
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: hello-world

resources:
  - namespace.yaml
  - deployment.yaml
  - service.yaml

commonLabels:
  managed-by: argocd
  environment: nonprod
```

### Step 6: Create ArgoCD Application Manifest

```bash
cd ~/pcc/core/pcc-app-argo-config/argocd-nonprod/devtest/app-of-apps/apps
```

Create file: `hello-world.yaml`

```yaml
# ArgoCD Application for Hello-World
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: hello-world-nonprod
  namespace: argocd
  labels:
    app.kubernetes.io/name: hello-world
    environment: nonprod
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default

  source:
    repoURL: git@github.com:ORG/pcc-app-argo-config.git
    targetRevision: main
    path: hello-world-nonprod

  destination:
    server: https://kubernetes.default.svc
    namespace: hello-world

  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true  # ArgoCD creates hello-world namespace
      - PruneLast=true

  # Health check configuration
  ignoreDifferences:
    - group: apps
      kind: Deployment
      jsonPointers:
        - /spec/replicas  # Ignore HPA-managed replica count (if HPA added later)
```

**Key Configuration**:
- `CreateNamespace=true`: ArgoCD creates hello-world namespace automatically
- Demonstrates cluster-scoped ArgoCD capability
- Automated sync with self-healing

### Step 7: Update Kustomization to Include Hello-World

```bash
cd ~/pcc/core/pcc-app-argo-config/argocd-nonprod/devtest/app-of-apps/apps
```

Edit file: `kustomization.yaml`

Add `hello-world.yaml` to resources:

```yaml
# Kustomization for child applications
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: argocd

resources:
  - network-policies.yaml
  - ingress.yaml
  - hello-world.yaml  # ADD THIS LINE

commonLabels:
  managed-by: argocd-root
  environment: nonprod
```

### Step 8: Validate Manifests

```bash
# Validate hello-world resources
cd ~/pcc/core/pcc-app-argo-config/hello-world-nonprod
kubectl apply --dry-run=client -k .

# Validate ArgoCD application
cd ~/pcc/core/pcc-app-argo-config/argocd-nonprod/devtest/app-of-apps/apps
kubectl apply --dry-run=client -f hello-world.yaml

# Expected: All resources validated
```

### Step 9: Git Commit

```bash
cd ~/pcc/core/pcc-app-argo-config

git add .
git commit -m "feat(apps): add hello-world sample application

- Simple hello-world app for testing ArgoCD deployment
- Demonstrates CreateNamespace sync option
- GKE Autopilot-compliant resource requests and security contexts
- 2 replicas with liveness/readiness probes
- Automated sync with self-healing enabled
- Managed by app-of-apps root application"

git push origin main
```

## Success Criteria

- ✅ Hello-world application manifests created
- ✅ ArgoCD Application manifest created
- ✅ Kustomization updated to include hello-world
- ✅ All manifests validate successfully
- ✅ Manifests committed to Git

## HALT Conditions

**HALT if**:
- YAML validation fails
- Kustomization build fails
- Git commit fails

**Resolution**:
- Check YAML syntax with `yamllint`
- Verify namespace is `hello-world` in app manifests
- Ensure resource requests meet Autopilot minimums
- Check security contexts are configured
- Verify git repo is clean: `git status`

## Next Phase

Proceed to **Phase 6.24**: Deploy Hello-World via ArgoCD

## Notes

- **CreateNamespace=true**: Demonstrates cluster-scoped ArgoCD capability (NOT namespace-scoped)
- **Autopilot Compliance**: Resource requests, security contexts, non-root user
- **Public Image**: `gcr.io/google-samples/hello-app:2.0` (no auth needed)
- **Health Checks**: Liveness and readiness probes ensure pod health
- **2 Replicas**: Demonstrates multi-pod deployment and load balancing
- **Kustomization**: Allows easy customization per environment
- **GitOps**: Deployment happens automatically when committed to Git
- **Self-Healing**: Manual kubectl changes will be reverted
- **App-of-Apps**: hello-world app managed by root app (3-level hierarchy)
- Namespace can be created by either:
  1. Including namespace.yaml in manifests (explicit)
  2. Using CreateNamespace=true in ArgoCD app (implicit)
- Both methods work - we use both for demonstration
- If namespace already exists, CreateNamespace is a no-op (safe)
- Service type ClusterIP (not exposed externally yet)
- To expose externally, would need Ingress (future enhancement)
- Application will sync automatically within 3 minutes of Git push
- Can force immediate sync: `argocd app sync hello-world-nonprod`
