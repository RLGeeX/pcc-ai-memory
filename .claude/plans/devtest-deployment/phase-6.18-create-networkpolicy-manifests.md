# Phase 6.18: Create NetworkPolicy Manifests

**Tool**: [CC] Claude Code
**Estimated Duration**: 15 minutes

## Purpose

Create Kubernetes NetworkPolicy manifests for ArgoCD namespace with wide-open egress (all outbound traffic allowed) and permissive ingress rules for ArgoCD components, managed via GitOps for self-management demonstration.

## Prerequisites

- Phase 6.17 completed (RBAC validated)
- Git repo: `pcc-app-argo-config` cloned locally

## Detailed Steps

### Step 1: Create Directory Structure

```bash
mkdir -p ~/pcc/core/pcc-app-argo-config/argocd-nonprod/devtest/network-policies
cd ~/pcc/core/pcc-app-argo-config/argocd-nonprod/devtest/network-policies
```

### Step 2: Create NetworkPolicy for ArgoCD Server

Create file: `networkpolicy-argocd-server.yaml`

```yaml
# NetworkPolicy for ArgoCD Server - Allow ingress from GCP LB and within namespace
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-server
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/component: server
    app.kubernetes.io/part-of: argocd
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-server
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow from GCP load balancer (GKE Ingress)
    - from:
      - namespaceSelector: {}
      - podSelector: {}
      ports:
      - protocol: TCP
        port: 8080  # HTTP
      - protocol: TCP
        port: 8083  # Metrics
  egress:
    # Wide-open egress (nonprod) - allow ALL external traffic
    - {}
```

**Key Configuration**:
- Allow ingress from any pod (GCP LB, other ArgoCD components)
- Allow ingress on ports 8080 (HTTP) and 8083 (metrics)
- Wide-open egress (no restrictions)

### Step 3: Create NetworkPolicy for ArgoCD Application Controller

Create file: `networkpolicy-argocd-application-controller.yaml`

```yaml
# NetworkPolicy for ArgoCD Application Controller
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-application-controller
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-application-controller
    app.kubernetes.io/component: application-controller
    app.kubernetes.io/part-of: argocd
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-application-controller
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow metrics scraping from within namespace
    - from:
      - podSelector: {}
      ports:
      - protocol: TCP
        port: 8082  # Metrics
  egress:
    # Wide-open egress (nonprod) - allow ALL external traffic
    - {}
```

### Step 4: Create NetworkPolicy for ArgoCD Repo Server

Create file: `networkpolicy-argocd-repo-server.yaml`

```yaml
# NetworkPolicy for ArgoCD Repo Server
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-repo-server
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-repo-server
    app.kubernetes.io/component: repo-server
    app.kubernetes.io/part-of: argocd
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-repo-server
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow from argocd-server and application-controller
    - from:
      - podSelector:
          matchLabels:
            app.kubernetes.io/part-of: argocd
      ports:
      - protocol: TCP
        port: 8081  # gRPC
      - protocol: TCP
        port: 8084  # Metrics
  egress:
    # Wide-open egress (nonprod) - allow ALL external traffic
    - {}
```

### Step 5: Create NetworkPolicy for ArgoCD Dex Server

Create file: `networkpolicy-argocd-dex-server.yaml`

```yaml
# NetworkPolicy for ArgoCD Dex Server (OAuth)
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-dex-server
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-dex-server
    app.kubernetes.io/component: dex-server
    app.kubernetes.io/part-of: argocd
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-dex-server
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow from argocd-server for OAuth flow
    - from:
      - podSelector:
          matchLabels:
            app.kubernetes.io/name: argocd-server
      ports:
      - protocol: TCP
        port: 5556  # gRPC
      - protocol: TCP
        port: 5558  # Metrics
  egress:
    # Wide-open egress (nonprod) - allow ALL external traffic (needs Google OAuth)
    - {}
```

### Step 6: Create NetworkPolicy for ArgoCD Redis

Create file: `networkpolicy-argocd-redis.yaml`

```yaml
# NetworkPolicy for ArgoCD Redis
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: argocd-redis
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-redis
    app.kubernetes.io/component: redis
    app.kubernetes.io/part-of: argocd
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: argocd-redis
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow from all ArgoCD components
    - from:
      - podSelector:
          matchLabels:
            app.kubernetes.io/part-of: argocd
      ports:
      - protocol: TCP
        port: 6379  # Redis
  egress:
    # Wide-open egress (nonprod) - allow ALL external traffic
    - {}
```

### Step 7: Create NetworkPolicy for ExternalDNS

Create file: `networkpolicy-externaldns.yaml`

```yaml
# NetworkPolicy for ExternalDNS
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: external-dns
  namespace: argocd
  labels:
    app.kubernetes.io/name: external-dns
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: external-dns
  policyTypes:
    - Ingress
    - Egress
  ingress:
    # Allow metrics scraping
    - from:
      - podSelector: {}
      ports:
      - protocol: TCP
        port: 7979  # Metrics
  egress:
    # Wide-open egress (nonprod) - allow ALL external traffic (needs Cloudflare API)
    - {}
```

### Step 8: Create Default Deny Policy (Optional)

Create file: `networkpolicy-default-deny.yaml`

```yaml
# Default deny policy - requires explicit allow rules
# COMMENTED OUT FOR NONPROD - Uncomment for production
# apiVersion: networking.k8s.io/v1
# kind: NetworkPolicy
# metadata:
#   name: default-deny-all
#   namespace: argocd
# spec:
#   podSelector: {}
#   policyTypes:
#     - Ingress
#     - Egress
```

**Note**: Default deny is commented out for nonprod to allow easier debugging. Uncomment for production.

### Step 9: Create Kustomization File

Create file: `kustomization.yaml`

```yaml
# Kustomization for ArgoCD NetworkPolicies
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: argocd

resources:
  - networkpolicy-argocd-server.yaml
  - networkpolicy-argocd-application-controller.yaml
  - networkpolicy-argocd-repo-server.yaml
  - networkpolicy-argocd-dex-server.yaml
  - networkpolicy-argocd-redis.yaml
  - networkpolicy-externaldns.yaml
  # - networkpolicy-default-deny.yaml  # Commented out for nonprod

commonLabels:
  managed-by: argocd
  environment: nonprod
```

### Step 10: Validate Manifests

```bash
# Validate YAML syntax
kubectl apply --dry-run=client -k .

# Expected: All resources validated
```

### Step 11: Git Commit

```bash
git add .
git commit -m "feat(argocd): add network policies for nonprod

- Wide-open egress (nonprod philosophy)
- Permissive ingress for ArgoCD components
- Allow GCP LB traffic to argocd-server
- Allow OAuth flow for dex-server
- Allow metrics scraping within namespace
- ExternalDNS can reach Cloudflare API
- Default deny policy commented out (enable in prod)"

git push origin main
```

## Success Criteria

- ✅ NetworkPolicy manifests created for all ArgoCD components
- ✅ Wide-open egress configured (nonprod)
- ✅ Ingress rules allow required component communication
- ✅ Kustomization file validates successfully
- ✅ Manifests committed to Git

## HALT Conditions

**HALT if**:
- YAML validation fails
- Kustomization build fails
- Git commit fails

**Resolution**:
- Check YAML syntax with `yamllint`
- Verify namespace is `argocd`
- Ensure podSelector labels match Helm chart labels
- Check git repo is clean: `git status`

## Next Phase

Proceed to **Phase 6.19**: Configure Git Credentials

## Notes

- **NONPROD PHILOSOPHY**: Wide-open egress simplifies debugging
- **PRODUCTION**: Uncomment default-deny policy and tighten egress rules
- NetworkPolicies are managed by ArgoCD itself (GitOps self-management)
- Ingress rules allow traffic within namespace (pod-to-pod)
- GKE Ingress traffic uses node ports (appears as pod traffic)
- ExternalDNS needs egress to reach Cloudflare API (1.1.1.1)
- Dex needs egress to reach Google OAuth endpoints
- Application controller needs egress to reach Git repos
- Repo server needs egress to reach Git repos and Helm chart registries
- Redis typically doesn't need egress (cache only)
- Metrics ports exposed for Prometheus scraping (future phase)
- Default deny policy provides defense-in-depth when enabled
- NetworkPolicies are additive (multiple policies on same pod are OR'd)
- Do NOT deploy yet - Phase 6.21 handles deployment via app-of-apps
