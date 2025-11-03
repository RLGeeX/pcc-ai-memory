# Phase 6.14: Install ExternalDNS via Helm

**Tool**: [WARP] Partner Execution
**Estimated Duration**: 15 minutes

## Purpose

Install ExternalDNS on GKE Autopilot using Helm, configured for Cloudflare provider with Workload Identity to automate DNS record creation for ArgoCD Ingress.

## Prerequisites

- Phase 6.13 completed (Cloudflare API token in Secret Manager)
- Phase 6.7 completed (externaldns GCP SA + WI binding created)
- Helm CLI installed
- kubectl access to argocd namespace

## Detailed Steps

### Step 1: Add ExternalDNS Helm Repository

```bash
helm repo add external-dns https://kubernetes-sigs.github.io/external-dns/
helm repo update
```

Expected output:
```
"external-dns" has been added to your repositories
Successfully got an update from the "external-dns" chart repository
```

### Step 2: Create values-externaldns.yaml

```bash
cat > /tmp/values-externaldns.yaml <<'EOF'
# ExternalDNS for Cloudflare on GKE Autopilot
provider: cloudflare

# Cloudflare configuration
cloudflare:
  secretName: cloudflare-api-token
  proxied: false  # No Cloudflare proxy (direct to GCP LB)

# DNS domain filtering
domainFilters:
  - pcconnect.ai

# Only manage DNS records created by ExternalDNS
policy: sync  # Create/update/delete records

# Source for DNS records
sources:
  - ingress
  - service

# TXT registry for ownership tracking
registry: txt
txtPrefix: externaldns-
txtOwnerId: argocd-nonprod

# Workload Identity
serviceAccount:
  create: true
  name: externaldns
  annotations:
    iam.gke.io/gcp-service-account: externaldns@pcc-prj-devops-nonprod.iam.gserviceaccount.com

# Autopilot resource requirements
resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 200m
    memory: 256Mi

# Security context
securityContext:
  runAsNonRoot: true
  runAsUser: 65534
  fsGroup: 65534
  allowPrivilegeEscalation: false
  capabilities:
    drop:
    - ALL

# Deployment strategy
replicas: 1
revisionHistoryLimit: 3

# Logging
logLevel: info
logFormat: json

# Environment variables for Cloudflare token
env:
  - name: CF_API_TOKEN
    valueFrom:
      secretKeyRef:
        name: cloudflare-api-token
        key: token
EOF
```

### Step 3: Create Kubernetes Secret from GCP Secret Manager

```bash
# Retrieve token from Secret Manager
TOKEN=$(gcloud secrets versions access latest --secret=cloudflare-api-token)

# Create K8s secret in argocd namespace
kubectl create secret generic cloudflare-api-token \
  -n argocd \
  --from-literal=token="${TOKEN}"

# Clear token from shell
unset TOKEN
```

**Expected**: `secret/cloudflare-api-token created`

**Note**: Runs from workstation using your gcloud credentials (not Workload Identity).

### Step 4: Install ExternalDNS

```bash
helm install external-dns external-dns/external-dns \
  --version 1.14.3 \
  --namespace argocd \
  -f /tmp/values-externaldns.yaml
```

Expected output:
```
NAME: external-dns
LAST DEPLOYED: <timestamp>
NAMESPACE: argocd
STATUS: deployed
REVISION: 1
```

### Step 5: Watch Pod Creation

```bash
kubectl get pods -n argocd -l app.kubernetes.io/name=external-dns --watch
```

Wait for pod to reach Running status (~1-2 minutes).

Press `Ctrl+C` when pod shows Running/1/1.

### Step 6: Verify ExternalDNS Logs

```bash
kubectl logs -n argocd -l app.kubernetes.io/name=external-dns --tail=50
```

**Expected log entries**:
```
level=info msg="Connected to Cloudflare API"
level=info msg="Applying provider record filter for domains: [pcconnect.ai]"
level=info msg="All records are already up to date"
```

**HALT if**: Authentication errors or "Invalid Cloudflare API token"

### Step 7: Verify Workload Identity Binding

```bash
kubectl exec -n argocd deployment/external-dns-external-dns -- \
  curl -sS -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email
```

**Expected**: `externaldns@pcc-prj-devops-nonprod.iam.gserviceaccount.com`

### Step 8: Check Helm Release

```bash
helm list -n argocd
```

Expected to see both releases:
```
NAME            NAMESPACE   REVISION    STATUS      CHART
argocd          argocd      1           deployed    argo-cd-9.0.5
external-dns    argocd      1           deployed    external-dns-1.14.3
```

## Success Criteria

- ✅ Helm repo added successfully
- ✅ ExternalDNS installed without errors
- ✅ Pod reaches Running state
- ✅ Logs show successful Cloudflare API connection
- ✅ No authentication errors
- ✅ Workload Identity validated
- ✅ Helm release status = deployed

## HALT Conditions

**HALT if**:
- Helm install fails
- Pod stuck in Pending/CrashLoopBackOff
- Authentication errors in logs
- Invalid Cloudflare API token
- Workload Identity not working

**Resolution**:
- Check pod logs: `kubectl logs -n argocd -l app.kubernetes.io/name=external-dns`
- Describe pod: `kubectl describe pod -n argocd -l app.kubernetes.io/name=external-dns`
- Verify secret exists: `kubectl get secret cloudflare-api-token -n argocd`
- Test token: See Phase 6.13 Step 2
- Check WI binding: `gcloud iam service-accounts get-iam-policy externaldns@pcc-prj-devops-nonprod.iam.gserviceaccount.com`
- Rollback if needed: `helm uninstall external-dns -n argocd`

## Next Phase

Proceed to **Phase 6.15**: Create Ingress + BackendConfig Manifests

## Notes

- ExternalDNS watches for Ingress resources and creates DNS records automatically
- `policy: sync` means ExternalDNS will create/update/delete records as needed
- `txtOwnerId` prevents conflicts with other ExternalDNS instances
- TXT records track ownership: `externaldns-argocd-nonprod.pcconnect.ai`
- Cloudflare proxy disabled (proxied: false) - traffic goes directly to GCP LB
- Single replica sufficient for nonprod
- ExternalDNS uses Workload Identity to read cloudflare-api-token secret
- Chart version 1.14.3 is latest stable as of Oct 2024
- If install fails, safe to uninstall and retry after fixing issues
- DNS record creation happens in Phase 6.16 when Ingress is deployed
