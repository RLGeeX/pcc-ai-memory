# Phase 6.25: Install Velero for Backup/Restore

**Tool**: [WARP] Partner Execution
**Estimated Duration**: 25 minutes

## Purpose

Install Velero on GKE Autopilot for Kubernetes backup/restore, configured with GCS bucket backend, 3-day retention for nonprod, and exclude velero.io CRDs from ArgoCD management to prevent pruning.

## Prerequisites

- Phase 6.24 completed (hello-world deployed)
- Phase 6.7 completed (velero GCP SA + WI binding created)
- Phase 6.4 completed (GCS bucket `pcc-argocd-backups-nonprod` created)
- Velero CLI installed: https://velero.io/docs/main/basic-install/

## Detailed Steps

### Step 1: Install Velero CLI

```bash
# Check if Velero CLI is installed
velero version --client-only

# If not installed, install via package manager
# macOS:
brew install velero

# Linux:
wget https://github.com/vmware-tanzu/velero/releases/download/v1.14.0/velero-v1.14.0-linux-amd64.tar.gz
tar -xvf velero-v1.14.0-linux-amd64.tar.gz
sudo mv velero-v1.14.0-linux-amd64/velero /usr/local/bin/
```

**Expected**: `Client: Version: v1.14.0` (or later)

### Step 2: Verify GCS Bucket Exists

```bash
gsutil ls gs://pcc-argocd-backups-nonprod
```

**Expected**: Bucket exists (created in Phase 6.4)

**HALT if**: Bucket does not exist

### Step 3: Install Velero via CLI

```bash
velero install \
  --provider gcp \
  --plugins velero/velero-plugin-for-gcp:v1.10.0 \
  --bucket pcc-argocd-backups-nonprod \
  --secret-file /dev/null \
  --use-volume-snapshots \
  --sa-annotations iam.gke.io/gcp-service-account=velero@pcc-prj-devops-nonprod.iam.gserviceaccount.com \
  --namespace velero \
  --wait
```

**Key Flags**:
- `--secret-file /dev/null`: No service account key (using Workload Identity)
- `--use-volume-snapshots`: Enable CSI volume snapshots (GKE Autopilot compatible)
- `--sa-annotations`: Workload Identity annotation

**Note**: GKE Autopilot does not support `--use-node-agent` (requires privileged containers). Using CSI snapshots instead.

**Expected Output**:
```
CustomResourceDefinition/backups.velero.io created
CustomResourceDefinition/backupstoragelocations.velero.io created
...
Deployment/velero created
Velero is installed! ⛵
```

### Step 4: Verify Velero Deployment

```bash
kubectl get deployments -n velero
```

**Expected Output**:
```
NAME     READY   UP-TO-DATE   AVAILABLE   AGE
velero   1/1     1            1           2m
```

### Step 5: Verify VolumeSnapshotClass (CSI Snapshots)

```bash
kubectl get volumesnapshotclass
```

**Expected Output**:
```
NAME                     DRIVER               DELETIONPOLICY   AGE
csi-gce-pd-snapshot-class   pd.csi.storage.gke.io   Delete           Xm
```

**Note**: GKE Autopilot provides this VolumeSnapshotClass automatically for CSI snapshots

### Step 6: Verify Workload Identity Binding

```bash
kubectl exec -n velero deployment/velero -- \
  curl -sS -H "Metadata-Flavor: Google" \
  http://metadata.google.internal/computeMetadata/v1/instance/service-accounts/default/email
```

**Expected**: `velero@pcc-prj-devops-nonprod.iam.gserviceaccount.com`

**HALT if**: Wrong service account or 404 error

### Step 7: Configure Backup Storage Location

Verify BackupStorageLocation:
```bash
kubectl get backupstoragelocation -n velero
```

**Expected Output**:
```
NAME      PHASE       LAST VALIDATED   AGE
default   Available   10s              2m
```

**HALT if**: PHASE shows "Unavailable"

### Step 8: Set Backup Retention (3 Days for NonProd)

Create backup schedule with 3-day retention:
```bash
velero schedule create daily-backup \
  --schedule="0 2 * * *" \
  --ttl 72h \
  --include-namespaces argocd,hello-world \
  --exclude-resources='events,events.events.k8s.io'
```

**Expected**:
```
Schedule "daily-backup" created successfully.
```

**Backup Configuration**:
- **Schedule**: 2 AM daily (cron: `0 2 * * *`)
- **TTL**: 72 hours (3 days)
- **Namespaces**: argocd, hello-world
- **Excludes**: Events (noisy, not needed)
- **Volume Method**: CSI snapshots (GKE Autopilot compatible)

### Step 9: Verify Schedule Created

```bash
velero schedule get
```

**Expected Output**:
```
NAME           STATUS    CREATED                         SCHEDULE    BACKUP TTL   LAST BACKUP   SELECTOR
daily-backup   Enabled   2024-10-26 14:00:00 +0000 UTC   0 2 * * *   72h0m0s      n/a           <none>
```

### Step 10: Create Manual Test Backup

```bash
velero backup create test-backup \
  --include-namespaces hello-world \
  --wait
```

**Expected Output**:
```
Backup request "test-backup" submitted successfully.
Waiting for backup to complete. You may safely press ctrl-c to stop waiting - your backup will continue in the background.
...
Backup completed with status: Completed
```

### Step 11: Verify Backup Completed

```bash
velero backup describe test-backup --details
```

**Expected**:
- **Phase**: Completed
- **Total items to be backed up**: ~5 (namespace, deployment, replicaset, pods, service)
- **Items backed up**: ~5
- **Errors**: 0

### Step 12: List Backups in GCS

```bash
gsutil ls -r gs://pcc-argocd-backups-nonprod/backups/
```

**Expected**: Shows `test-backup/` directory with backup metadata

### Step 13: Configure ArgoCD to Exclude Velero CRDs

ArgoCD should NOT manage Velero CRDs to prevent pruning.

**IMPORTANT**: These changes should be made in Git repo, NOT via kubectl edit.

**Option A**: Add exclusion to root app (recommended)

1. Edit `apps/argocd-nonprod-root.yaml` in your Git repo
2. Add to `spec`:
   ```yaml
   spec:
     # Existing fields...

     # Ignore velero.io CRDs (managed by Velero, not ArgoCD)
     ignoreDifferences:
       - group: velero.io
         kind: "*"
   ```
3. Git commit and push:
   ```bash
   git add apps/argocd-nonprod-root.yaml
   git commit -m "feat(argocd): exclude Velero CRDs from management"
   git push origin main
   ```
4. ArgoCD will auto-sync the change (or manually sync via UI)

**Option B**: Add resource exclusion to ArgoCD ConfigMap

1. Velero exclusion was already configured in Phase 6.5 (`values-autopilot.yaml` line 71-78)
2. If not present, update Helm values and re-apply via Terraform/Helm

**No restart needed**: ArgoCD will detect Git changes automatically

### Step 14: Verify Velero Logs

```bash
kubectl logs -n velero deployment/velero --tail=50
```

**Expected**: No errors, shows backup storage location validation successful

## Success Criteria

- ✅ Velero CLI installed
- ✅ Velero deployment running (1/1 READY)
- ✅ VolumeSnapshotClass available (CSI snapshots)
- ✅ Workload Identity validated
- ✅ BackupStorageLocation shows "Available"
- ✅ Daily backup schedule created with 3-day retention
- ✅ Manual test backup completed successfully
- ✅ Backup files exist in GCS bucket
- ✅ ArgoCD configured to exclude velero.io resources
- ✅ No errors in Velero logs

## HALT Conditions

**HALT if**:
- Velero installation fails
- Deployment not ready after 5 minutes
- Workload Identity not working
- BackupStorageLocation shows "Unavailable"
- Test backup fails
- Backup files not in GCS bucket

**Resolution**:
- Check Velero deployment logs: `kubectl logs -n velero deployment/velero`
- Verify GCS bucket permissions:
  ```bash
  gcloud iam service-accounts get-iam-policy velero@pcc-prj-devops-nonprod.iam.gserviceaccount.com
  ```
- Check Workload Identity binding:
  ```bash
  gcloud iam service-accounts get-iam-policy velero@pcc-prj-devops-nonprod.iam.gserviceaccount.com
  ```
- Describe BackupStorageLocation:
  ```bash
  kubectl describe backupstoragelocation default -n velero
  ```
- Test GCS access manually:
  ```bash
  kubectl exec -n velero deployment/velero -- gsutil ls gs://pcc-argocd-backups-nonprod
  ```
- Uninstall and reinstall if needed: `velero uninstall && <repeat Step 3>`

## Next Phase

Proceed to **Phase 6.26**: Configure Monitoring

## Notes

- **Velero version**: v1.14.0 (latest stable as of Oct 2024)
- **Plugin version**: v1.10.0 for GCP
- **Retention**: 3 days for nonprod (cost optimization)
- **Production**: Increase retention to 30 days or longer
- **Volume Snapshots**: Using CSI snapshots (GKE Autopilot compatible, no privileged containers)
- **Node-Agent**: NOT used (requires privileged containers, incompatible with Autopilot)
- **Schedule**: 2 AM daily (low traffic time)
- **Namespaces**: argocd and hello-world (add more as needed)
- **Events**: Excluded from backups (noisy, not needed)
- **ArgoCD Exclusion**: Prevents ArgoCD from pruning Velero CRDs
- Velero uses GCS for backup storage (regional redundancy)
- Backup metadata stored in GCS: `gs://bucket/backups/<backup-name>/`
- Restore command: `velero restore create --from-backup <backup-name>`
- Velero can backup/restore across clusters (disaster recovery)
- Workload Identity authentication (no service account keys)
- IAM role: `roles/storage.objectAdmin` on GCS bucket (Phase 6.4)
- Velero watches K8s API for resources to backup
- Daily schedule creates backups at 2 AM UTC
- TTL of 72h means backups auto-delete after 3 days
- GCS lifecycle policy in Phase 6.4 provides additional safety net
- Manual backups can be created anytime: `velero backup create <name>`
