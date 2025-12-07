# Chunk 16: Create NetworkPolicy Manifests (Wide-Open Egress)

**Status:** pending
**Dependencies:** chunk-015-app-of-apps
**Complexity:** simple
**Estimated Time:** 10 minutes
**Tasks:** 2
**Phase:** GitOps Patterns
**Story:** STORY-707
**Jira:** PCC-296

---

## Task 1: Create Base NetworkPolicy Template

**Agent:** k8s-security

**Step 1: Create egress-all NetworkPolicy for argocd namespace**

File: `core/pcc-app-argo-config/prod/network-policies/argocd-egress-all.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: egress-all
  namespace: argocd
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - {}  # Allow all egress traffic
```

**Step 2: Create egress-all NetworkPolicy for default namespace**

File: `core/pcc-app-argo-config/prod/network-policies/default-egress-all.yaml`

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: egress-all
  namespace: default
spec:
  podSelector: {}
  policyTypes:
  - Egress
  egress:
  - {}  # Allow all egress traffic
```

---

## Task 2: Commit NetworkPolicy Manifests

**Agent:** k8s-security

**Step 1: Create README explaining policy**

File: `core/pcc-app-argo-config/prod/network-policies/README.md`

```markdown
# Production NetworkPolicies

## Egress Policy: Allow All

**Decision**: Wide-open egress for production (same as nonprod)

All namespaces have `egress: [{}]` which allows unrestricted outbound traffic.

**Rationale**:
- Simplified operations (no egress rule maintenance)
- Faster troubleshooting (no network-related blocks)
- Cost-effective (no NAT Gateway required)
- Production workloads require external API access

**Security Note**:
Pods can reach any external destination. Review access logs via Cloud Logging.
```

**Step 2: Commit and push**

```bash
cd ~/pcc/core/pcc-app-argo-config
git add prod/network-policies/
git commit -m "feat(phase-7): add wide-open egress NetworkPolicies for prod"
git push origin main
```

---

## Chunk Complete Checklist

- [ ] NetworkPolicy manifests created (argocd, default namespaces)
- [ ] Wide-open egress configured (egress: [{}])
- [ ] README explaining egress policy decision
- [ ] Manifests committed and pushed
- [ ] Ready for chunk 17 (hello-world sample)
