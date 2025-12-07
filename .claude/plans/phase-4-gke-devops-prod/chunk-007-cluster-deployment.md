# Chunk 7: Deploy Production GKE Cluster

**Status:** pending
**Dependencies:** chunk-006-terraform-validation
**Complexity:** medium
**Estimated Time:** 25-30 minutes
**Tasks:** 2
**Phase:** Validation & Deployment
**Story:** STORY-4.4
**Jira:** PCC-278

---

## Task 1: Execute Terraform Apply

**Agent:** terraform-specialist

**Step 1: Apply terraform plan**

```bash
cd ~/pcc/infra/pcc-devops-infra/environments/prod
terraform apply tfplan
```

Expected:
- Cluster creation starts (will take 15-20 minutes)
- IAM bindings applied
- Hub membership configured

**Step 2: Monitor deployment progress**

While terraform runs, monitor in another terminal:

```bash
# Watch cluster creation
gcloud container clusters list --project=pcc-prj-devops-prod --format="table(name,status,location)"
```

Expected initial status: `PROVISIONING` → `RUNNING`

**Step 3: Wait for completion**

Terraform apply will wait for cluster to be ready. Expected total time: 15-20 minutes

**Step 4: Verify apply success**

Expected output:
```
Apply complete! Resources: 4 added, 0 changed, 0 destroyed.

Outputs:

cluster_id = "projects/pcc-prj-devops-prod/locations/us-east4/clusters/pcc-gke-devops-prod"
cluster_name = "pcc-gke-devops-prod"
...
```

---

## Task 2: Validate Deployment and Capture Outputs

**Agent:** terraform-specialist

**Step 1: Capture terraform outputs**

```bash
terraform output > terraform-outputs.txt
```

**Step 2: Verify cluster in GCP Console**

```bash
gcloud container clusters describe pcc-gke-devops-prod \
  --region=us-east4 \
  --project=pcc-prj-devops-prod \
  --format="table(name,status,location,autopilot.enabled,releaseChannel.channel)"
```

Expected:
```
NAME                      STATUS   LOCATION  AUTOPILOT  CHANNEL
pcc-gke-devops-prod       RUNNING  us-east4  True       STABLE
```

**Step 3: Check IAM propagation**

```bash
# Verify IAM bindings applied (may take 60-90 seconds)
gcloud projects get-iam-policy pcc-prj-devops-prod \
  --flatten="bindings[].members" \
  --filter="bindings.role:roles/gkehub.gatewayAdmin" \
  --format="table(bindings.role,bindings.members)"
```

Expected: `group:gcp-devops@pcconnect.ai` listed

**Step 4: Document deployment**

Create `deployment-log.md`:
- Deployment date/time
- Terraform version used
- Cluster creation duration
- Any warnings or issues encountered
- Terraform outputs captured

---

## Chunk Complete Checklist

- [ ] Terraform apply completed successfully
- [ ] Cluster status: RUNNING
- [ ] Autopilot mode confirmed enabled
- [ ] Release channel confirmed: STABLE
- [ ] IAM bindings applied
- [ ] Terraform outputs captured
- [ ] Deployment documented
- [ ] Ready for chunk 8 (cluster validation)
