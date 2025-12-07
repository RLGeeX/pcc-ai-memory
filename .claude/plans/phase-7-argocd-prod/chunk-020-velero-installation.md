# Chunk 20: Install Velero for Backups

**Status:** pending
**Dependencies:** chunk-019-monitoring-setup
**Complexity:** medium
**Estimated Time:** 20 minutes
**Tasks:** 3
**Phase:** Production Operations
**Story:** STORY-709
**Jira:** PCC-300

---

## Task 1: Configure Velero with Workload Identity

**Agent:** sre-engineer

**Step 1: Create velero namespace**

```bash
kubectl create namespace velero
```

**Step 2: Annotate Velero ServiceAccount for Workload Identity**

Note: The GCP SA `argocd-backup` was already created in chunk 5 with WI binding to `velero/velero`

```bash
kubectl create serviceaccount velero -n velero
kubectl annotate serviceaccount velero -n velero \
  iam.gke.io/gcp-service-account=argocd-backup@pcc-prj-devops-prod.iam.gserviceaccount.com
```

**Step 3: Verify Workload Identity binding**

```bash
gcloud iam service-accounts get-iam-policy \
  argocd-backup@pcc-prj-devops-prod.iam.gserviceaccount.com \
  --project=pcc-prj-devops-prod
```

Expected: `serviceAccount:pcc-prj-devops-prod.svc.id.goog[velero/velero]` member with `roles/iam.workloadIdentityUser`

---

## Task 2: Install Velero Helm Chart

**Agent:** sre-engineer

**Step 1: Add Velero Helm repo**

```bash
helm repo add vmware-tanzu https://vmware-tanzu.github.io/helm-charts
helm repo update
```

**Step 2: Create Velero values file**

File: `infra/pcc-argocd-prod-infra/environments/prod/helm/velero-values.yaml`

```yaml
configuration:
  backupStorageLocation:
  - name: default
    provider: gcp
    bucket: pcc-argocd-prod-backups
    config:
      serviceAccount: argocd-backup@pcc-prj-devops-prod.iam.gserviceaccount.com

  volumeSnapshotLocation:
  - name: default
    provider: gcp
    config:
      project: pcc-prj-devops-prod
      snapshotLocation: us-east4

initContainers:
- name: velero-plugin-for-gcp
  image: velero/velero-plugin-for-gcp:v1.10.0
  volumeMounts:
  - mountPath: /target
    name: plugins

serviceAccount:
  server:
    create: false
    name: velero
    annotations:
      iam.gke.io/gcp-service-account: argocd-backup@pcc-prj-devops-prod.iam.gserviceaccount.com

resources:
  requests:
    cpu: "500m"
    memory: "512Mi"
  limits:
    cpu: "500m"
    memory: "512Mi"

deployNodeAgent: false  # Autopilot doesn't need node agent
```

**Step 3: Install Velero**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra/environments/prod

helm install velero vmware-tanzu/velero \
  --namespace velero \
  --version 5.0.0 \
  -f helm/velero-values.yaml \
  --timeout 10m
```

Expected: "STATUS: deployed"

---

## Task 3: Verify Velero Installation

**Agent:** sre-engineer

**Step 1: Wait for Velero pod to be ready**

```bash
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=velero \
  -n velero --timeout=300s
```

**Step 2: Check backup storage location**

```bash
kubectl get backupstoragelocation -n velero
```

Expected: `default` with STATUS `Available`

**Step 3: Verify GCS bucket access**

```bash
# Exec into Velero pod and test GCS access
VELERO_POD=$(kubectl get pods -n velero -l app.kubernetes.io/name=velero -o jsonpath='{.items[0].metadata.name}')

kubectl exec $VELERO_POD -n velero -- velero backup-location get
```

Expected: Shows `default` location as `Available`

**Step 4: Commit Velero configuration**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra
git add environments/prod/helm/velero-values.yaml
git commit -m "feat(phase-7): install Velero 5.0.0 for 14-day backup retention"
```

---

## Chunk Complete Checklist

- [ ] velero namespace created
- [ ] Velero ServiceAccount annotated with Workload Identity
- [ ] Velero Helm chart installed (v5.0.0)
- [ ] Velero pod running
- [ ] Backup storage location Available (GCS bucket accessible)
- [ ] Velero values committed
- [ ] Ready for chunk 21 (backup schedule)
