# Chunk 11: Create Production Cluster Documentation

**Status:** pending
**Dependencies:** chunk-009-connect-gateway, chunk-010-workload-identity
**Complexity:** simple
**Estimated Time:** 20 minutes
**Tasks:** 2
**Phase:** Documentation
**Story:** STORY-4.8
**Jira:** PCC-306

---

## Task 1: Create Comprehensive Cluster Documentation

**Agent:** documentation-engineer

**Step 1: Create prod-cluster-guide.md**

File: `infra/pcc-devops-infra/docs/prod-cluster-guide.md`

```markdown
# Production DevOps GKE Cluster Guide

## Overview

**Cluster Name:** pcc-gke-devops-prod
**Project:** pcc-prj-devops-prod
**Region:** us-east4
**Type:** GKE Autopilot
**Purpose:** Production DevOps workloads (ArgoCD, monitoring tools)

## Cluster Details

- **Kubernetes Version:** [from chunk 8 validation]
- **Release Channel:** STABLE
- **Deletion Protection:** Enabled
- **Workload Identity:** Enabled (pcc-prj-devops-prod.svc.id.goog)
- **Connect Gateway:** Enabled
- **Network:** pcc-vpc-prod (Shared VPC)
- **Subnet:** pcc-prj-devops-prod

## Access Methods

### Connect Gateway (Recommended)

Generate kubeconfig:
\`\`\`bash
gcloud container fleet memberships get-credentials pcc-gke-devops-prod \\
  --project=pcc-prj-devops-prod
\`\`\`

Verify access:
\`\`\`bash
kubectl cluster-info
kubectl get nodes
\`\`\`

### IAM Requirements

**Required Group:** gcp-devops@pcconnect.ai

**Required Roles:**
- `roles/gkehub.gatewayAdmin` - Connect Gateway access
- `roles/container.clusterViewer` - View cluster metadata

## Workload Identity Setup

### For New Workloads

1. Create GCP Service Account:
\`\`\`bash
gcloud iam service-accounts create WORKLOAD-sa \\
  --display-name="Workload SA" \\
  --project=pcc-prj-devops-prod
\`\`\`

2. Grant necessary GCP permissions:
\`\`\`bash
gcloud projects add-iam-policy-binding pcc-prj-devops-prod \\
  --member="serviceAccount:WORKLOAD-sa@pcc-prj-devops-prod.iam.gserviceaccount.com" \\
  --role=roles/REQUIRED_ROLE
\`\`\`

3. Create Kubernetes ServiceAccount:
\`\`\`bash
kubectl create serviceaccount WORKLOAD-sa -n NAMESPACE
\`\`\`

4. Bind K8s SA to GCP SA:
\`\`\`bash
gcloud iam service-accounts add-iam-policy-binding \\
  WORKLOAD-sa@pcc-prj-devops-prod.iam.gserviceaccount.com \\
  --role=roles/iam.workloadIdentityUser \\
  --member="serviceAccount:pcc-prj-devops-prod.svc.id.goog[NAMESPACE/WORKLOAD-sa]" \\
  --project=pcc-prj-devops-prod
\`\`\`

5. Annotate K8s ServiceAccount:
\`\`\`bash
kubectl annotate serviceaccount WORKLOAD-sa \\
  -n NAMESPACE \\
  iam.gke.io/gcp-service-account=WORKLOAD-sa@pcc-prj-devops-prod.iam.gserviceaccount.com
\`\`\`

## Common Operations

### Check Cluster Health
\`\`\`bash
gcloud container clusters describe pcc-gke-devops-prod \\
  --region=us-east4 \\
  --project=pcc-prj-devops-prod \\
  --format="value(status)"
\`\`\`

### View Node Pools
\`\`\`bash
kubectl get nodes
\`\`\`

### Check Autopilot Events
\`\`\`bash
kubectl get events -A --sort-by='.lastTimestamp' | grep -i autopilot
\`\`\`

## Troubleshooting

### Cannot Connect via Connect Gateway

1. Verify IAM group membership:
   \`\`\`bash
   gcloud projects get-iam-policy pcc-prj-devops-prod \\
     --flatten="bindings[].members" \\
     --filter="bindings.members:user@pcconnect.ai"
   \`\`\`

2. Check Fleet membership status:
   \`\`\`bash
   gcloud container fleet memberships describe pcc-gke-devops-prod \\
     --project=pcc-prj-devops-prod
   \`\`\`

3. Regenerate kubeconfig:
   \`\`\`bash
   gcloud container fleet memberships get-credentials pcc-gke-devops-prod \\
     --project=pcc-prj-devops-prod
   \`\`\`

### Workload Identity Not Working

1. Verify annotation on K8s ServiceAccount:
   \`\`\`bash
   kubectl get sa WORKLOAD-sa -n NAMESPACE -o yaml | grep iam.gke.io
   \`\`\`

2. Check IAM binding:
   \`\`\`bash
   gcloud iam service-accounts get-iam-policy \\
     WORKLOAD-sa@pcc-prj-devops-prod.iam.gserviceaccount.com \\
     --project=pcc-prj-devops-prod
   \`\`\`

3. Test from pod:
   \`\`\`bash
   kubectl exec POD-NAME -n NAMESPACE -- gcloud auth list
   \`\`\`

## Differences from NonProd

| Feature | NonProd | Prod |
|---------|---------|------|
| Deletion Protection | False | **True** |
| Project | pcc-prj-devops-nonprod | pcc-prj-devops-prod |
| Network | pcc-vpc-nonprod | pcc-vpc-prod |
| Release Channel | STABLE | STABLE |
| Backup Policy | Standard | Enhanced (Phase 7) |

## Related Documentation

- Terraform Configuration: `infra/pcc-devops-infra/environments/prod/`
- Phase 4 Plan: `.claude/plans/phase-4-gke-devops-prod/`
- Connect Gateway Guide: `connect-gateway-access-guide.md`
- Workload Identity Guide: `workload-identity-setup-guide.md`

## Support

For cluster issues, contact DevOps team: gcp-devops@pcconnect.ai
```

**Step 2: Commit documentation**

```bash
cd ~/pcc/infra/pcc-devops-infra
git add docs/prod-cluster-guide.md
git commit -m "docs: add production cluster comprehensive guide for Phase 4"
```

---

## Task 2: Create Quick Reference Card

**Agent:** documentation-engineer

**Step 1: Create quick-reference.md**

File: `infra/pcc-devops-infra/docs/prod-quick-reference.md`

```markdown
# Production GKE Cluster - Quick Reference

## Access
\`\`\`bash
gcloud container fleet memberships get-credentials pcc-gke-devops-prod --project=pcc-prj-devops-prod
kubectl get nodes
\`\`\`

## Cluster Info
- **Name:** pcc-gke-devops-prod
- **Project:** pcc-prj-devops-prod
- **Region:** us-east4
- **Type:** Autopilot
- **WI Pool:** pcc-prj-devops-prod.svc.id.goog

## Key Commands
\`\`\`bash
# Status
kubectl get nodes
kubectl get pods -A

# Logs
kubectl logs -f POD_NAME -n NAMESPACE

# Describe
kubectl describe pod POD_NAME -n NAMESPACE
\`\`\`

## Terraform
\`\`\`bash
cd ~/pcc/infra/pcc-devops-infra/environments/prod
terraform plan
terraform apply
\`\`\`
```

**Step 2: Commit and verify documentation**

```bash
git add docs/prod-quick-reference.md
git commit -m "docs: add prod cluster quick reference card"
git push origin main
```

---

## Chunk Complete Checklist

- [ ] Comprehensive cluster guide created
- [ ] Quick reference card created
- [ ] Access procedures documented
- [ ] Workload Identity setup documented
- [ ] Troubleshooting guide included
- [ ] All documentation committed to git
- [ ] Ready for chunk 12 (status files)
