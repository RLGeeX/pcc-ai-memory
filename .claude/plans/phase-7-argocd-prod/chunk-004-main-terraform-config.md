# Chunk 4: Create Main Terraform Configuration

**Status:** pending
**Dependencies:** chunk-003-directory-structure
**Complexity:** medium
**Estimated Time:** 20 minutes
**Tasks:** 3
**Phase:** Infrastructure Foundation
**Story:** STORY-702
**Jira:** PCC-284

---

## Task 1: Create Service Accounts

**Agent:** terraform-specialist

**Step 1: Create main.tf with 4 service accounts**

File: `environments/prod/main.tf`

```hcl
# ArgoCD Application Controller SA
module "argocd_controller_sa" {
  source = "../../modules/service-account"

  project_id   = var.project_id
  account_id   = "argocd-application-controller"
  display_name = "ArgoCD Application Controller (Prod)"
  description  = "Service account for ArgoCD application controller in production"
}

# ArgoCD Repo Server SA
module "argocd_repo_sa" {
  source = "../../modules/service-account"

  project_id   = var.project_id
  account_id   = "argocd-repo-server"
  display_name = "ArgoCD Repo Server (Prod)"
  description  = "Service account for ArgoCD repo server in production"
}

# ArgoCD API Server SA
module "argocd_server_sa" {
  source = "../../modules/service-account"

  project_id   = var.project_id
  account_id   = "argocd-server"
  display_name = "ArgoCD API Server (Prod)"
  description  = "Service account for ArgoCD API server in production"
}

# ArgoCD Backup SA
module "argocd_backup_sa" {
  source = "../../modules/service-account"

  project_id   = var.project_id
  account_id   = "argocd-backup"
  display_name = "ArgoCD Backup (Prod)"
  description  = "Service account for ArgoCD backups via Velero in production"
}
```

---

## Task 2: Create Workload Identity Bindings

**Agent:** terraform-specialist

**Step 1: Add workload identity bindings to main.tf**

```hcl
# Workload Identity binding for Application Controller
module "argocd_controller_wi" {
  source = "../../modules/workload-identity"

  project_id         = var.project_id
  gcp_sa_email       = module.argocd_controller_sa.email
  k8s_namespace      = "argocd"
  k8s_sa_name        = "argocd-application-controller"
}

# Workload Identity binding for Repo Server
module "argocd_repo_wi" {
  source = "../../modules/workload-identity"

  project_id         = var.project_id
  gcp_sa_email       = module.argocd_repo_sa.email
  k8s_namespace      = "argocd"
  k8s_sa_name        = "argocd-repo-server"
}

# Workload Identity binding for API Server
module "argocd_server_wi" {
  source = "../../modules/workload-identity"

  project_id         = var.project_id
  gcp_sa_email       = module.argocd_server_sa.email
  k8s_namespace      = "argocd"
  k8s_sa_name        = "argocd-server"
}

# Workload Identity binding for Backup (Velero)
module "velero_backup_wi" {
  source = "../../modules/workload-identity"

  project_id         = var.project_id
  gcp_sa_email       = module.argocd_backup_sa.email
  k8s_namespace      = "velero"
  k8s_sa_name        = "velero"
}
```

---

## Task 3: Add GCS Bucket and Managed Certificate

**Agent:** terraform-specialist

**Step 1: Add remaining resources to main.tf**

```hcl
# GCS bucket for 14-day backups
module "argocd_backup_bucket" {
  source = "../../modules/gcs-backup-bucket"

  project_id      = var.project_id
  bucket_name     = "pcc-argocd-prod-backups"
  region          = var.region
  retention_days  = 14
}

# Managed SSL certificate
module "argocd_ssl_cert" {
  source = "../../modules/managed-certificate"

  project_id   = var.project_id
  cert_name    = "argocd-prod-tls"
  domains      = [var.domain]
}
```

**Step 2: Create outputs.tf**

File: `environments/prod/outputs.tf`

```hcl
output "controller_sa_email" {
  value = module.argocd_controller_sa.email
}

output "repo_sa_email" {
  value = module.argocd_repo_sa.email
}

output "server_sa_email" {
  value = module.argocd_server_sa.email
}

output "backup_sa_email" {
  value = module.argocd_backup_sa.email
}

output "backup_bucket" {
  value = module.argocd_backup_bucket.bucket_name
}

output "ssl_cert_name" {
  value = module.argocd_ssl_cert.cert_name
}
```

**Step 3: Commit configuration**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra
git add environments/prod/main.tf environments/prod/outputs.tf
git commit -m "feat(phase-7): configure terraform for 4 SAs, WI, backup bucket, SSL cert"
```

---

## Chunk Complete Checklist

- [ ] 4 service accounts configured (controller, repo, server, backup)
- [ ] 4 workload identity bindings configured
- [ ] GCS backup bucket with 14-day retention
- [ ] Managed SSL certificate configured
- [ ] Outputs defined
- [ ] Configuration committed
- [ ] Ready for chunk 5 (terraform deploy)
