# Chunk 11: Configure Ingress and Create DNS Record

**Status:** pending
**Dependencies:** chunk-010-helm-install
**Complexity:** simple
**Estimated Time:** 15 minutes
**Tasks:** 2
**Phase:** Access & Security
**Story:** STORY-705
**Jira:** PCC-291

---

## Task 1: Verify Ingress Creation

**Agent:** k8s-architect

**Step 1: Check Ingress resource**

```bash
kubectl get ingress -n argocd
```

Expected: `argocd-server` Ingress with ADDRESS pending (GCP provisioning LoadBalancer)

**Step 2: Wait for LoadBalancer IP**

```bash
# Wait up to 5 minutes for IP
kubectl get ingress argocd-server -n argocd --watch
```

Expected: ADDRESS field populated with external IP (e.g., 34.x.x.x)

**Step 3: Get LoadBalancer IP**

```bash
INGRESS_IP=$(kubectl get ingress argocd-server -n argocd \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Ingress IP: $INGRESS_IP"
```

---

## Task 2: Create DNS A Record

**Agent:** cloud-architect

**Step 1: Create A record in Cloud DNS**

```bash
gcloud dns record-sets create argocd-prod.portcon.com \
  --zone=portcon-com \
  --type=A \
  --ttl=300 \
  --rrdatas=$INGRESS_IP \
  --project=pcc-prj-shared-services
```

Expected: "Created [https://dns.googleapis.com/dns/v1/projects/...]"

**Step 2: Verify DNS propagation**

```bash
# Check DNS resolution (may take 1-2 minutes)
dig argocd-prod.portcon.com +short
```

Expected: Returns the LoadBalancer IP

**Step 3: Document DNS configuration**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra
cat <<EOF >> environments/prod/docs/deployment-notes.md

## DNS Configuration
- Domain: argocd-prod.portcon.com
- DNS Zone: portcon-com (project: pcc-prj-shared-services)
- A Record: $INGRESS_IP
- Ingress: argocd-server (namespace: argocd)
EOF

git add environments/prod/docs/deployment-notes.md
git commit -m "feat(phase-7): create DNS A record for argocd-prod.portcon.com"
```

---

## Chunk Complete Checklist

- [ ] Ingress resource created
- [ ] LoadBalancer IP obtained
- [ ] DNS A record created (argocd-prod.portcon.com)
- [ ] DNS resolution verified
- [ ] DNS configuration documented
- [ ] Ready for chunk 12 (SSL cert validation)
