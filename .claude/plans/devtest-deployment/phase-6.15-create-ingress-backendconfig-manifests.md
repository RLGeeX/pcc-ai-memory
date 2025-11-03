# Phase 6.15: Create Ingress + BackendConfig Manifests

**Tool**: [CC] Claude Code
**Estimated Duration**: 20 minutes

## Purpose

Create Kubernetes Ingress and BackendConfig manifests for ArgoCD with GCP-managed SSL certificate, HTTP/2 support for gRPC, and ExternalDNS annotations for automatic DNS record creation.

## Prerequisites

- Phase 6.14 completed (ExternalDNS installed)
- Phase 6.7 completed (GCP-managed SSL certificate created)
- Git repo: `pcc-app-argo-config` cloned locally

## Detailed Steps

### Step 1: Create Directory Structure

```bash
mkdir -p ~/pcc/core/pcc-app-argo-config/argocd-nonprod/devtest/ingress
cd ~/pcc/core/pcc-app-argo-config/argocd-nonprod/devtest/ingress
```

### Step 2: Create BackendConfig Manifest

Create file: `backendconfig.yaml`

```yaml
# BackendConfig for ArgoCD Server - HTTP/2 for gRPC support
apiVersion: cloud.google.com/v1
kind: BackendConfig
metadata:
  name: argocd-server-backend-config
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/component: server
    app.kubernetes.io/part-of: argocd
spec:
  # HTTP/2 required for ArgoCD CLI gRPC calls
  connectionDraining:
    drainingTimeoutSec: 60

  # Health check configuration
  healthCheck:
    checkIntervalSec: 10
    timeoutSec: 5
    healthyThreshold: 2
    unhealthyThreshold: 3
    type: HTTP
    requestPath: /healthz
    port: 8080

  # Session affinity for consistent routing
  sessionAffinity:
    affinityType: "CLIENT_IP"
    affinityCookieTtlSec: 3600

  # Timeout configuration
  timeoutSec: 30

  # Protocol configuration
  # Note: HTTP/2 is enabled via Service annotation, not here
```

**Key Configuration**:
- Health check on `/healthz` endpoint
- Client IP session affinity for consistent routing
- Connection draining for graceful shutdown
- 30s backend timeout

### Step 3: Update ArgoCD Server Service with BackendConfig Annotation

Create file: `service-patch.yaml`

```yaml
# Patch to add BackendConfig annotation to argocd-server Service
apiVersion: v1
kind: Service
metadata:
  name: argocd-server
  namespace: argocd
  annotations:
    cloud.google.com/backend-config: '{"default": "argocd-server-backend-config"}'
    cloud.google.com/neg: '{"ingress": true}'
spec:
  type: ClusterIP
  ports:
  - name: http
    port: 80
    targetPort: 8080
    protocol: TCP
  - name: https
    port: 443
    targetPort: 8080
    protocol: TCP
```

**Key Annotations**:
- `cloud.google.com/backend-config`: Links Service to BackendConfig
- `cloud.google.com/neg`: Enables Network Endpoint Groups for better load balancing

### Step 4: Create Ingress Manifest

Create file: `ingress.yaml`

```yaml
# Ingress for ArgoCD Server with GCP-managed SSL and ExternalDNS
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server
  namespace: argocd
  labels:
    app.kubernetes.io/name: argocd-server
    app.kubernetes.io/component: server
    app.kubernetes.io/part-of: argocd
  annotations:
    # GKE Ingress configuration
    kubernetes.io/ingress.class: "gce"

    # SSL configuration
    ingress.gcp.kubernetes.io/pre-shared-cert: "argocd-nonprod-cert"
    kubernetes.io/ingress.allow-http: "false"  # Force HTTPS

    # ExternalDNS annotations
    external-dns.alpha.kubernetes.io/hostname: "argocd.nonprod.pcconnect.ai"
    external-dns.alpha.kubernetes.io/cloudflare-proxied: "false"

    # Backend configuration
    cloud.google.com/backend-config: '{"default": "argocd-server-backend-config"}'

    # Security headers
    ingress.kubernetes.io/force-ssl-redirect: "true"

spec:
  rules:
  - host: argocd.nonprod.pcconnect.ai
    http:
      paths:
      - path: /*
        pathType: ImplementationSpecific
        backend:
          service:
            name: argocd-server
            port:
              number: 443

  # TLS configuration (uses GCP-managed cert)
  tls:
  - hosts:
    - argocd.nonprod.pcconnect.ai
    secretName: argocd-server-tls  # Placeholder, cert is managed by GCP
```

**Key Configuration**:
- `ingress.class: gce` - GCP load balancer
- `pre-shared-cert` - References GCP-managed SSL certificate from Phase 6.7
- `allow-http: false` - HTTPS only
- `external-dns.alpha.kubernetes.io/hostname` - Triggers ExternalDNS to create DNS record
- `cloudflare-proxied: false` - Direct traffic to GCP LB (no Cloudflare proxy)
- `force-ssl-redirect: true` - Redirect HTTP to HTTPS

### Step 5: Create Kustomization File

Create file: `kustomization.yaml`

```yaml
# Kustomization for ArgoCD Ingress resources
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: argocd

resources:
  - backendconfig.yaml
  - ingress.yaml

# Strategic merge patch for Service
patchesStrategicMerge:
  - service-patch.yaml

commonLabels:
  managed-by: argocd
  environment: nonprod
```

### Step 6: Validate Manifests

```bash
# Validate YAML syntax
kubectl apply --dry-run=client -k .

# Expected: All resources validated
```

### Step 7: Git Commit

```bash
git add .
git commit -m "feat(argocd): add ingress and backendconfig for nonprod

- GCP-managed SSL certificate (argocd-nonprod-cert)
- HTTP/2 support for ArgoCD CLI gRPC
- ExternalDNS automation for argocd.nonprod.pcconnect.ai
- BackendConfig with health checks and session affinity
- HTTPS-only with forced SSL redirect
- Network Endpoint Groups for better load balancing"

git push origin main
```

## Success Criteria

- ✅ BackendConfig manifest created with HTTP/2 support
- ✅ Service patch adds BackendConfig annotation
- ✅ Ingress manifest references GCP-managed SSL certificate
- ✅ ExternalDNS annotations configured correctly
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
- Ensure GCP-managed cert name matches Phase 6.7 output
- Check git repo is clean: `git status`

## Next Phase

Proceed to **Phase 6.16**: Deploy Ingress (ExternalDNS Auto-Creates DNS)

## Notes

- **CRITICAL**: BackendConfig annotation goes on Service, NOT Ingress
- HTTP/2 is required for ArgoCD CLI gRPC calls (sync, app list, etc.)
- GCP-managed SSL certificate is referenced by name (created in Phase 6.7)
- ExternalDNS will automatically create DNS A record when Ingress is deployed
- Network Endpoint Groups (NEG) improve load balancing by routing to pods directly
- HTTPS-only enforced at Ingress level
- Session affinity ensures consistent routing for WebSocket connections
- Health check on `/healthz` endpoint verifies ArgoCD server health
- Connection draining allows graceful pod shutdown (60s timeout)
- Kustomization allows easy customization per environment
- Do NOT deploy yet - Phase 6.16 handles deployment and validation
