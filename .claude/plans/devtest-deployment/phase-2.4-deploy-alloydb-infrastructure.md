# Phase 2.4: Deploy AlloyDB Infrastructure

**Phase**: 2.4 (AlloyDB Infrastructure - Deployment)
**Duration**: 20-25 minutes
**Type**: Implementation
**Status**: Ready for Execution

---

## Execution Tool

**Use WARP for this phase** - Running terraform commands only, no file editing.

---

## Objective

Deploy AlloyDB cluster and primary instance to devtest environment using terraform. Verify the infrastructure is provisioned correctly.

## Prerequisites

✅ Phase 2.3 completed (alloydb.tf configuration created)
✅ `pcc-app-shared-infra` repository with alloydb.tf
✅ Terraform initialized in pcc-app-shared-infra
✅ GCP credentials configured

---

## Working Directory

```bash
cd ~/pcc/infra/pcc-app-shared-infra/terraform
```

---

## Step 1: Format Configuration

```bash
terraform fmt
```

**Expected Output**:
```
alloydb.tf
```

**Purpose**: Ensure consistent code formatting

---

## Step 2: Validate Configuration

```bash
terraform validate
```

**Expected Output**:
```
Success! The configuration is valid.
```

**If validation fails**:
- Check syntax errors in alloydb.tf
- Verify module source path is correct
- Ensure all required variables are defined

---

## Step 3: Initialize Terraform (if needed)

```bash
terraform init -upgrade
```

**Expected Output**:
```
Initializing modules...
Downloading git::https://github.com/portco-connect/pcc-tf-library.git?ref=main for alloydb...
- alloydb in .terraform/modules/alloydb/modules/alloydb-cluster

Initializing the backend...

Initializing provider plugins...
- Reusing previous version of hashicorp/google from the dependency lock file
- Using previously-installed hashicorp/google v5.x.x

Terraform has been successfully initialized!
```

**Purpose**: Download module from pcc-tf-library and initialize providers

---

## Step 4: Generate Deployment Plan

```bash
terraform plan -var="environment=devtest" -out=alloydb-devtest.tfplan
```

**Expected Resources**:
```
Terraform will perform the following actions:

  # module.alloydb.google_alloydb_cluster.cluster will be created
  + resource "google_alloydb_cluster" "cluster" {
      + cluster_id   = "pcc-alloydb-devtest"
      + project      = "pcc-prj-app-devtest"
      + location     = "us-east4"
      + network      = "projects/pcc-prj-net-shared/global/networks/pcc-vpc-nonprod"
      ...
    }

  # module.alloydb.google_alloydb_instance.primary will be created
  + resource "google_alloydb_instance" "primary" {
      + instance_id   = "primary"
      + instance_type = "PRIMARY"
      + cluster       = (known after apply)
      + availability_type = "ZONAL"
      + machine_config {
          + cpu_count = 2
        }
      ...
    }

Plan: 2 to add, 0 to change, 0 to destroy.

Changes to Outputs:
  + alloydb_cluster_id              = (known after apply)
  + alloydb_cluster_name            = (known after apply)
  + alloydb_primary_connection_name = (known after apply)
  + alloydb_primary_instance_id     = (known after apply)
  + alloydb_primary_instance_ip     = (known after apply)
  + alloydb_network_id              = (known after apply)
```

**Verify**:
- 2 resources to add (cluster + instance)
- Cluster ID: pcc-alloydb-devtest
- Availability type: ZONAL
- Machine config: cpu_count = 2 (db-standard-2)
- 6 new outputs

**Important**: Review carefully before applying! AlloyDB deployment is a significant infrastructure change.

---

## Step 5: Apply Deployment Plan

**⚠️ IMPORTANT**: This step will create billable resources (~$200/month)

```bash
terraform apply alloydb-devtest.tfplan
```

**Expected Duration**: 15-20 minutes

**Progress Indicators**:
```
module.alloydb.google_alloydb_cluster.cluster: Creating...
module.alloydb.google_alloydb_cluster.cluster: Still creating... [10s elapsed]
module.alloydb.google_alloydb_cluster.cluster: Still creating... [20s elapsed]
...
module.alloydb.google_alloydb_cluster.cluster: Creation complete after 5m12s [id=projects/pcc-prj-app-devtest/locations/us-east4/clusters/pcc-alloydb-devtest]

module.alloydb.google_alloydb_instance.primary: Creating...
module.alloydb.google_alloydb_instance.primary: Still creating... [10s elapsed]
...
module.alloydb.google_alloydb_instance.primary: Creation complete after 10m34s [id=projects/pcc-prj-app-devtest/locations/us-east4/clusters/pcc-alloydb-devtest/instances/primary]

Apply complete! Resources: 2 added, 0 changed, 0 destroyed.

Outputs:

alloydb_cluster_id = "pcc-alloydb-devtest"
alloydb_cluster_name = "projects/pcc-prj-app-devtest/locations/us-east4/clusters/pcc-alloydb-devtest"
alloydb_primary_connection_name = "pcc-prj-app-devtest:us-east4:pcc-alloydb-devtest:primary"
alloydb_primary_instance_id = "primary"
alloydb_primary_instance_ip = "10.0.1.5" # Example private IP
alloydb_network_id = "projects/pcc-prj-net-shared/global/networks/pcc-vpc-nonprod"
```

**Success Indicators**:
- ✅ "Apply complete! Resources: 2 added"
- ✅ All 6 outputs displayed
- ✅ No errors in terraform output

---

## Step 6: Verify Deployment

### Verify via GCloud CLI

```bash
# List AlloyDB clusters
gcloud alloydb clusters list \
  --region=us-east4 \
  --project=pcc-prj-app-devtest

# Describe cluster
gcloud alloydb clusters describe pcc-alloydb-devtest \
  --region=us-east4 \
  --project=pcc-prj-app-devtest

# List instances
gcloud alloydb instances list \
  --cluster=pcc-alloydb-devtest \
  --region=us-east4 \
  --project=pcc-prj-app-devtest

# Describe primary instance
gcloud alloydb instances describe primary \
  --cluster=pcc-alloydb-devtest \
  --region=us-east4 \
  --project=pcc-prj-app-devtest
```

**Expected Output**:
- Cluster state: READY
- Instance state: READY
- Instance IP: Private IP address (10.x.x.x)
- Availability type: ZONAL
- Machine config: 2 vCPU

### Verify via Terraform Outputs

```bash
terraform output
```

**Verify All Outputs Present**:
- alloydb_cluster_id
- alloydb_cluster_name
- alloydb_primary_connection_name
- alloydb_primary_instance_id
- alloydb_primary_instance_ip
- alloydb_network_id

---

## Validation Checklist

- [ ] Terraform plan shows 2 resources to add
- [ ] Terraform apply completed successfully
- [ ] Cluster created: pcc-alloydb-devtest
- [ ] Primary instance created: primary
- [ ] Cluster state: READY (via gcloud)
- [ ] Instance state: READY (via gcloud)
- [ ] Instance IP address assigned (private IP)
- [ ] Availability type: ZONAL
- [ ] Machine config: 2 vCPU, 16 GB RAM
- [ ] 6 outputs available
- [ ] No errors in terraform or gcloud output

---

## Cost Verification

```bash
# Estimate monthly cost (approximate)
gcloud alloydb instances describe primary \
  --cluster=pcc-alloydb-devtest \
  --region=us-east4 \
  --project=pcc-prj-app-devtest \
  --format="value(machineConfig.cpuCount)"
```

**Expected Cost Breakdown**:
- AlloyDB instance (db-standard-2, ZONAL): ~$180/month
- Backup storage (30-day retention): ~$10-20/month
- Total: ~$200/month

---

## Troubleshooting

### Issue: "Error creating Cluster: Network not found"
**Resolution**: Verify NonProd VPC exists
```bash
gcloud compute networks describe pcc-vpc-nonprod \
  --project=pcc-prj-net-shared
```

### Issue: "Error creating Cluster: Service account missing permissions"
**Resolution**: Verify AlloyDB service account has compute.networkUser role
```bash
gcloud projects get-iam-policy pcc-prj-net-shared \
  --flatten="bindings[].members" \
  --filter="bindings.role:roles/compute.networkUser"
```

### Issue: "Error creating Instance: Cluster not ready"
**Resolution**: Wait for cluster to reach READY state before creating instance. This is handled automatically by terraform depends_on.

### Issue: "Plan shows unexpected changes"
**Resolution**:
- Run `terraform refresh` to sync state
- Check for manual changes in GCP console
- Review terraform state: `terraform show`

---

## Post-Deployment Actions

**DO NOT PROCEED** until:
- ✅ Cluster is in READY state
- ✅ Instance is in READY state
- ✅ All 6 outputs are populated

**Next Steps**:
1. **Phase 2.5**: Create Secret Manager module
2. **Phase 2.6**: Store AlloyDB credentials in Secret Manager
3. **Phase 2.8**: Add IAM bindings for database access
4. **Phase 2.10**: Configure Flyway for database migrations

---

## Rollback Procedure

If deployment fails or needs to be rolled back:

```bash
# Destroy only AlloyDB resources
terraform destroy -target=module.alloydb

# Confirm destruction
terraform state list | grep alloydb
```

**⚠️ WARNING**: This will delete the AlloyDB cluster and all data. Only use for initial deployment issues.

---

## References

- **AlloyDB CLI**: https://cloud.google.com/sdk/gcloud/reference/alloydb
- **Terraform Plan**: https://developer.hashicorp.com/terraform/cli/commands/plan
- **Terraform Apply**: https://developer.hashicorp.com/terraform/cli/commands/apply

---

## Time Estimate

- **Format**: 1 minute
- **Validate**: 1 minute
- **Initialize** (if needed): 2-3 minutes
- **Generate plan**: 2-3 minutes
- **Apply plan**: 15-20 minutes (AlloyDB provisioning)
- **Verify deployment**: 3-5 minutes
- **Total**: 20-25 minutes

---

**Status**: Ready for execution
**Next**: Phase 2.5 - Create Secret Manager Module
