# Chunk 21: Configure 14-Day Backup Schedule

**Status:** pending
**Dependencies:** chunk-020-velero-installation
**Complexity:** simple
**Estimated Time:** 15 minutes
**Tasks:** 2
**Phase:** Production Operations
**Story:** STORY-709
**Jira:** PCC-301

---

## Task 1: Create Daily Backup Schedule

**Agent:** sre-engineer

**Step 1: Create backup schedule for argocd namespace**

```bash
velero schedule create argocd-daily \
  --schedule="0 2 * * *" \
  --ttl=336h \
  --include-namespaces=argocd \
  --include-cluster-resources=true \
  --default-volumes-to-fs-backup=false \
  --snapshot-volumes=false
```

Expected: "Schedule 'argocd-daily' created successfully"

**TTL Explanation**: 336h = 14 days (14 * 24 hours)
**Schedule**: Daily at 2 AM UTC

**Step 2: Verify schedule created**

```bash
velero schedule get argocd-daily
```

Expected output:
```
NAME           STATUS    CREATED                         SCHEDULE    BACKUP TTL   LAST BACKUP   SELECTOR
argocd-daily   Enabled   <timestamp>                    0 2 * * *   336h0m0s     n/a           <none>
```

---

## Task 2: Trigger First Backup and Validate

**Agent:** sre-engineer

**Step 1: Create immediate backup (don't wait for scheduled time)**

```bash
velero backup create argocd-manual-$(date +%Y%m%d-%H%M%S) \
  --from-schedule=argocd-daily
```

Expected: "Backup request 'argocd-manual-YYYYMMDD-HHMMSS' submitted successfully"

**Step 2: Monitor backup progress**

```bash
# Watch backup status
velero backup get --selector velero.io/schedule-name=argocd-daily

# Wait for Completed status (may take 2-5 minutes)
```

Expected: `Phase: Completed`

**Step 3: Verify backup in GCS**

```bash
gsutil ls gs://pcc-argocd-prod-backups/backups/
```

Expected: Backup directory `argocd-manual-YYYYMMDD-HHMMSS/`

**Step 4: Get backup details**

```bash
BACKUP_NAME=$(velero backup get --selector velero.io/schedule-name=argocd-daily -o jsonpath='{.items[0].metadata.name}')

velero backup describe $BACKUP_NAME
```

Expected output includes:
- Phase: Completed
- Total items: XX (ArgoCD resources)
- Namespaces: argocd
- Included resources: All

**Step 5: Document backup schedule**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra
cat <<EOF >> environments/prod/docs/deployment-notes.md

## Backup Configuration
- Tool: Velero 5.0.0
- Schedule: Daily at 2 AM UTC (argocd-daily)
- Retention: 14 days (336 hours)
- Storage: GCS bucket (pcc-argocd-prod-backups)
- Namespace: argocd
- First backup: $BACKUP_NAME ($(date))
- Status: Completed ✓
EOF

git add environments/prod/docs/deployment-notes.md
git commit -m "feat(phase-7): configure 14-day backup schedule for argocd namespace"
```

---

## Chunk Complete Checklist

- [ ] Daily backup schedule created (argocd-daily)
- [ ] Schedule configured: 2 AM UTC, 14-day retention
- [ ] First manual backup completed successfully
- [ ] Backup verified in GCS bucket
- [ ] Backup includes all argocd namespace resources
- [ ] Backup schedule documented
- [ ] Ready for chunk 22 (backup testing)
