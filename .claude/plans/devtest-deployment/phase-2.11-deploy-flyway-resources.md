# Phase 2.11: Deploy Flyway Resources

**Phase**: 2.11 (Database Migrations - Deployment)
**Duration**: 15-20 minutes
**Type**: Implementation
**Status**: Ready for Execution

---

## Execution Tool

**Use WARP for this phase** - Running terraform, kubectl, and gcloud commands only, no file editing.

---

## Objective

Deploy Flyway database migration system to Kubernetes and execute initial schema creation. Verifies end-to-end connectivity from K8s → Secret Manager → AlloyDB.

## Prerequisites

✅ Phase 2.10 completed (Flyway configuration files created)
✅ GKE cluster accessible via kubectl
✅ Workload Identity enabled on GKE cluster
✅ AlloyDB cluster and secrets deployed

---

## Working Directory

```bash
cd ~/pcc/infra/pcc-app-shared-infra
```

---

## Step 1: Apply Terraform Changes (Workload Identity)

```bash
cd terraform

# Plan
terraform plan -var="environment=devtest" -out=workload-identity.tfplan

# Review output (expect 1 new IAM binding)
# Apply
terraform apply workload-identity.tfplan

# Verify output
terraform output flyway_workload_identity_annotation
```

**Expected Output**:
```
iam.gke.io/gcp-service-account=flyway-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com
```

---

## Step 2: Verify GKE Workload Identity

```bash
# Get cluster name
gcloud container clusters list \
  --project=pcc-prj-app-devtest \
  --region=us-east4

# Check Workload Identity status
gcloud container clusters describe <CLUSTER_NAME> \
  --project=pcc-prj-app-devtest \
  --region=us-east4 \
  --format="value(workloadIdentityConfig.workloadPool)"
```

**Expected**: `pcc-prj-app-devtest.svc.id.goog`

**If NOT enabled**: Enable Workload Identity
```bash
gcloud container clusters update <CLUSTER_NAME> \
  --workload-pool=pcc-prj-app-devtest.svc.id.goog \
  --project=pcc-prj-app-devtest \
  --region=us-east4
```
**Note**: This takes 15-20 minutes

---

## Step 3: Set Kubectl Context

```bash
# Get credentials
gcloud container clusters get-credentials <CLUSTER_NAME> \
  --region=us-east4 \
  --project=pcc-prj-app-devtest

# Verify context
kubectl config current-context
```

---

## Step 4: Update Flyway Manifests with Environment

```bash
cd ../flyway

# Set environment variable
export ENVIRONMENT=devtest

# Update namespace
envsubst < namespace.yaml.template > namespace.yaml

# Update serviceaccount with actual annotation
ANNOTATION=$(cd ../terraform && terraform output -raw flyway_workload_identity_annotation)
sed -i "s|iam.gke.io/gcp-service-account:.*|iam.gke.io/gcp-service-account: $ANNOTATION|" serviceaccount.yaml

# Update job with environment
envsubst < job.yaml.template > job.yaml
```

**OR** manually edit files to replace `${ENVIRONMENT}` with `devtest`

---

## Step 5: Deploy Flyway Resources

```bash
# Apply namespace
kubectl apply -f namespace.yaml

# Apply service account
kubectl apply -f serviceaccount.yaml

# Apply ConfigMap
kubectl apply -f configmap.yaml

# Apply Job
kubectl apply -f job.yaml
```

**Expected Output**:
```
namespace/flyway created
serviceaccount/flyway-sa created
configmap/flyway-config created
job.batch/flyway-migrate created
```

---

## Step 6: Monitor Migration

### Watch Job Status
```bash
kubectl get jobs -n flyway -w
```

**Expected Progression**:
```
NAME             COMPLETIONS   DURATION   AGE
flyway-migrate   0/1                      0s
flyway-migrate   0/1           5s         5s
flyway-migrate   1/1           45s        45s
```

### View Init Container Logs (Fetch Secrets)
```bash
kubectl logs -n flyway job/flyway-migrate -c fetch-secrets
```

**Expected Output**:
```
Fetching database password from Secret Manager...
Password fetched successfully
```

### View Auth Proxy Logs
```bash
kubectl logs -n flyway job/flyway-migrate -c alloydb-auth-proxy
```

**Expected Output**:
```
2025-01-20T10:30:00.000Z [INFO] Listening on 0.0.0.0:5432
2025-01-20T10:30:00.000Z [INFO] Connection accepted from 127.0.0.1
```

### View Flyway Logs
```bash
kubectl logs -n flyway -f job/flyway-migrate -c flyway
```

**Expected Output**:
```
Waiting for Auth Proxy...
Auth Proxy ready
Running Flyway migrations...
Flyway Community Edition 9.x.x by Redgate
Successfully validated 2 migrations (execution time 00:00.123s)
Creating Schema History table [client_api].[flyway_schema_history] ...
Current version of schema [client_api]: << Empty Schema >>
Migrating schema [client_api] to version "1 - create schema"
Migrating schema [client_api] to version "2 - create tables"
Successfully applied 2 migrations to schema [client_api] (execution time 00:01.456s)
Migration complete
```

---

## Step 7: Verify Database Schema

### Method 1: Via kubectl exec (if psql available in pod)
```bash
kubectl run -n flyway psql-test --rm -it \
  --image=postgres:15-alpine \
  --env="PGPASSWORD=$(gcloud secrets versions access latest --secret=alloydb-devtest-password --project=pcc-prj-app-devtest)" \
  -- psql \
  -h <ALLOYDB_IP> \
  -U postgres \
  -d client_api_db \
  -c "\dt client_api.*"
```

### Method 2: Via local connection (if psql installed)
```bash
# Get AlloyDB IP
ALLOYDB_IP=$(gcloud alloydb instances describe primary \
  --cluster=pcc-alloydb-devtest \
  --region=us-east4 \
  --project=pcc-prj-app-devtest \
  --format="value(ipAddress)")

# Get password
PASSWORD=$(gcloud secrets versions access latest \
  --secret=alloydb-devtest-password \
  --project=pcc-prj-app-devtest)

# Connect
PGPASSWORD=$PASSWORD psql \
  -h $ALLOYDB_IP \
  -U postgres \
  -d client_api_db \
  -c "\dt client_api.*"
```

**Expected Output**:
```
                      List of relations
   Schema    |         Name          | Type  |  Owner
-------------+-----------------------+-------+----------
 client_api  | clients               | table | postgres
 client_api  | flyway_schema_history | table | postgres
 client_api  | users                 | table | postgres
(3 rows)
```

### Verify Migration History
```bash
PGPASSWORD=$PASSWORD psql \
  -h $ALLOYDB_IP \
  -U postgres \
  -d client_api_db \
  -c "SELECT * FROM client_api.flyway_schema_history;"
```

**Expected**: 2 rows (V1 and V2 migrations)

---

## Step 8: Verify Workload Identity

```bash
# Check ServiceAccount annotation
kubectl get serviceaccount flyway-sa -n flyway -o yaml | grep iam.gke.io

# Expected: iam.gke.io/gcp-service-account: flyway-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com

# Verify IAM binding
gcloud iam service-accounts get-iam-policy \
  flyway-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com \
  --project=pcc-prj-app-devtest
```

**Expected**: `roles/iam.workloadIdentityUser` granted to K8s ServiceAccount

---

## Validation Checklist

- [ ] Terraform applied Workload Identity binding
- [ ] GKE cluster has Workload Identity enabled
- [ ] Flyway namespace created
- [ ] Flyway ServiceAccount created with annotation
- [ ] ConfigMap created with SQL scripts
- [ ] Job created and completed successfully (1/1)
- [ ] Init container fetched password successfully
- [ ] Auth Proxy connected to AlloyDB
- [ ] Flyway applied 2 migrations successfully
- [ ] Database schema verified: 3 tables exist
- [ ] Migration history table populated
- [ ] No errors in any logs

---

## Troubleshooting

### Issue: "Permission denied on Secret Manager"
**Resolution**: Verify IAM binding
```bash
gcloud secrets get-iam-policy alloydb-devtest-password \
  --project=pcc-prj-app-devtest | grep flyway-devtest-sa
```

### Issue: "Could not connect to AlloyDB"
**Resolution**: Verify Auth Proxy configuration
```bash
kubectl logs -n flyway job/flyway-migrate -c alloydb-auth-proxy
# Check connection string format
```

### Issue: "Workload Identity not working"
**Resolution**: Verify annotation and IAM binding
```bash
# Check annotation
kubectl describe serviceaccount flyway-sa -n flyway

# Check IAM policy
gcloud iam service-accounts get-iam-policy \
  flyway-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com \
  --project=pcc-prj-app-devtest
```

### Issue: "Flyway validation failed"
**Resolution**: Check SQL syntax
```bash
kubectl get configmap flyway-config -n flyway -o yaml | grep -A 50 "V1__"
```

### Issue: "Database does not exist"
**Resolution**: Create database first
```bash
# Connect and create database
PGPASSWORD=$PASSWORD psql \
  -h $ALLOYDB_IP \
  -U postgres \
  -c "CREATE DATABASE client_api_db;"
```

### Issue: "Job failed to complete"
**Resolution**: Check pod status and logs
```bash
kubectl get pods -n flyway
kubectl describe pod -n flyway <POD_NAME>
kubectl logs -n flyway <POD_NAME> -c flyway
```

---

## Cleanup (if needed to re-run)

```bash
# Delete job
kubectl delete job flyway-migrate -n flyway

# Re-apply job
kubectl apply -f job.yaml

# Watch new execution
kubectl logs -n flyway -f job/flyway-migrate -c flyway
```

---

## Post-Deployment Actions

**DO NOT PROCEED** until:
- ✅ Job completed successfully (1/1)
- ✅ 2 migrations applied
- ✅ 3 tables exist in database
- ✅ No errors in logs

**Connection Info for Applications**:
- **Host**: Use Auth Proxy or PSC endpoint
- **Port**: 5432
- **Database**: `client_api_db`
- **Schema**: `client_api`
- **User**: `postgres`
- **Password**: From Secret Manager (`alloydb-devtest-password`)

---

## Next Steps

**Phase 2.12** will:
- Validate entire deployment end-to-end
- Document connection strings
- Test application connectivity
- Create deployment summary

---

## References

- **Flyway CLI**: https://flywaydb.org/documentation/usage/commandline
- **kubectl logs**: https://kubernetes.io/docs/reference/kubectl/cheatsheet/#interacting-with-running-pods
- **Workload Identity**: https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity

---

## Time Estimate

- **Apply terraform**: 2-3 minutes
- **Verify GKE**: 2 minutes
- **Set kubectl context**: 1 minute
- **Update manifests**: 2-3 minutes
- **Deploy resources**: 2 minutes
- **Monitor migration**: 3-5 minutes
- **Verify database**: 3-5 minutes
- **Total**: 15-20 minutes

---

**Status**: Ready for execution
**Next**: Phase 2.12 - Validation and Deployment Summary
