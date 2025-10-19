# ADR-002: Apigee to GKE Ingress Strategy

**Status**: ✅ DECIDED - GKE Ingress + PSC (flexible pending backend requirements)
**Date**: 2025-10-18
**Decision Makers**: Platform Architecture Team
**Related**: ADR-001 (Two-Org Apigee Architecture), devtest-deployment-phases.md
**Three-Way AI Consultation**: Claude, Gemini, Codex (2025-10-18)

## Context

Apigee X needs to route API requests to backend .NET 10 microservices running on GKE clusters. The devtest environment requires a reliable, secure, and maintainable ingress strategy for Apigee → GKE traffic routing.

### Current Architecture

**Internet → Apigee Flow** (Phase 8):
- External HTTPS Load Balancer
- PSC NEG (Private Service Connect Network Endpoint Group)
- Google-managed SSL certificates
- Cloud Armor IP allowlist

**Apigee → GKE Flow** (Phases 3, 6, 7):
- VPC peering: `pcc-vpc-nonprod` ↔ `pcc-vpc-app-devtest`
- Firewall rules: Allow 10.24.192.0/20 → GKE subnets (ports 80, 443)
- **Missing**: Ingress mechanism for stable backend endpoints

### Problem Statement

Apigee backend targets need stable, routable endpoints to reach K8s services. The current plan references K8s service FQDNs (e.g., `http://pcc-auth-api.pcc-auth-api.svc.cluster.local`), but **VPC peering doesn't enable cross-cluster DNS resolution** from Apigee runtime instances to GKE CoreDNS.

**Identified Issue**: Apigee cannot resolve K8s service hostnames without additional DNS/networking configuration.

## Decision Options

### Option A: NGINX Ingress Controller (RECOMMENDED - DRAFT)

**Description**: Deploy NGINX Ingress Controller in GKE with internal load balancer (ILB) providing stable IP address for Apigee backend targets.

**Architecture**:
```
Apigee Runtime (10.24.192.0/20)
  ↓ VPC peering
GCP Internal Load Balancer (static IP in 10.28.0.0/20)
  ↓
NGINX Ingress Controller (K8s Service type: LoadBalancer)
  ↓
K8s Services (pcc-auth-api, pcc-user-api, etc.)
```

**Pros**:
- ✅ Vendor-neutral, community standard (500k+ installations)
- ✅ Stable IP address for Apigee backend targets (no DNS dependency)
- ✅ Fine-grained routing control (path rewrites, rate limiting, auth delegation)
- ✅ Familiar to DevOps teams (common pattern)
- ✅ SSL termination at ingress (internal mTLS optional)
- ✅ Observability: Prometheus metrics, NGINX access logs
- ✅ Canary deployments, A/B testing via Ingress annotations

**Cons**:
- ⚠️ Additional infrastructure to manage (NGINX pods, HPA, upgrades)
- ⚠️ Requires separate SSL cert management (cert-manager or Google CA Service)
- ⚠️ Extra hop (latency: ~2-5ms added vs. direct Service routing)
- ⚠️ Cost: ILB (~$20-30/month) + NGINX pod compute

**Implementation Phases**:
- Phase 3: Deploy NGINX Ingress Controller + ILB
- Phase 6: Create Ingress resources for 7 microservices
- Phase 7: Configure Apigee backend targets with ILB IP

**Example Apigee Backend Target**:
```
http://10.28.5.100/auth-api
```
(Where 10.28.5.100 = ILB static IP, path routing via Ingress rules)

---

### Option B: GCP Ingress (GKE Ingress Controller)

**Description**: Use GKE's native ingress controller with Google Cloud Load Balancer backend.

**Architecture**:
```
Apigee Runtime (10.24.192.0/20)
  ↓ VPC peering
GCP Internal Load Balancer (auto-provisioned by GKE Ingress)
  ↓
GKE Ingress Controller
  ↓
K8s Services (pcc-auth-api, pcc-user-api, etc.)
```

**Pros**:
- ✅ Native GKE integration (no additional controllers to manage)
- ✅ Automatic SSL cert management via Google-managed certificates
- ✅ Integrated with Cloud Armor (WAF policies)
- ✅ Simplified operations (Google manages LB infrastructure)
- ✅ Health check auto-configuration

**Cons**:
- ⚠️ Vendor lock-in (GCP-specific, harder to migrate to other clouds)
- ⚠️ Less flexible routing (limited path rewrite capabilities)
- ⚠️ Slower iteration (LB provisioning takes 5-10 minutes vs. NGINX instant)
- ⚠️ Requires separate Ingress per service (more YAML overhead)
- ⚠️ Backend configuration tied to GCP annotations (less portable)

**Implementation Phases**:
- Phase 3: Enable GKE Ingress, configure internal LB class
- Phase 6: Create Ingress resources for 7 microservices
- Phase 7: Configure Apigee backend targets with auto-provisioned ILB IPs

---

### Option C: Internal Load Balancer (Direct Service Exposure)

**Description**: Create dedicated internal load balancers for each K8s service via `type: LoadBalancer`.

**Architecture**:
```
Apigee Runtime (10.24.192.0/20)
  ↓ VPC peering
GCP Internal Load Balancer (per-service, 7 ILBs total)
  ↓
K8s Service (type: LoadBalancer)
  ↓
Pods (pcc-auth-api, pcc-user-api, etc.)
```

**Pros**:
- ✅ Simplest configuration (no ingress controller needed)
- ✅ Direct service exposure with stable IP
- ✅ Lowest latency (fewest hops)

**Cons**:
- ❌ Cost explosion: 7 ILBs × $20/month = $140/month (vs. 1 ILB for NGINX)
- ❌ No centralized routing logic (path-based routing requires Apigee config)
- ❌ No SSL termination at K8s layer (TLS handled per-service)
- ❌ Difficult to implement cross-cutting concerns (rate limiting, auth, logging)
- ❌ 7 separate IPs to manage in Apigee backend targets

---

### Option D: CoreDNS Forwarding

**Description**: Configure CoreDNS in GKE to forward DNS queries from Apigee's VPC.

**Architecture**:
```
Apigee Runtime (10.24.192.0/20)
  ↓ VPC peering + DNS forwarding rule
GKE CoreDNS (responds to *.svc.cluster.local queries)
  ↓
K8s Service (ClusterIP)
  ↓
Pods
```

**Pros**:
- ✅ Enables service hostname resolution (closest to original plan)
- ✅ No additional load balancers (cost-effective)

**Cons**:
- ❌ Complex DNS configuration (Cloud DNS private zones + forwarding rules)
- ❌ Tight coupling (Apigee depends on GKE's internal DNS)
- ❌ Security risk: Exposes cluster DNS to external VPC
- ❌ Troubleshooting difficulty (DNS resolution failures hard to debug)
- ❌ Not a standard pattern for Apigee → K8s integration

---

## Decision

**Selected Option**: Option B - GKE Ingress with Private Service Connect

**Rationale**:
1. **Managed Simplicity**: Fully Google-managed ingress reduces operational burden (no NGINX pods, CVE patching, 24/7 ownership)
2. **PSC from Day 1**: Private Service Connect provides better security, isolation, and future scalability vs. VPC peering
3. **Functional Sufficiency**: No concrete requirement TODAY for advanced NGINX features (path rewrites, custom Lua, per-user rate limiting)
4. **Bounded Migration Path**: 7 services = manageable migration to NGINX later if backend requirements emerge
5. **AI-Assisted Build**: Context7 + AI assistance makes both options feasible; chose operational simplicity over build complexity

**Network Architecture**:
```
Internet → External HTTPS LB → PSC NEG → Apigee Runtime
Apigee Runtime → Private Service Connect → GKE Internal HTTP(S) LB → GKE Ingress → Services
```

**Trade-offs Accepted**:
- GCP vendor lock-in (acceptable for GCP-native architecture)
- Less flexible routing (mitigated by Apigee-layer routing logic if needed)
- Potential future migration to NGINX if advanced features required

**Three-Way AI Consultation (2025-10-18)**:
- **Unanimous**: All 3 AIs (Claude, Gemini, Codex) agree - use PSC from day 1, skip VPC peering
- **Split on Ingress**: Gemini/Claude recommended NGINX, Codex recommended GKE Ingress
- **Key Insight (Codex)**: "AI reduces build effort but doesn't change ownership model - running NGINX makes your team the data-plane owner with operational duties Google otherwise absorbs"
- **User Decision**: Start with GKE Ingress + PSC, flexible to add NGINX if backend dev identifies need for advanced rewrites

**Flexibility**:
This decision is provisional pending backend developer feedback on routing requirements. If advanced NGINX features are needed (identified by 10/20), plan will be updated to NGINX + PSC.

## Impacted Phases (for Future Updates)

If this decision changes to NGINX + PSC, the following phases in `devtest-deployment-phases.md` require updates:

### Phase 1: Networking for Devtest (Minor Impact)
- **Current**: References "PSC/service networking configuration"
- **If NGINX**: No change needed (PSC remains the same)

### Phase 3: GKE Clusters (NEW - Add NGINX Deployment)
- **Current**: GKE cluster deployment only
- **If NGINX**: Add NGINX Ingress Controller deployment step
  - Helm chart installation
  - Internal load balancer configuration
  - Static IP allocation

### Phase 7: Apigee Nonprod Org + Devtest Environment (HIGH Impact)
- **Current**: Section 9 "Apigee to GKE Connectivity (Private Service Connect)"
  - PSC service attachment (GKE side)
  - PSC endpoint (Apigee side, IP 10.24.200.10)
  - GKE Ingress configuration (gce-internal class)
  - Backend target: PSC endpoint IP via HTTPS
- **If NGINX**: Update section 9
  - Keep PSC service attachment + endpoint
  - Replace GKE Ingress with NGINX Ingress Controller
  - Backend target: NGINX ILB static IP (e.g., 10.28.5.100)
  - Add NGINX Ingress resource definitions for 7 services
  - Update Apigee backend target to NGINX ILB IP

### Phase 8: External HTTPS Load Balancer & Connectivity (Minor Impact)
- **Current**: References PSC connectivity for Apigee → GKE
- **If NGINX**: Update validation steps
  - Request path: Internet → External LB → PSC NEG → Apigee → PSC Endpoint → **NGINX ILB** → Service
  - No other changes needed

### Files to Update if Decision Changes:
1. `.claude/docs/ADR/002-apigee-gke-ingress-strategy.md` (this file)
   - Update "Decision" section to NGINX + PSC
   - Update "Implementation Details" section with NGINX examples
2. `.claude/plans/devtest-deployment-phases.md`
   - Phase 3: Add NGINX deployment step
   - Phase 7 Section 9: Complete rewrite for NGINX + PSC
   - Phase 7 Validation: Update routing path references
   - Phase 8 Validation: Update end-to-end test flow
3. ADR document status line
   - Change from "GKE Ingress + PSC" to "NGINX + PSC"

**Estimated Update Effort**: 2-3 hours to update all documentation and Terraform examples if pivot is needed.

## Private Service Connect (PSC) Architecture

**Why PSC over VPC Peering** (Unanimous AI Consensus):
- **Security Isolation**: Decouples producer/consumer networks, limits blast radius
- **Scalability**: No VPC peering limits (25 peerings per VPC), supports future multi-project/multi-tenant patterns
- **No IP Overlap**: Eliminates CIDR conflict concerns between Apigee and GKE VPCs
- **Future-Proof**: Aligns with Google's recommended connectivity model for service-to-service communication

**PSC Components**:
1. **Service Attachment** (Producer side - GKE): Exposes internal HTTP(S) LB to PSC consumers
2. **PSC Endpoint** (Consumer side - Apigee): Connects Apigee VPC to GKE service attachment
3. **Internal HTTP(S) LB**: Backed by GKE Ingress, provides stable endpoint for PSC

**Implementation Phases**:
- Phase 3: Deploy PSC service attachment + endpoint for GKE cluster
- Phase 6: Configure GKE Ingress resources for 7 microservices
- Phase 7: Update Apigee backend targets to use PSC endpoint IP

## Implementation Details

### Phase 3: Deploy GKE Ingress + PSC

**Terraform Module**: `core/pcc-tf-library/modules/gke-psc-ingress/`

```hcl
# Step 1: Internal HTTP(S) Load Balancer (auto-provisioned by GKE Ingress)
# Step 2: PSC Service Attachment (exposes ILB to PSC consumers)
module "psc_service_attachment" {
  source = "../../pcc-tf-library/modules/psc-service-attachment"

  project_id    = "pcc-prj-app-devtest"
  name          = "pcc-gke-devtest-psc"
  region        = "us-east1"
  subnet        = "pcc-prj-app-devtest"

  # Auto-provisioned ILB from GKE Ingress
  target_service = module.gke_ingress.forwarding_rule_id

  # Allow Apigee project to connect
  consumer_accept_lists = [{
    project_id_or_num = "pcc-prj-apigee-devtest"
    connection_limit  = 10
  }]
}

# Step 3: PSC Endpoint (in Apigee VPC, connects to service attachment)
module "psc_endpoint" {
  source = "../../pcc-tf-library/modules/psc-endpoint"

  project_id        = "pcc-prj-apigee-devtest"
  name              = "psc-gke-devtest"
  region            = "us-east1"
  network           = "pcc-vpc-nonprod"

  # Points to service attachment in GKE project
  target_service    = module.psc_service_attachment.id

  # Static IP in Apigee subnet for stable backend targets
  ip_address        = "10.24.200.10"
}
```

### Phase 6: Create GKE Ingress Resources

**Example**: `src/pcc-auth-api/k8s/ingress.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: pcc-auth-api-ingress
  namespace: pcc-auth-api
  annotations:
    kubernetes.io/ingress.class: "gce-internal"
    kubernetes.io/ingress.regional-static-ip-name: "pcc-gke-devtest-ilb-ip"
    networking.gke.io/managed-certificates: "pcc-auth-api-cert"
spec:
  rules:
  - http:
      paths:
      - path: /auth-api/*
        pathType: ImplementationSpecific
        backend:
          service:
            name: pcc-auth-api
            port:
              number: 80
```

**Notes**:
- `gce-internal`: Provisions internal HTTP(S) load balancer (not external)
- Regional static IP pre-allocated in Phase 1 for stable PSC targeting
- GKE Ingress automatically creates backend NEGs (Network Endpoint Groups)

### Phase 7: Apigee Backend Target Configuration

**Terraform**: `infra/pcc-apigee-infra/terraform/apigee-backends.tf`

```hcl
resource "google_apigee_target_server" "auth_api_devtest" {
  name        = "pcc-auth-api-devtest"
  description = "Auth API service via PSC to GKE devtest"
  env_id      = google_apigee_environment.devtest.id

  host        = "10.24.200.10"  # PSC endpoint IP in Apigee VPC
  port        = 443
  protocol    = "HTTPS"  # GKE Ingress terminates TLS

  s_sl_info {
    enabled = true
    ignore_validation_errors = false
  }
}
```

**API Proxy Target Endpoint**:
```xml
<TargetEndpoint name="default">
  <HTTPTargetConnection>
    <URL>https://10.24.200.10/auth-api</URL>
  </HTTPTargetConnection>
</TargetEndpoint>
```

**Note**: Traffic flows through PSC tunnel (encrypted), ILB provides stable endpoint

### Validation Checklist

**Phase 3 Validation**:
- [ ] PSC service attachment created and active
- [ ] PSC endpoint created with IP 10.24.200.10
- [ ] Internal HTTP(S) LB auto-provisioned by GKE Ingress
- [ ] Health check passing (LB backend NEGs healthy)
- [ ] PSC connection status: ACCEPTED

**Phase 6 Validation**:
- [ ] GKE Ingress resources created for all 7 services
- [ ] Backend NEGs created automatically (check GCP console)
- [ ] Internal LB forwarding rule updated with new backends
- [ ] curl from Apigee instance to PSC endpoint IP returns service responses

**Phase 7 Validation**:
- [ ] Apigee backend target configured with PSC endpoint IP (10.24.200.10)
- [ ] Test API call: `curl -H "Host: devtest.api.pcconnect.ai" https://devtest.api.pcconnect.ai/v1/auth/health`
- [ ] GKE Ingress logs show requests from Apigee (via PSC tunnel, source IP may be PSC NAT IP)
- [ ] SSL handshake successful (GKE Ingress manages certificates)

## Alternatives Considered

See Options B, C, D above.

## Risks & Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| NGINX pod failure | API downtime | Deploy 2+ replicas with PodDisruptionBudget, enable HPA |
| ILB provisioning failure | Deployment blocked | Pre-allocate static IP in Phase 1, validate in Phase 3 |
| Certificate management complexity | SSL errors | Use cert-manager with Google CA Service integration |
| Path routing misconfiguration | 404 errors | Validate each Ingress with integration tests in Phase 6 |

## Open Questions

1. **SSL/TLS Strategy**: Should NGINX terminate TLS for internal Apigee → GKE traffic? Or use HTTP with firewall isolation?
   - **Recommendation**: HTTP for devtest (VPC peering provides network isolation), mTLS for staging/prod

2. **Rate Limiting**: Implement at NGINX layer or rely on Apigee quotas?
   - **Recommendation**: Apigee quotas (business logic), NGINX for DDoS protection

3. **Monitoring Integration**: Use NGINX Prometheus metrics or rely on GCP Ops Agent?
   - **Recommendation**: Both - NGINX metrics for ingress health, Ops Agent for GKE cluster metrics

4. **Canary Deployments**: Use NGINX weighted routing or ArgoCD Rollouts?
   - **Recommendation**: ArgoCD Rollouts (more mature GitOps integration)

## Success Criteria

- ✅ Apigee can route to all 7 microservices via single ILB IP
- ✅ Response time: <50ms P95 latency for internal routing
- ✅ Zero downtime during NGINX pod restarts (HPA, PDB)
- ✅ Clear observability: NGINX logs show all Apigee → GKE traffic
- ✅ Cost: ≤ $50/month for ingress infrastructure (ILB + compute)

## References

- NGINX Ingress Controller: https://kubernetes.github.io/ingress-nginx/
- GKE Internal Load Balancer: https://cloud.google.com/kubernetes-engine/docs/how-to/internal-load-balancing
- Apigee Target Servers: https://cloud.google.com/apigee/docs/api-platform/fundamentals/target-servers
- Phase 3: GKE Cluster Deployment (devtest-deployment-phases.md)
- Phase 6: Microservices Deployment (devtest-deployment-phases.md)
- Phase 7: Apigee Configuration (devtest-deployment-phases.md)

## Timeline

- **Phase 3** (Week 2): NGINX Ingress Controller deployment
- **Phase 6** (Week 3): Ingress resources for 7 services
- **Phase 7** (Week 4): Apigee backend configuration + testing

## Review Notes

**2025-10-17**: Initial draft created based on agent-organizer feedback
- Issue: K8s service FQDNs not routable from Apigee via VPC peering
- Initial recommendation: NGINX Ingress with ILB
- Status: Under discussion

**2025-10-18**: Three-way AI consultation completed (Claude, Gemini, Codex)
- **Unanimous**: PSC from day 1 (all 3 AIs agree)
- **Split**: Gemini/Claude recommended NGINX, Codex recommended GKE Ingress
- **Decision**: GKE Ingress + PSC (operational simplicity, pending backend requirements)
- **Flexibility**: Plan can pivot to NGINX + PSC if backend dev identifies need for advanced rewrites
- Status: ✅ DECIDED (flexible)
