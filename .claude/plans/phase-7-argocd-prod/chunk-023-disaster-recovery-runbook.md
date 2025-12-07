# Chunk 23: Create Disaster Recovery Runbook

**Status:** pending
**Dependencies:** chunk-022-backup-testing
**Complexity:** simple
**Estimated Time:** 20 minutes
**Tasks:** 2
**Phase:** Production Operations
**Story:** STORY-710
**Jira:** PCC-303

---

## Task 1: Create Disaster Recovery Runbook

**Agent:** documentation-engineer

**Step 1: Create DR runbook**

File: `infra/pcc-argocd-prod-infra/environments/prod/docs/disaster-recovery-runbook.md`

```markdown
# ArgoCD Production Disaster Recovery Runbook

## Overview

**RTO (Recovery Time Objective)**: 1 hour
**RPO (Recovery Point Objective)**: 24 hours (daily backups)

This runbook covers disaster recovery procedures for ArgoCD production cluster.

---

## Disaster Scenarios

### Scenario 1: Complete Cluster Failure

**Symptoms:**
- Cluster unreachable
- GCP Console shows cluster in ERROR state
- kubectl commands timeout

**Recovery Steps:**

1. **Verify Cluster Status**
   ```bash
   gcloud container clusters describe pcc-gke-devops-prod \
     --region=us-east4 \
     --project=pcc-prj-devops-prod
   ```

2. **If cluster destroyed, recreate from Terraform**
   ```bash
   cd ~/pcc/infra/pcc-devops-infra/environments/prod
   terraform plan
   terraform apply
   ```
   Expected: ~15-20 minutes for cluster creation

3. **Reinstall ArgoCD**
   ```bash
   cd ~/pcc/infra/pcc-argocd-prod-infra/environments/prod
   ./scripts/preflight-prod.sh
   helm install argocd argo/argo-cd --version 7.7.11 \
     -f helm/values-prod-autopilot.yaml -n argocd
   ```
   Expected: ~5-10 minutes

4. **Restore from Latest Backup**
   ```bash
   # Get latest backup
   LATEST=$(velero backup get --selector velero.io/schedule-name=argocd-daily \
     -o jsonpath='{.items[0].metadata.name}')

   # Restore to argocd namespace
   velero restore create argocd-dr-$(date +%Y%m%d-%H%M%S) \
     --from-backup=$LATEST
   ```
   Expected: ~5-10 minutes

5. **Verify Applications**
   ```bash
   kubectl get applications -n argocd
   argocd app list
   ```

6. **Sync Applications**
   ```bash
   argocd app sync --all
   ```

**Total Time**: 30-45 minutes

---

### Scenario 2: ArgoCD Namespace Deleted

**Symptoms:**
- ArgoCD UI inaccessible
- kubectl get ns argocd returns "not found"
- Applications still running but not managed

**Recovery Steps:**

1. **Verify Namespace Missing**
   ```bash
   kubectl get namespace argocd
   ```

2. **Restore from Latest Backup**
   ```bash
   LATEST=$(velero backup get --selector velero.io/schedule-name=argocd-daily \
     -o jsonpath='{.items[0].metadata.name}')

   velero restore create argocd-namespace-restore-$(date +%Y%m%d-%H%M%S) \
     --from-backup=$LATEST
   ```

3. **Verify Restoration**
   ```bash
   kubectl get pods -n argocd
   kubectl get applications -n argocd
   ```

4. **Access ArgoCD UI**
   ```bash
   open https://argocd-prod.portcon.com
   ```

**Total Time**: 10-15 minutes

---

### Scenario 3: Data Corruption (Applications Misconfigured)

**Symptoms:**
- Applications showing incorrect configurations
- Sync status showing unexpected changes
- Settings modified without authorization

**Recovery Steps:**

1. **List Available Backups**
   ```bash
   velero backup get --selector velero.io/schedule-name=argocd-daily
   ```

2. **Identify Pre-Corruption Backup**
   Select backup from before corruption occurred

3. **Restore Applications Only (Preserve Current Infrastructure)**
   ```bash
   velero restore create argocd-selective-restore-$(date +%Y%m%d-%H%M%S) \
     --from-backup=argocd-daily-YYYYMMDD \
     --include-resources=applications.argoproj.io,appprojects.argoproj.io
   ```

4. **Verify Applications Restored**
   ```bash
   argocd app list
   argocd app get <app-name>
   ```

5. **Resync if Needed**
   ```bash
   argocd app sync <app-name>
   ```

**Total Time**: 5-10 minutes

---

## Backup Information

**Backup Schedule**: Daily at 2 AM UTC
**Retention**: 14 days
**Storage**: gs://pcc-argocd-prod-backups
**Service Account**: argocd-backup@pcc-prj-devops-prod.iam.gserviceaccount.com

### List All Backups

```bash
velero backup get
```

### View Backup Details

```bash
velero backup describe <backup-name> --details
```

### Download Backup to Local (For Forensics)

```bash
velero backup download <backup-name>
```

---

## Contacts

**Primary On-Call**: DevOps Team (via PagerDuty)
**Slack Channel**: #pcc-devops-prod
**Escalation**: CTO, VP Engineering

**Response Times**:
- Critical (cluster down): 15 minutes
- High (namespace deleted): 30 minutes
- Medium (data corruption): 1 hour

---

## Testing Schedule

**Monthly**: Restore test to argocd-restore namespace (chunk 22 procedure)
**Quarterly**: Full DR drill (cluster recreation + restore)

**Last Test**: [To be filled after quarterly test]
**Next Test**: [Schedule quarterly]

---

## Post-Recovery Checklist

After completing disaster recovery:

- [ ] All applications synced and healthy
- [ ] ArgoCD UI accessible
- [ ] OAuth/RBAC working
- [ ] Monitoring restored (Prometheus, Grafana)
- [ ] Incident report created
- [ ] Root cause documented
- [ ] Prevention measures implemented
- [ ] DR runbook updated if needed
```

---

## Task 2: Create Quick Reference Card

**Agent:** documentation-engineer

**Step 1: Create quick DR reference**

File: `infra/pcc-argocd-prod-infra/environments/prod/docs/dr-quick-reference.md`

```markdown
# ArgoCD DR Quick Reference

## Immediate Actions

1. **Check Cluster Health**
   ```bash
   kubectl get nodes
   gcloud container clusters describe pcc-gke-devops-prod --region=us-east4 --project=pcc-prj-devops-prod
   ```

2. **Get Latest Backup**
   ```bash
   LATEST=$(velero backup get --selector velero.io/schedule-name=argocd-daily -o jsonpath='{.items[0].metadata.name}')
   echo $LATEST
   ```

3. **Restore from Backup**
   ```bash
   velero restore create argocd-dr-$(date +%Y%m%d-%H%M%S) --from-backup=$LATEST
   ```

4. **Monitor Restore**
   ```bash
   velero restore describe argocd-dr-YYYYMMDD-HHMMSS --details
   ```

5. **Verify Applications**
   ```bash
   kubectl get applications -n argocd
   argocd app list
   ```

## Key Information

- **RTO**: 1 hour
- **RPO**: 24 hours
- **Backup Storage**: gs://pcc-argocd-prod-backups
- **Runbook**: `docs/disaster-recovery-runbook.md`
- **Contacts**: #pcc-devops-prod, PagerDuty
```

**Step 2: Commit DR documentation**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra
git add environments/prod/docs/disaster-recovery-runbook.md
git add environments/prod/docs/dr-quick-reference.md
git commit -m "docs(phase-7): create disaster recovery runbook with RTO < 1 hour"
git push origin main
```

---

## Chunk Complete Checklist

- [ ] Disaster recovery runbook created
- [ ] 3 disaster scenarios documented (cluster failure, namespace deletion, data corruption)
- [ ] Recovery procedures with time estimates
- [ ] Backup information documented
- [ ] Contacts and escalation paths defined
- [ ] Testing schedule defined (monthly, quarterly)
- [ ] Quick reference card created
- [ ] DR documentation committed
- [ ] Ready for chunk 24 (status updates)
