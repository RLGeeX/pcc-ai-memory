# Chunk 22: Test Backup and Restore

**Status:** pending
**Dependencies:** chunk-021-backup-schedule
**Complexity:** medium
**Estimated Time:** 30 minutes
**Tasks:** 3
**Phase:** Production Operations
**Story:** STORY-709
**Jira:** PCC-302

---

## Task 1: Create Test Namespace for Restore

**Agent:** sre-engineer

**Step 1: Create argocd-restore namespace**

```bash
kubectl create namespace argocd-restore
```

**Step 2: Get latest backup name**

```bash
LATEST_BACKUP=$(velero backup get --selector velero.io/schedule-name=argocd-daily \
  -o jsonpath='{.items[0].metadata.name}')

echo "Testing restore from backup: $LATEST_BACKUP"
```

---

## Task 2: Perform Test Restore

**Agent:** sre-engineer

**Step 1: Create restore to test namespace**

```bash
velero restore create argocd-test-restore-$(date +%Y%m%d-%H%M%S) \
  --from-backup=$LATEST_BACKUP \
  --namespace-mappings argocd:argocd-restore \
  --restore-volumes=false
```

Expected: "Restore request 'argocd-test-restore-YYYYMMDD-HHMMSS' submitted successfully"

**Step 2: Monitor restore progress**

```bash
RESTORE_NAME=$(velero restore get -o jsonpath='{.items[0].metadata.name}')

# Watch restore status (may take 3-5 minutes)
velero restore describe $RESTORE_NAME --details
```

Expected:
- Phase: Completed
- Restored items: XX (ArgoCD ConfigMaps, Secrets, Applications, etc.)
- Warnings: 0 (or minimal, expected warnings about existing resources)

**Step 3: Verify restored resources**

```bash
# Check restored resources in argocd-restore namespace
kubectl get all,configmaps,secrets,applications -n argocd-restore

# Verify ArgoCD Applications restored
kubectl get applications -n argocd-restore
```

Expected: ArgoCD resources (ConfigMaps, Secrets, Applications) exist in argocd-restore

---

## Task 3: Validate and Cleanup Test Restore

**Agent:** sre-engineer

**Step 1: Compare original and restored resources**

```bash
# Count resources in original namespace
ORIGINAL_COUNT=$(kubectl get all,configmaps,secrets -n argocd --no-headers | wc -l)

# Count resources in restored namespace
RESTORED_COUNT=$(kubectl get all,configmaps,secrets -n argocd-restore --no-headers | wc -l)

echo "Original resources: $ORIGINAL_COUNT"
echo "Restored resources: $RESTORED_COUNT"
```

Expected: Counts should be similar (restored may be slightly less due to runtime resources)

**Step 2: Time the restore process**

```bash
velero restore describe $RESTORE_NAME | grep "Started:"
velero restore describe $RESTORE_NAME | grep "Completed:"
```

Calculate duration (should be < 30 minutes)

**Step 3: Cleanup test namespace**

```bash
kubectl delete namespace argocd-restore
```

**Step 4: Document restore test results**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra
cat <<EOF >> environments/prod/docs/deployment-notes.md

## Backup Restore Testing
- Test Date: $(date)
- Backup Used: $LATEST_BACKUP
- Restore Name: $RESTORE_NAME
- Restore Duration: [calculated from timestamps]
- Original Resources: $ORIGINAL_COUNT
- Restored Resources: $RESTORED_COUNT
- Status: Completed ✓
- RTO Achieved: < 30 minutes ✓

### Restore Verification
- ConfigMaps restored: ✓
- Secrets restored: ✓
- Applications restored: ✓
- Deployments restored: ✓
- Services restored: ✓

### Next Steps
- Monthly restore testing recommended
- DR runbook to be created in chunk 23
EOF

git add environments/prod/docs/deployment-notes.md
git commit -m "test(phase-7): validate backup restore to argocd-restore namespace"
```

---

## Chunk Complete Checklist

- [ ] Test namespace created (argocd-restore)
- [ ] Restore executed from latest backup
- [ ] All ArgoCD resources restored successfully
- [ ] Resource counts compared (original vs restored)
- [ ] Restore duration < 30 minutes (RTO met)
- [ ] Test namespace cleaned up
- [ ] Restore test results documented
- [ ] Ready for chunk 23 (DR runbook)
