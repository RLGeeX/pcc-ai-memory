# Chunk 5: Deploy Production Infrastructure

**Status:** pending
**Dependencies:** chunk-004-main-terraform-config
**Complexity:** medium
**Estimated Time:** 25 minutes
**Tasks:** 3
**Phase:** Infrastructure Foundation
**Story:** STORY-702
**Jira:** PCC-285

---

## Task 1: Initialize Terraform

**Agent:** terraform-specialist

**Step 1: Initialize backend**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra/environments/prod
terraform init
```

Expected: "Terraform has been successfully initialized!"

**Step 2: Validate configuration**

```bash
terraform validate
```

Expected: "Success! The configuration is valid."

---

## Task 2: Create Terraform Plan

**Agent:** terraform-specialist

**Step 1: Run terraform plan**

```bash
terraform plan -out=tfplan
```

**Step 2: Review plan output**

Expected resources:
- 4 google_service_account (controller, repo, server, backup)
- 4 google_service_account_iam_binding (workload identity)
- 1 google_storage_bucket (pcc-argocd-prod-backups)
- 1 google_compute_managed_ssl_certificate (argocd-prod-tls)

Total: ~10 resources to create

**Step 3: Verify critical settings**

```bash
# Verify backup bucket retention
terraform show tfplan | grep -A5 "lifecycle_rule"
# Expected: age = 14

# Verify force_destroy = false
terraform show tfplan | grep force_destroy
# Expected: force_destroy = false
```

---

## Task 3: Apply Terraform Configuration

**Agent:** terraform-specialist

**Step 1: Apply plan**

```bash
terraform apply tfplan
```

Expected: "Apply complete! Resources: 10 added, 0 changed, 0 destroyed."

**Step 2: Verify outputs**

```bash
terraform output
```

Expected outputs:
```
controller_sa_email = "argocd-application-controller@pcc-prj-devops-prod.iam.gserviceaccount.com"
repo_sa_email = "argocd-repo-server@pcc-prj-devops-prod.iam.gserviceaccount.com"
server_sa_email = "argocd-server@pcc-prj-devops-prod.iam.gserviceaccount.com"
backup_sa_email = "argocd-backup@pcc-prj-devops-prod.iam.gserviceaccount.com"
backup_bucket = "pcc-argocd-prod-backups"
ssl_cert_name = "argocd-prod-tls"
```

**Step 3: Commit terraform state reference**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra
echo "# Terraform State: gs://pcc-tf-state-prod/argocd-infra/prod" > environments/prod/README.md
git add environments/prod/README.md
git commit -m "feat(phase-7): deploy prod infrastructure - 4 SAs, WI, backup bucket, SSL cert"
```

---

## Chunk Complete Checklist

- [ ] Terraform initialized
- [ ] Plan created and reviewed
- [ ] 10 resources deployed successfully
- [ ] Outputs verified (4 SA emails, bucket, cert)
- [ ] 14-day retention confirmed on backup bucket
- [ ] Infrastructure deployed
- [ ] Ready for chunk 6 (HA Helm values)
