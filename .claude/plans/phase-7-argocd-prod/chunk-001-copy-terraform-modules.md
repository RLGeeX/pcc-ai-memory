# Chunk 1: Copy Terraform Modules from Phase 6

**Status:** pending
**Dependencies:** none
**Complexity:** simple
**Estimated Time:** 10 minutes
**Tasks:** 2
**Phase:** Infrastructure Foundation
**Story:** STORY-701
**Jira:** PCC-281

---

## Task 1: Copy Existing Modules from NonProd

**Agent:** terraform-specialist

**Step 1: Copy 3 modules from Phase 6**

```bash
cd ~/pcc/infra
mkdir -p pcc-argocd-prod-infra/modules

# Copy service-account module
cp -r pcc-argocd-nonprod-infra/modules/service-account \
  pcc-argocd-prod-infra/modules/

# Copy workload-identity module
cp -r pcc-argocd-nonprod-infra/modules/workload-identity \
  pcc-argocd-prod-infra/modules/

# Copy managed-certificate module
cp -r pcc-argocd-nonprod-infra/modules/managed-certificate \
  pcc-argocd-prod-infra/modules/
```

**Step 2: Verify modules copied**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra/modules
ls -la
# Expected: service-account, workload-identity, managed-certificate directories
```

---

## Task 2: Initialize Git Repository

**Agent:** terraform-specialist

**Step 1: Create git repo**

```bash
cd ~/pcc/infra/pcc-argocd-prod-infra
git init
```

**Step 2: Create .gitignore**

```bash
cat <<EOF > .gitignore
.terraform/
*.tfstate
*.tfstate.backup
*.tfplan
.terraform.lock.hcl
EOF
```

**Step 3: Initial commit**

```bash
git add modules/ .gitignore
git commit -m "feat(phase-7): copy terraform modules from Phase 6 for prod ArgoCD"
```

---

## Chunk Complete Checklist

- [ ] 3 modules copied (service-account, workload-identity, managed-certificate)
- [ ] Git repository initialized
- [ ] .gitignore created
- [ ] Initial commit completed
- [ ] Ready for chunk 2 (GCS backup module)
