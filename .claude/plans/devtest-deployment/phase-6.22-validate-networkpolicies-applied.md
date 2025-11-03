# Phase 6.22: Validate NetworkPolicies Applied

**Tool**: [WARP] Partner Execution
**Estimated Duration**: 15 minutes

## Purpose

Verify NetworkPolicies deployed by ArgoCD are correctly applied to ArgoCD pods and test network connectivity between components.

## Prerequisites

- Phase 6.21 completed (app-of-apps deployed, NetworkPolicies synced)
- kubectl access to argocd namespace

## Detailed Steps

### Step 1: List All NetworkPolicies

```bash
kubectl get networkpolicies -n argocd
```

**Expected Output**: 6 NetworkPolicies:
```
NAME                              POD-SELECTOR
argocd-server                     app.kubernetes.io/name=argocd-server
argocd-application-controller     app.kubernetes.io/name=argocd-application-controller
argocd-repo-server                app.kubernetes.io/name=argocd-repo-server
argocd-dex-server                 app.kubernetes.io/name=argocd-dex-server
argocd-redis                      app.kubernetes.io/name=argocd-redis
external-dns                      app.kubernetes.io/name=external-dns
```

**HALT if**: Fewer than 6 NetworkPolicies exist

### Step 2: Verify NetworkPolicy Pod Selectors Match Pods

```bash
# For each NetworkPolicy, verify pods exist with matching labels
for np in argocd-server argocd-application-controller argocd-repo-server argocd-dex-server argocd-redis external-dns; do
  echo "NetworkPolicy: $np"
  kubectl get pods -n argocd -l app.kubernetes.io/name=$np
  echo "---"
done
```

**Expected**: Each NetworkPolicy has at least one matching pod

**HALT if**: Any NetworkPolicy has no matching pods

### Step 3: Describe NetworkPolicy for ArgoCD Server

```bash
kubectl describe networkpolicy argocd-server -n argocd
```

**Expected Output** shows:
- **PodSelector**: `app.kubernetes.io/name=argocd-server`
- **Allowing ingress traffic**: From all pods
- **Allowing egress traffic**: To all destinations (wide-open)
- **Policy Types**: Ingress, Egress

### Step 4: Test Ingress Connectivity to ArgoCD Server

```bash
# Test from external-dns pod to argocd-server
kubectl exec -n argocd deployment/external-dns-external-dns -- \
  curl -sS -o /dev/null -w "%{http_code}" http://argocd-server.argocd.svc.cluster.local
```

**Expected**: HTTP status code `200` or `302` (redirect to login)

**HALT if**: Connection refused or timeout

### Step 5: Test Application Controller to Repo Server

```bash
# Get repo-server service IP
REPO_SERVER_IP=$(kubectl get svc argocd-repo-server -n argocd -o jsonpath='{.spec.clusterIP}')

# Test connectivity from application-controller to repo-server
kubectl exec -n argocd statefulset/argocd-application-controller -- \
  nc -zv ${REPO_SERVER_IP} 8081
```

**Expected**: `Connection to ${REPO_SERVER_IP} 8081 port [tcp/*] succeeded!`

**HALT if**: Connection refused

### Step 6: Test Dex to Google OAuth (Egress)

```bash
# Test that Dex can reach Google OAuth endpoints
kubectl exec -n argocd deployment/argocd-dex-server -- \
  curl -sS -o /dev/null -w "%{http_code}" https://accounts.google.com/.well-known/openid-configuration
```

**Expected**: HTTP status code `200`

**HALT if**: Connection timeout or failed

### Step 7: Test ExternalDNS to Cloudflare API (Egress)

```bash
# Test that ExternalDNS can reach Cloudflare API
kubectl exec -n argocd deployment/external-dns-external-dns -- \
  curl -sS -o /dev/null -w "%{http_code}" https://api.cloudflare.com/client/v4/user/tokens/verify \
  -H "Authorization: Bearer $(kubectl get secret cloudflare-api-token -n argocd -o jsonpath='{.data.token}' | base64 -d)"
```

**Expected**: HTTP status code `200`

**HALT if**: HTTP 401 (invalid token) or connection timeout

### Step 8: Test Redis Connectivity from ArgoCD Components

```bash
# Get Redis service IP
REDIS_IP=$(kubectl get svc argocd-redis -n argocd -o jsonpath='{.spec.clusterIP}')

# Test from argocd-server to Redis
kubectl exec -n argocd deployment/argocd-server -- \
  nc -zv ${REDIS_IP} 6379
```

**Expected**: `Connection to ${REDIS_IP} 6379 port [tcp/*] succeeded!`

**HALT if**: Connection refused

### Step 9: Verify Wide-Open Egress Works

```bash
# Test arbitrary external connection (should work with wide-open egress)
kubectl exec -n argocd deployment/argocd-server -- \
  curl -sS -o /dev/null -w "%{http_code}" https://www.google.com
```

**Expected**: HTTP status code `200` or `301`

**Note**: This confirms egress is NOT restricted (nonprod philosophy)

### Step 10: Check NetworkPolicy Managed by ArgoCD

```bash
# Verify NetworkPolicies have ArgoCD annotations
kubectl get networkpolicy argocd-server -n argocd -o yaml | grep -A 5 "app.kubernetes.io/instance"
```

**Expected**: Shows ArgoCD application instance annotation:
```yaml
app.kubernetes.io/instance: argocd-network-policies
```

**This confirms**: NetworkPolicies are managed by ArgoCD (not manual kubectl)

## Success Criteria

- ✅ All 6 NetworkPolicies exist
- ✅ Each NetworkPolicy has matching pods
- ✅ Ingress connectivity to argocd-server works
- ✅ Application controller can reach repo-server
- ✅ Dex can reach Google OAuth endpoints (egress)
- ✅ ExternalDNS can reach Cloudflare API (egress)
- ✅ ArgoCD components can reach Redis
- ✅ Wide-open egress confirmed (arbitrary internet access)
- ✅ NetworkPolicies managed by ArgoCD (annotations present)

## HALT Conditions

**HALT if**:
- Missing NetworkPolicies
- NetworkPolicies have no matching pods
- Ingress connectivity to argocd-server fails
- Component-to-component connectivity fails
- Egress to external APIs fails
- Redis connectivity fails
- ArgoCD annotations missing from NetworkPolicies

**Resolution**:
- Check NetworkPolicy application status: `argocd app get argocd-network-policies`
- Verify pod labels match NetworkPolicy selectors:
  ```bash
  kubectl get pods -n argocd --show-labels
  ```
- Describe NetworkPolicy for detailed rules:
  ```bash
  kubectl describe networkpolicy <name> -n argocd
  ```
- Check if NetworkPolicy controller is running (GKE Autopilot has built-in support)
- Test with verbose curl:
  ```bash
  kubectl exec -n argocd deployment/argocd-server -- \
    curl -v http://argocd-repo-server.argocd.svc.cluster.local:8081
  ```
- Check ArgoCD application logs:
  ```bash
  kubectl logs -n argocd statefulset/argocd-application-controller -c application-controller --tail=50 | grep network-policies
  ```
- Force sync NetworkPolicy app: `argocd app sync argocd-network-policies`

## Next Phase

Proceed to **Phase 6.23**: Create Hello-World App Manifests

## Notes

- **GKE Autopilot**: NetworkPolicy enforcement is built-in (no Calico/Cilium install needed)
- **Wide-Open Egress**: Nonprod philosophy allows all outbound traffic for debugging
- **Production**: Tighten egress rules to only allow required destinations
- NetworkPolicies are additive (multiple policies on same pod are OR'd)
- Pod-to-pod communication within argocd namespace is allowed by default
- Ingress from GCP load balancer appears as pod traffic (not external)
- ExternalDNS needs egress to Cloudflare API (1.1.1.1)
- Dex needs egress to Google OAuth (accounts.google.com)
- Application controller and repo-server need egress to Git repositories
- Redis has no egress (cache only)
- NetworkPolicies apply at pod level (not service level)
- Service ClusterIP is just an iptables rule (NetworkPolicy works on pod IPs)
- If connectivity fails, check CNI plugin logs (GKE Autopilot abstracts this)
- ArgoCD manages NetworkPolicies via GitOps (any manual kubectl changes will be reverted)
- NetworkPolicy controller processes policies asynchronously (may take 10-30 seconds)
- Use `kubectl logs` with `-c` flag for multi-container pods (e.g., application-controller)
