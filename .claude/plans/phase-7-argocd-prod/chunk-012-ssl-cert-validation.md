# Chunk 12: Verify SSL Certificate Provisioning

**Status:** pending
**Dependencies:** chunk-011-ingress-dns
**Complexity:** simple
**Estimated Time:** 20 minutes
**Tasks:** 2
**Phase:** Access & Security
**Story:** STORY-705
**Jira:** PCC-292

---

## Task 1: Monitor SSL Certificate Provisioning

**Agent:** cloud-architect

**Step 1: Check managed certificate status**

```bash
gcloud compute ssl-certificates describe argocd-prod-tls \
  --project=pcc-prj-devops-prod \
  --format="value(managed.status)"
```

Expected states:
- Initial: "PROVISIONING"
- After 10-15 minutes: "ACTIVE"

**Step 2: Wait for ACTIVE status**

```bash
# Poll every 60 seconds (timeout: 15 minutes)
for i in {1..15}; do
  STATUS=$(gcloud compute ssl-certificates describe argocd-prod-tls \
    --project=pcc-prj-devops-prod \
    --format="value(managed.status)")

  echo "[$i/15] Certificate status: $STATUS"

  if [ "$STATUS" = "ACTIVE" ]; then
    echo "✓ SSL certificate provisioned successfully"
    break
  fi

  if [ $i -eq 15 ]; then
    echo "⚠ Certificate still provisioning after 15 minutes"
    echo "This is normal. GCP may take up to 60 minutes for initial provisioning."
  fi

  sleep 60
done
```

**Step 3: Verify certificate details**

```bash
gcloud compute ssl-certificates describe argocd-prod-tls \
  --project=pcc-prj-devops-prod \
  --format=yaml
```

Expected:
- `managed.domains[0]: argocd-prod.portcon.com`
- `managed.status: ACTIVE`

---

## Task 2: Test HTTPS Access

**Agent:** k8s-architect

**Step 1: Test HTTPS connection**

```bash
curl -I https://argocd-prod.portcon.com
```

Expected:
- HTTP/2 200 (if cert is ACTIVE)
- OR "SSL certificate problem" (if cert still provisioning)

**Step 2: Access ArgoCD UI (manual)**

Open browser: `https://argocd-prod.portcon.com`

Expected:
- ArgoCD login page loads
- No SSL warnings (if cert ACTIVE)
- HTTPS padlock icon visible

**Step 3: Document SSL status**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra
cat <<EOF >> environments/prod/docs/deployment-notes.md

## SSL Certificate
- Certificate Name: argocd-prod-tls
- Status: ACTIVE
- Domain: argocd-prod.portcon.com
- Provisioning Time: ~10-15 minutes
- Access URL: https://argocd-prod.portcon.com
EOF

git add environments/prod/docs/deployment-notes.md
git commit -m "feat(phase-7): verify SSL certificate provisioned for argocd-prod"
```

---

## Chunk Complete Checklist

- [ ] SSL certificate status checked
- [ ] Certificate reached ACTIVE status (or documented waiting time)
- [ ] HTTPS connection tested
- [ ] ArgoCD UI accessible via HTTPS
- [ ] No SSL warnings (when ACTIVE)
- [ ] SSL configuration documented
- [ ] Ready for chunk 13 (Google OAuth)
