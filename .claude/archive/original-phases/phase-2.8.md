# Phase 2.8: Validate Terraform

**Phase**: 2.8 (AlloyDB Infrastructure - Validation)
**Duration**: 10-15 minutes
**Type**: Validation
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/20+)

---

## Objective

Validate all Phase 2 terraform code (module and caller) using `terraform fmt`, `terraform validate`, and `terraform plan` to ensure correctness before deployment in Phase 2.9.

## Prerequisites

✅ Phase 2.7 completed (developer access and Flyway documented)
✅ Phase 2.6 completed (IAM bindings designed)
✅ Phase 2.5 completed (Secret Manager designed)
✅ Phase 2.2 completed (terraform module created in pcc-tf-library)
✅ Phase 2.3 completed (module call created in pcc-app-shared-infra)
✅ Terraform 1.6+ installed
✅ GCP credentials configured

---

## Validation Workflow

### Step 1: Validate Terraform Module (pcc-tf-library)

**Working Directory**: `~/pcc/core/pcc-tf-library/modules/alloydb-cluster/`

---

#### 1.1: Format Check

```bash
cd ~/pcc/core/pcc-tf-library/modules/alloydb-cluster/
terraform fmt -check -recursive
```

**Expected Output**:
```
# No output = all files properly formatted
```

**If Formatting Needed**:
```bash
terraform fmt -recursive
git add .
git commit -m "style: format AlloyDB module"
```

---

#### 1.2: Initialize Module

```bash
terraform init
```

**Expected Output**:
```
Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/google versions matching "~> 5.0"...
- Installing hashicorp/google v5.x.x...

Terraform has been successfully initialized!
```

---

#### 1.3: Validate Module

```bash
terraform validate
```

**Expected Output**:
```
Success! The configuration is valid.
```

**Validation Checks**:
- Variable types correct
- Resource syntax correct
- Required providers specified
- Output expressions valid

---

### Step 2: Validate Module Caller (pcc-app-shared-infra)

**Working Directory**: `~/pcc/infra/pcc-app-shared-infra/terraform/`

---

#### 2.1: Format Check

```bash
cd ~/pcc/infra/pcc-app-shared-infra/terraform/
terraform fmt -check -recursive
```

**Expected Output**:
```
# No output = all files properly formatted
```

**If Formatting Needed**:
```bash
terraform fmt -recursive
git add .
git commit -m "style: format shared infra terraform"
```

---

#### 2.2: Initialize Caller

```bash
terraform init
```

**Expected Output**:
```
Initializing modules...
Downloading git::https://github.com/your-org/pcc-tf-library.git//modules/alloydb-cluster...

Initializing the backend...
Initializing provider plugins...
- Finding hashicorp/google versions matching "~> 5.0"...

Terraform has been successfully initialized!
```

**Module Download**: Terraform downloads pcc-tf-library module from Git

---

#### 2.3: Validate Caller

```bash
terraform validate
```

**Expected Output**:
```
Success! The configuration is valid.
```

**Validation Checks**:
- Module source path correct
- Module variables provided
- Required variables not missing
- Output references valid

---

#### 2.4: Terraform Plan (Dry Run)

```bash
terraform plan -out=alloydb-devtest.tfplan
```

**Expected Output** (abridged):
```
Terraform will perform the following actions:

  # module.alloydb_cluster_devtest.google_alloydb_cluster.cluster will be created
  + resource "google_alloydb_cluster" "cluster" {
      + cluster_id   = "pcc-alloydb-cluster-devtest"
      + location     = "us-east4"
      + project      = "pcc-prj-app-devtest"
      + psc_config {
          + psc_enabled = true
        }
      + automated_backup_policy {
          + enabled = true
          + backup_window {
              + start_times {
                  + hours   = 2
                  + minutes = 0
                }
            }
          + quantity_based_retention {
              + count = 30
            }
        }
      + continuous_backup_config {
          + enabled              = true
          + recovery_window_days = 7
        }
    }

  # module.alloydb_cluster_devtest.google_alloydb_instance.primary will be created
  + resource "google_alloydb_instance" "primary" {
      + cluster       = "projects/pcc-prj-app-devtest/locations/us-east4/clusters/pcc-alloydb-cluster-devtest"
      + instance_id   = "pcc-alloydb-instance-devtest-primary"
      + instance_type = "PRIMARY"
      + machine_config {
          + cpu_count = 2
        }
      + availability_type = "REGIONAL"
    }

  # module.alloydb_cluster_devtest.google_alloydb_instance.replica[0] will be created
  + resource "google_alloydb_instance" "replica" {
      + cluster       = "projects/pcc-prj-app-devtest/locations/us-east4/clusters/pcc-alloydb-cluster-devtest"
      + instance_id   = "pcc-alloydb-instance-devtest-replica"
      + instance_type = "READ_POOL"
      + machine_config {
          + cpu_count = 2
        }
      + read_pool_config {
          + node_count = 1
        }
    }

Plan: 3 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + alloydb_devtest_cluster_id              = "pcc-alloydb-cluster-devtest"
  + alloydb_devtest_primary_ip              = (known after apply)
  + alloydb_devtest_primary_connection_string = (sensitive value)
  + alloydb_devtest_replica_ip              = (known after apply)
  + alloydb_devtest_psc_dns_name            = (known after apply)

------------------------------------------------------------------------

Saved the plan to: alloydb-devtest.tfplan
```

**Resource Count**:
- 1 AlloyDB cluster (auto-creates default `postgres` database)
- 2 AlloyDB instances (primary + replica)
- **Total**: 3 resources

**Note**:
- PSC endpoints are auto-created by AlloyDB (not counted as Terraform resources)
- Database `client_api_db_devtest` will be created by Flyway (Phase 2.7), not Terraform
- No `google_alloydb_database` resource exists in Terraform Google provider

---

### Step 3: Analyze Terraform Plan

**Review Checklist**:
- [ ] Cluster created in correct project (`pcc-prj-app-devtest`)
- [ ] Network reference correct (`projects/pcc-prj-net-shared/global/networks/pcc-vpc-nonprod`)
- [ ] PSC enabled (`psc_config { psc_enabled = true }`)
- [ ] Backup policy enabled (30-day retention)
- [ ] PITR enabled (7-day window)
- [ ] Primary instance: 2 vCPUs, REGIONAL availability
- [ ] Replica instance: 2 vCPUs, READ_POOL type
- [ ] Outputs defined (cluster_id, IPs, connection_string, PSC DNS name)
- [ ] Verify default `postgres` database will be auto-created (databases created by Flyway, not Terraform)

---

### Step 4: Verify Prerequisites

**Prerequisite Checks**:
```bash
# Check project exists
gcloud projects describe pcc-prj-app-devtest

# Check VPC exists (AlloyDB will use this for PSC auto-creation)
gcloud compute networks describe pcc-vpc-nonprod \
  --project=pcc-prj-net-shared
```

**Expected**: All prerequisites exist from Phase 1

---

### Step 5: Estimate Costs

**AlloyDB Pricing** (devtest environment):

| Resource | Quantity | Cost/Month |
|----------|----------|------------|
| Primary Instance (2 vCPUs) | 1 | ~$250 |
| Replica Instance (2 vCPUs) | 1 | ~$250 |
| Storage (100 GB) | 100 GB | ~$17 |
| Backups (30-day retention) | ~500 GB | ~$30 |
| PITR (7-day logs) | ~50 GB | ~$5 |

**Total Estimated Cost**: ~$550/month

**Note**: DevTest pricing lower than production (smaller instances)

---

## Validation Criteria

- [ ] **Module Formatting**: `terraform fmt -check` passes
- [ ] **Module Validation**: `terraform validate` passes
- [ ] **Caller Formatting**: `terraform fmt -check` passes
- [ ] **Caller Validation**: `terraform validate` passes
- [ ] **Terraform Plan**: Generated successfully (alloydb-devtest.tfplan)
- [ ] **Resource Count**: 4 resources (1 cluster, 2 instances, 1 database)
- [ ] **Prerequisites**: VPC, project all exist
- [ ] **Configuration**: Cluster config matches Phase 2.1 design

---

## Common Validation Errors

### Error 1: Module Source Not Found

**Error**:
```
Error: Module not found
│ The module address "git::https://..." could not be found.
```

**Solution**: Check module source URL, verify Git access
```bash
git ls-remote https://github.com/your-org/pcc-tf-library.git
```

---

### Error 2: Variable Not Provided

**Error**:
```
Error: Missing required variable
│ The variable "network_self_link" is required, but no definition was found.
```

**Solution**: Add variable to module call (Phase 2.3)

---

### Error 3: Network Not Found

**Error**:
```
Error: Error creating AlloyDB cluster: network pcc-vpc-nonprod not found
```

**Solution**: Verify VPC network exists (should already exist from Phase 1)
```bash
gcloud compute networks describe pcc-vpc-nonprod \
  --project=pcc-prj-net-shared
```

---

## Rollback Strategy

**If Validation Fails**:
1. **Fix errors**: Address validation errors (syntax, variables)
2. **Re-run validation**: `terraform validate`
3. **Re-run plan**: `terraform plan -out=alloydb-devtest.tfplan`

**If Prerequisites Missing**:
1. **Verify VPC**: Confirm pcc-vpc-nonprod exists (should already exist from Phase 1)
2. **Verify project**: Confirm pcc-prj-app-devtest exists
3. **Retry validation**: Re-run terraform plan

**No State Changes**: Validation phase does NOT modify infrastructure

---

## Deliverables

- [ ] Terraform module validated (`pcc-tf-library/modules/alloydb-cluster/`)
- [ ] Module caller validated (`pcc-app-shared-infra/terraform/`)
- [ ] Terraform plan generated (`alloydb-devtest.tfplan`)
- [ ] Prerequisites verified (VPC, project)
- [ ] Cost estimate calculated (~$550/month)
- [ ] Ready for Phase 2.9 (deployment)

---

## Next Steps After Validation

**Phase 2.9 Preparation**:
- [ ] Review terraform plan output (4 resources)
- [ ] Confirm cost estimate acceptable (~$550/month)
- [ ] Verify prerequisites (VPC, project)
- [ ] Prepare for WARP deployment (Phase 2.9)
- [ ] Plan Flyway baseline (after deployment)

---

## References

- Phase 2.1 (cluster configuration design)
- Phase 2.2 (terraform module)
- Phase 2.3 (module call)
- Phase 1 (network infrastructure, prerequisite)
- 🔗 Terraform Validate: https://www.terraform.io/docs/cli/commands/validate.html
- 🔗 Terraform Plan: https://www.terraform.io/docs/cli/commands/plan.html

---

## Notes

- **No State Changes**: Validation does NOT modify infrastructure
- **Dry Run**: `terraform plan` shows what WOULD be created
- **Prerequisites**: Phase 1 must be complete (VPC network already exists)
- **PSC Auto-Creation**: AlloyDB automatically creates PSC endpoints when psc_enabled = true
- **Cost**: ~$550/month for devtest (2 vCPU instances + 100 GB storage)
- **Formatting**: Use `terraform fmt` before commit
- **Plan File**: `alloydb-devtest.tfplan` saved for Phase 2.9 apply

---

## Time Estimate

**Validation**: 10-15 minutes
- 2 min: Format check (module + caller)
- 2 min: Initialize (module + caller)
- 2 min: Validate (module + caller)
- 3 min: Terraform plan (analyze output)
- 2 min: Verify prerequisites

---

**Next Phase**: 2.9 - Deploy via WARP
