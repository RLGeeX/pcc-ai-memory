# Phase 6.16: Deploy Ingress (ExternalDNS Auto-Creates DNS)

**Tool**: [WARP] Partner Execution
**Estimated Duration**: 20 minutes

## Purpose

Deploy ArgoCD Ingress with BackendConfig, triggering ExternalDNS to automatically create DNS A record pointing to GCP load balancer, then wait for SSL certificate provisioning.

## Prerequisites

- Phase 6.15 completed (manifests created and committed)
- Phase 6.14 completed (ExternalDNS installed)
- kubectl access to argocd namespace

## Detailed Steps

### Step 1: Apply Ingress Manifests

```bash
cd ~/pcc/core/pcc-app-argo-config/argocd-nonprod/devtest/ingress

kubectl apply -k .
```

**Expected Output**:
```
backendconfig.cloud.google.com/argocd-server-backend-config created
service/argocd-server configured
ingress.networking.k8s.io/argocd-server created
```

### Step 2: Watch Ingress Provisioning

```bash
kubectl get ingress argocd-server -n argocd --watch
```

Wait for ADDRESS to be assigned (~2-3 minutes).

Expected progression:
```
NAME             CLASS    HOSTS                             ADDRESS         PORTS     AGE
argocd-server    <none>   argocd.nonprod.pcconnect.ai       <pending>       80, 443   10s
argocd-server    <none>   argocd.nonprod.pcconnect.ai       34.120.x.x      80, 443   2m
```

Press `Ctrl+C` when ADDRESS is assigned.

### Step 3: Get Load Balancer IP

```bash
LB_IP=$(kubectl get ingress argocd-server -n argocd \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Load Balancer IP: ${LB_IP}"
```

**Expected**: Public IP in format `34.120.x.x`

### Step 4: Watch ExternalDNS Logs for DNS Creation

```bash
kubectl logs -n argocd -l app.kubernetes.io/name=external-dns --tail=100 -f
```

Wait for log entry showing DNS record creation (~1-2 minutes):

**Expected log entries**:
```
level=info msg="Desired change: CREATE argocd.nonprod.pcconnect.ai A [34.120.x.x]"
level=info msg="Desired change: CREATE externaldns-argocd.nonprod.pcconnect.ai TXT ..."
level=info msg="2 record(s) in zone pcconnect.ai were successfully updated"
```

Press `Ctrl+C` after seeing successful update.

### Step 5: Verify DNS Record Created in Cloudflare

```bash
# Query Cloudflare DNS
dig @1.1.1.1 argocd.nonprod.pcconnect.ai +short
```

**Expected**: Should return the load balancer IP from Step 3

**HALT if**: No IP returned or wrong IP

Alternative verification:
```bash
nslookup argocd.nonprod.pcconnect.ai 1.1.1.1
```

### Step 6: Verify TXT Ownership Record

```bash
dig @1.1.1.1 externaldns-argocd.nonprod.pcconnect.ai TXT +short
```

**Expected**: TXT record containing ownership identifier `"heritage=external-dns,external-dns/owner=argocd-nonprod"`

### Step 7: Check SSL Certificate Status

```bash
kubectl describe ingress argocd-server -n argocd | grep -A 10 "Events:"
```

**Expected Events**:
```
Events:
  Type    Reason  Age    From                     Message
  ----    ------  ----   ----                     -------
  Normal  Sync    5m     loadbalancer-controller  UrlMap "k8s2-um-..." created
  Normal  Sync    4m     loadbalancer-controller  TargetHttpsProxy "k8s2-ts-..." created
  Normal  Sync    3m     loadbalancer-controller  ForwardingRule "k8s2-fr-..." created
```

### Step 8: Wait for SSL Certificate Provisioning

```bash
# Check certificate status
gcloud compute ssl-certificates describe argocd-nonprod-cert \
  --format="value(managed.status)"
```

**Expected progression**:
- Initially: `PROVISIONING`
- After 10-15 minutes: `ACTIVE`

**Note**: Certificate provisioning requires:
1. DNS record pointing to load balancer (completed in Step 5)
2. Load balancer responding to HTTP-01 challenges
3. Google verifying domain ownership

**HALT if**: Status is `FAILED_NOT_VISIBLE` or `FAILED`

### Step 9: Test HTTP to HTTPS Redirect

```bash
# Should redirect to HTTPS
curl -I http://argocd.nonprod.pcconnect.ai
```

**Expected**:
```
HTTP/1.1 301 Moved Permanently
Location: https://argocd.nonprod.pcconnect.ai/
```

**Note**: May return 404 or connection refused while cert is provisioning - this is normal.

### Step 10: Verify BackendConfig Applied

```bash
kubectl get backendconfig argocd-server-backend-config -n argocd -o yaml
```

Verify configuration includes:
- `connectionDraining.drainingTimeoutSec: 60`
- `healthCheck.requestPath: /healthz`
- `sessionAffinity.affinityType: CLIENT_IP`

## Success Criteria

- ✅ Ingress created with ADDRESS assigned
- ✅ ExternalDNS logs show successful DNS record creation
- ✅ DNS A record resolves to load balancer IP
- ✅ TXT ownership record created
- ✅ SSL certificate status is PROVISIONING or ACTIVE
- ✅ HTTP redirects to HTTPS (may 404 until cert is ACTIVE)
- ✅ BackendConfig applied correctly

## HALT Conditions

**HALT if**:
- Ingress stuck without ADDRESS after 5 minutes
- ExternalDNS does not create DNS record after 5 minutes
- DNS query returns no IP or wrong IP
- SSL certificate status is FAILED
- No Events showing load balancer creation

**Resolution**:
- Check Ingress events: `kubectl describe ingress argocd-server -n argocd`
- Verify ExternalDNS logs: `kubectl logs -n argocd -l app.kubernetes.io/name=external-dns`
- Test Cloudflare API token: See Phase 6.13 Step 2
- Check BackendConfig: `kubectl describe backendconfig -n argocd`
- Verify Service annotations: `kubectl get svc argocd-server -n argocd -o yaml | grep annotations -A 5`
- Check GCP SSL cert exists: `gcloud compute ssl-certificates list`
- Delete and recreate if stuck: `kubectl delete ingress argocd-server -n argocd && kubectl apply -k .`

## Next Phase

**WAIT**: Do NOT proceed to Phase 6.17 until SSL certificate status is `ACTIVE` (may take 10-15 minutes).

Once certificate is ACTIVE, proceed to **Phase 6.17**: Validate Google Workspace Groups RBAC

## Notes

- ExternalDNS polls Ingress resources every 60 seconds (default)
- DNS propagation via Cloudflare is near-instant (< 30 seconds)
- SSL certificate provisioning takes 10-15 minutes on first deployment
- Certificate renewal is automatic (no manual intervention)
- TXT record tracks ownership to prevent conflicts
- Load balancer IP is regional (us-east4)
- BackendConfig enables advanced GCP load balancer features
- Network Endpoint Groups route traffic directly to pods (not nodes)
- Health check ensures traffic only goes to healthy pods
- Connection draining prevents dropped requests during pod restarts
- If certificate fails provisioning, check DNS record points to correct IP
- Ingress creation triggers GCP load balancer provisioning (takes 2-3 minutes)
- Do NOT access ArgoCD UI until certificate is ACTIVE (browser will show security warning)
