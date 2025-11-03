# Phase 6.5: Create Helm Values Configuration

**Tool**: [CC] Claude Code
**Estimated Duration**: 45 minutes

## Purpose

Create Helm values file for ArgoCD deployment on GKE Autopilot. This configuration enables **cluster-scoped mode** (NOT namespace-scoped), configures Workload Identity, Google Workspace OIDC authentication, and Autopilot resource/security requirements.

## Prerequisites

- Phase 6.4 completed (infrastructure config exists, service account names known)
- Understanding of ArgoCD Helm chart structure
- Understanding of GKE Autopilot constraints

## Key Architectural Decision

**CLUSTER-SCOPED MODE**: This configuration uses cluster-scoped ArgoCD (NOT namespace-scoped):
- ✅ Enables `CreateNamespace=true` functionality
- ✅ Allows managing resources in other namespaces
- ✅ Full GitOps capability
- ✅ GKE Autopilot compatible (avoids kube-system, uses namespace selectors)
- ❌ NO `controller.extraArgs: [--namespaced]`
- ❌ NO `clusterRole.create: false` flags

## Detailed Steps

### Step 1: Create Values File

```bash
cd /home/jfogarty/pcc/infra/pcc-devops-infra/argocd-nonprod/devtest
touch values-autopilot.yaml
```

### Step 2: Create values-autopilot.yaml

```yaml
# ArgoCD Helm Values for GKE Autopilot - Cluster-Scoped Mode
# Chart: argo-cd 9.0.5
# ArgoCD Version: v2.13.x

# -------------------------------------------------------------------
# Global Configuration
# -------------------------------------------------------------------
global:
  domain: argocd.nonprod.pcconnect.ai

# -------------------------------------------------------------------
# ArgoCD Configs - Google Workspace OIDC + RBAC
# -------------------------------------------------------------------
configs:
  # ConfigMap for ArgoCD settings
  cm:
    url: https://argocd.nonprod.pcconnect.ai

    # Google Workspace OIDC via Dex
    dex.config: |
      connectors:
      - type: oidc
        id: google
        name: Google Workspace
        config:
          issuer: https://accounts.google.com
          clientID: $dex.google.clientID
          clientSecret: $dex.google.clientSecret
          redirectURI: https://argocd.nonprod.pcconnect.ai/api/dex/callback
          hostedDomains:
          - pcconnect.ai

    # Exclude Velero CRDs from ArgoCD management (prevent backup pruning)
    resource.exclusions: |
      - apiGroups:
        - velero.io
        kinds:
        - Backup
        - Restore
        clusters:
        - "*"

  # RBAC Policy - Map Google Workspace Groups to ArgoCD Roles
  rbac:
    policy.csv: |
      g, gcp-admins@pcconnect.ai, role:admin
      g, gcp-devops@pcconnect.ai, role:admin
      g, gcp-developers@pcconnect.ai, role:readonly
      g, gcp-read-only@pcconnect.ai, role:readonly

  # Secret containing Google OAuth credentials (created in Phase 6.12)
  secret:
    extra:
      dex.google.clientID: ""  # Populated in Phase 6.12
      dex.google.clientSecret: ""  # Populated in Phase 6.12

# -------------------------------------------------------------------
# ArgoCD Application Controller
# -------------------------------------------------------------------
controller:
  # CLUSTER-SCOPED MODE - NO namespace restriction
  # ClusterRole WILL be created (Autopilot compatible)

  # Workload Identity annotation
  serviceAccount:
    create: true
    name: argocd-application-controller
    annotations:
      iam.gke.io/gcp-service-account: argocd-controller@pcc-prj-devops-nonprod.iam.gserviceaccount.com

  # Autopilot resource requirements (REQUIRED)
  resources:
    requests:
      cpu: 250m      # Autopilot minimum
      memory: 512Mi  # Autopilot minimum
    limits:
      cpu: 1000m
      memory: 2Gi

  # Autopilot security context (REQUIRED)
  containerSecurityContext:
    runAsNonRoot: true
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
    capabilities:
      drop:
      - ALL

  # Metrics for monitoring
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      namespace: argocd

# -------------------------------------------------------------------
# ArgoCD Server (API + UI)
# -------------------------------------------------------------------
server:
  # CLUSTER-SCOPED MODE - ClusterRole WILL be created

  # Workload Identity annotation
  serviceAccount:
    create: true
    name: argocd-server
    annotations:
      iam.gke.io/gcp-service-account: argocd-server@pcc-prj-devops-nonprod.iam.gserviceaccount.com

  # Service type ClusterIP (Ingress will handle external access)
  service:
    type: ClusterIP

  # Autopilot resource requirements
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 1Gi

  # Autopilot security context
  containerSecurityContext:
    runAsNonRoot: true
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
    capabilities:
      drop:
      - ALL

  # Metrics
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      namespace: argocd

# -------------------------------------------------------------------
# ArgoCD Repo Server
# -------------------------------------------------------------------
repoServer:
  # CLUSTER-SCOPED MODE - ClusterRole WILL be created

  # Autopilot resource requirements
  resources:
    requests:
      cpu: 100m
      memory: 256Mi
    limits:
      cpu: 500m
      memory: 1Gi

  # Autopilot security context
  containerSecurityContext:
    runAsNonRoot: true
    allowPrivilegeEscalation: false
    readOnlyRootFilesystem: true
    seccompProfile:
      type: RuntimeDefault
    capabilities:
      drop:
      - ALL

  # Metrics
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      namespace: argocd

# -------------------------------------------------------------------
# Dex (OIDC Connector for Google Workspace)
# -------------------------------------------------------------------
dex:
  enabled: true

  # Workload Identity annotation
  serviceAccount:
    create: true
    name: argocd-dex-server
    annotations:
      iam.gke.io/gcp-service-account: argocd-dex@pcc-prj-devops-nonprod.iam.gserviceaccount.com

  # Autopilot resource requirements
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi

  # Autopilot security context
  containerSecurityContext:
    runAsNonRoot: true
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
    capabilities:
      drop:
      - ALL

# -------------------------------------------------------------------
# Redis (State Storage)
# -------------------------------------------------------------------
redis:
  enabled: true

  # Workload Identity annotation
  serviceAccount:
    create: true
    name: argocd-redis
    annotations:
      iam.gke.io/gcp-service-account: argocd-redis@pcc-prj-devops-nonprod.iam.gserviceaccount.com

  # Autopilot resource requirements
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

  # Autopilot security context
  containerSecurityContext:
    runAsNonRoot: true
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
    capabilities:
      drop:
      - ALL

  # Metrics
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      namespace: argocd

# -------------------------------------------------------------------
# ApplicationSet Controller
# -------------------------------------------------------------------
applicationSet:
  enabled: true

  # CLUSTER-SCOPED MODE - ClusterRole WILL be created

  # Autopilot resource requirements
  resources:
    requests:
      cpu: 100m
      memory: 128Mi
    limits:
      cpu: 500m
      memory: 512Mi

  # Autopilot security context
  containerSecurityContext:
    runAsNonRoot: true
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
    capabilities:
      drop:
      - ALL

  # Metrics
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      namespace: argocd

# -------------------------------------------------------------------
# Notifications Controller
# -------------------------------------------------------------------
notifications:
  enabled: true

  # Autopilot resource requirements
  resources:
    requests:
      cpu: 50m
      memory: 128Mi
    limits:
      cpu: 200m
      memory: 256Mi

  # Autopilot security context
  containerSecurityContext:
    runAsNonRoot: true
    allowPrivilegeEscalation: false
    seccompProfile:
      type: RuntimeDefault
    capabilities:
      drop:
      - ALL

  # Metrics
  metrics:
    enabled: true
    serviceMonitor:
      enabled: true
      namespace: argocd
```

### Step 3: Validate YAML Syntax

```bash
# Install yamllint if needed
# pip install yamllint

# Validate syntax
yamllint values-autopilot.yaml

# Or use yq
yq eval '.' values-autopilot.yaml > /dev/null && echo "YAML valid"
```

### Step 4: Git Workflow

```bash
# Stage values file
git add infra/pcc-devops-infra/argocd-nonprod/devtest/values-autopilot.yaml

# Commit
git commit -m "feat(argocd): add Helm values for GKE Autopilot deployment

Create Helm values configuration for ArgoCD 9.0.5 on GKE Autopilot.

Key features:
- Cluster-scoped mode (NOT namespace-scoped) for full GitOps capability
- Google Workspace OIDC authentication via Dex
- Workload Identity annotations on all service accounts
- Autopilot resource requirements (250m CPU, 512Mi memory minimums)
- Autopilot security contexts (runAsNonRoot, no privilege escalation)
- RBAC mapping Google Workspace Groups to ArgoCD roles
- Velero CRD exclusion to prevent backup pruning
- Prometheus ServiceMonitor for all components

References service accounts from Phase 6.4 Terraform config.

"

# Push to remote
git push origin main
```

## Success Criteria

- ✅ values-autopilot.yaml created with valid YAML syntax
- ✅ Cluster-scoped mode (NO namespace restrictions)
- ✅ All 6 service accounts have Workload Identity annotations
- ✅ Resource requirements meet Autopilot minimums (250m CPU, 512Mi memory for controller)
- ✅ Security contexts configured (runAsNonRoot, no privilege escalation, seccompProfile)
- ✅ Google Workspace OIDC via dex.config
- ✅ RBAC policy maps 4 Google Workspace Groups
- ✅ Velero CRD exclusion configured
- ✅ Prometheus ServiceMonitors enabled
- ✅ Git commit follows conventional format

## HALT Conditions

**HALT if**:
- YAML syntax validation fails
- Service account email format incorrect
- Resource requests below Autopilot minimums
- Git repository is not accessible

**Resolution**: Fix YAML syntax, verify SA email format, adjust resources, check Git access.

## Next Phase

Proceed to **Phase 6.6**: Configure Google Workspace OAuth

## Notes

- **CRITICAL CHANGE**: This uses cluster-scoped mode (NOT namespace-scoped per Codex review)
- Service account emails reference Phase 6.4 config by constructing: `SA_ID@PROJECT.iam.gserviceaccount.com`
- Google OAuth clientID/clientSecret are empty - populated in Phase 6.12 after credentials created
- Helm chart version 9.0.5 (NOT 7.7.11 which was incorrect)
- ArgoCD version will be v2.13.x (tied to chart 9.0.5)
- Velero backup exclusion prevents ArgoCD from pruning Velero Backup/Restore CRDs
- All components have Prometheus ServiceMonitors for monitoring (Phase 6.27)
- This file will be used in Phase 6.10 for `helm install` command
