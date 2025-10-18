# PCC Foundation Workloads - Future Implementation

This document outlines the workload deployment and testing phase that will be executed after the foundation infrastructure is deployed.

---

## Overview

After completing Weeks 1-5 of the foundation deployment (organization policies, folders, projects, networks, and IAM), this workload phase will validate the infrastructure by deploying test workloads across different project types.

**Timeline:** TBD (post-foundation deployment)
**Duration:** 1-2 weeks
**Prerequisites:** Successful completion of foundation infrastructure (Weeks 1-5)

---

## Objectives

1. **Validate Network Connectivity:** Ensure Shared VPC, Cloud NAT, and firewall rules work correctly
2. **Test GKE Deployments:** Deploy test clusters in devops projects with proper subnet utilization
3. **Verify IAM Permissions:** Confirm Google Workspace group-based access works as designed
4. **Validate Logging:** Ensure all logs flow to central logging project
5. **Test Security Controls:** Verify organization policies prevent prohibited actions
6. **Document Operational Procedures:** Create runbooks for common operations

---

## Test Workloads by Project Type

### 1. Application Projects Testing

**Projects:** pcc-prj-app-devtest, pcc-prj-app-dev

**Test Scenarios:**

#### 1.1 Compute Engine VM Deployment
- Deploy test VM in Shared VPC subnet
- Verify VM has NO external IP (org policy enforcement)
- Test SSH via Identity-Aware Proxy (IAP)
- Validate Private Google Access for API calls
- Confirm Cloud NAT provides egress connectivity
- Verify logs appear in logging project

```bash
# Deploy test VM
gcloud compute instances create test-app-vm \
  --project=pcc-prj-app-devtest \
  --zone=us-east4-a \
  --machine-type=e2-micro \
  --subnet=projects/pcc-prj-network-nonprod/regions/us-east4/subnetworks/pcc-subnet-nonprod-use4 \
  --no-address \
  --shielded-secure-boot \
  --shielded-vtpm \
  --shielded-integrity-monitoring

# Test SSH via IAP
gcloud compute ssh test-app-vm \
  --project=pcc-prj-app-devtest \
  --zone=us-east4-a \
  --tunnel-through-iap

# Test internet connectivity via Cloud NAT
curl -I https://www.google.com

# Verify logs
gcloud logging read "resource.type=gce_instance AND resource.labels.instance_id=<instance-id>" \
  --project=pcc-prj-logging-monitoring \
  --limit=10
```

**Expected Results:**
- VM deploys successfully without external IP
- SSH via IAP works without firewall rule modifications
- VM can reach internet via Cloud NAT
- Serial port access is blocked (org policy)
- Logs appear in logging project within 5 minutes

#### 1.2 Cloud Run Service Deployment
- Deploy simple Hello World service
- Verify private networking
- Test service invocation
- Validate service-to-service authentication

```bash
# Deploy Cloud Run service
gcloud run deploy test-app-service \
  --project=pcc-prj-app-devtest \
  --region=us-east4 \
  --image=gcr.io/cloudrun/hello \
  --no-allow-unauthenticated \
  --vpc-connector=projects/pcc-prj-network-nonprod/locations/us-east4/connectors/app-connector

# Test invocation
gcloud run services invoke test-app-service \
  --project=pcc-prj-app-devtest \
  --region=us-east4
```

**Expected Results:**
- Service deploys successfully
- Service requires authentication (unauthenticated access blocked)
- Service can access Shared VPC resources via VPC connector

---

### 2. DevOps Projects Testing

**Projects:** pcc-prj-devops-nonprod, pcc-prj-devops-prod

**Test Scenarios:**

#### 2.1 GKE Cluster Deployment
- Create GKE Autopilot cluster using devops-specific subnets
- Verify pod and service secondary ranges are used
- Deploy sample workload
- Test Workload Identity
- Validate cluster logging and monitoring

```bash
# Create GKE Autopilot cluster in nonprod
gcloud container clusters create-auto test-gke-cluster \
  --project=pcc-prj-devops-nonprod \
  --region=us-east4 \
  --network=projects/pcc-prj-network-nonprod/global/networks/pcc-vpc-nonprod \
  --subnetwork=projects/pcc-prj-network-nonprod/regions/us-east4/subnetworks/pcc-devops-nonprod-use4-main \
  --cluster-secondary-range-name=pcc-devops-nonprod-use4-pod \
  --services-secondary-range-name=pcc-devops-nonprod-use4-svc \
  --enable-private-nodes \
  --enable-private-endpoint \
  --master-ipv4-cidr=172.16.0.0/28 \
  --no-enable-master-authorized-networks \
  --enable-ip-alias \
  --enable-shielded-nodes \
  --enable-autorepair \
  --enable-autoupgrade \
  --workload-pool=pcc-prj-devops-nonprod.svc.id.goog \
  --logging=SYSTEM,WORKLOAD \
  --monitoring=SYSTEM

# Get cluster credentials
gcloud container clusters get-credentials test-gke-cluster \
  --project=pcc-prj-devops-nonprod \
  --region=us-east4

# Deploy sample workload
kubectl create deployment test-nginx --image=nginx:latest
kubectl expose deployment test-nginx --port=80 --type=ClusterIP

# Test Workload Identity
kubectl create serviceaccount test-ksa
gcloud iam service-accounts create test-gsa \
  --project=pcc-prj-devops-nonprod

gcloud iam service-accounts add-iam-policy-binding \
  test-gsa@pcc-prj-devops-nonprod.iam.gserviceaccount.com \
  --role roles/iam.workloadIdentityUser \
  --member "serviceAccount:pcc-prj-devops-nonprod.svc.id.goog[default/test-ksa]"

kubectl annotate serviceaccount test-ksa \
  iam.gke.io/gcp-service-account=test-gsa@pcc-prj-devops-nonprod.iam.gserviceaccount.com
```

**Expected Results:**
- GKE cluster deploys using correct subnets and secondary ranges
- Pods receive IPs from 10.24.144.0/20 range
- Services receive IPs from 10.24.160.0/20 range
- Workload Identity functions correctly
- Cluster logs appear in logging project
- No external IPs assigned to nodes

#### 2.2 Artifact Registry Testing
- Create Artifact Registry repository
- Push test container image
- Pull image from GKE cluster
- Validate IAM permissions for reader group

```bash
# Create Artifact Registry repository
gcloud artifacts repositories create test-repo \
  --project=pcc-prj-devops-nonprod \
  --repository-format=docker \
  --location=us-east4 \
  --description="Test repository"

# Build and push test image
docker build -t us-east4-docker.pkg.dev/pcc-prj-devops-nonprod/test-repo/hello:v1 .
docker push us-east4-docker.pkg.dev/pcc-prj-devops-nonprod/test-repo/hello:v1

# Deploy from Artifact Registry to GKE
kubectl create deployment test-ar-app \
  --image=us-east4-docker.pkg.dev/pcc-prj-devops-nonprod/test-repo/hello:v1
```

**Expected Results:**
- Repository creates successfully
- GKE cluster can pull images without additional authentication
- IAM group members can view/pull images based on permissions

---

### 3. Data Projects Testing

**Projects:** pcc-prj-data-devtest, pcc-prj-data-dev

**Test Scenarios:**

#### 3.1 BigQuery Dataset and Query
- Create BigQuery dataset
- Load sample data
- Run queries
- Verify IAM permissions
- Confirm query logs in logging project

```bash
# Create BigQuery dataset
bq mk --project_id=pcc-prj-data-devtest \
  --location=us-east4 \
  test_dataset

# Load sample data
bq load --project_id=pcc-prj-data-devtest \
  --source_format=CSV \
  test_dataset.test_table \
  gs://sample-data/test.csv \
  schema.json

# Run test query
bq query --project_id=pcc-prj-data-devtest \
  --use_legacy_sql=false \
  'SELECT COUNT(*) FROM `pcc-prj-data-devtest.test_dataset.test_table`'
```

**Expected Results:**
- Dataset creates in us-east4 location (org policy enforcement)
- Queries execute successfully
- Query logs appear in logging project
- Public dataset access is blocked

#### 3.2 Cloud SQL Instance
- Deploy Cloud SQL instance in Shared VPC
- Configure private IP only (no public IP)
- Test connectivity from Compute Engine
- Validate automated backups

```bash
# Create Cloud SQL instance
gcloud sql instances create test-postgres \
  --project=pcc-prj-data-devtest \
  --database-version=POSTGRES_15 \
  --tier=db-f1-micro \
  --region=us-east4 \
  --network=projects/pcc-prj-network-nonprod/global/networks/pcc-vpc-nonprod \
  --no-assign-ip \
  --enable-bin-log \
  --backup \
  --backup-start-time=02:00

# Connect from VM
gcloud sql connect test-postgres \
  --project=pcc-prj-data-devtest \
  --user=postgres
```

**Expected Results:**
- Cloud SQL instance has NO public IP (org policy enforcement)
- Private IP connectivity works from Shared VPC
- Automated backups are configured
- Binary logging enabled

---

### 4. Systems Projects Testing

**Projects:** pcc-prj-sys-nonprod

**Test Scenarios:**

#### 4.1 Monitoring Agent Deployment
- Deploy Cloud Monitoring agent on test VM
- Configure custom metrics collection
- Create sample dashboard
- Set up alerting policy

```bash
# Deploy VM with monitoring agent
gcloud compute instances create test-monitoring-vm \
  --project=pcc-prj-sys-nonprod \
  --zone=us-east4-a \
  --subnet=projects/pcc-prj-network-nonprod/regions/us-east4/subnetworks/pcc-subnet-nonprod-use4 \
  --no-address \
  --metadata=startup-script='#! /bin/bash
    curl -sSO https://dl.google.com/cloudagents/add-google-cloud-ops-agent-repo.sh
    sudo bash add-google-cloud-ops-agent-repo.sh --also-install'

# Verify agent is running
gcloud compute ssh test-monitoring-vm \
  --project=pcc-prj-sys-nonprod \
  --zone=us-east4-a \
  --tunnel-through-iap \
  --command="sudo systemctl status google-cloud-ops-agent"
```

**Expected Results:**
- Monitoring agent installs successfully
- Metrics appear in central monitoring project
- Custom dashboards can be created
- Alerts can be configured

---

## IAM Permission Testing

### Test Each Google Workspace Group

For each of the 31 groups created, validate permissions:

1. **gcp-organization-admins@pcconnect.ai**
   - Add test user to group
   - Verify org-level admin access
   - Confirm ability to modify org policies
   - Test folder/project creation

2. **gcp-network-nonprod-admins@pcconnect.ai**
   - Add test user to group
   - Verify ability to modify firewall rules in nonprod network
   - Confirm CANNOT modify prod network
   - Test subnet creation

3. **gcp-devops-nonprod-developers@pcconnect.ai**
   - Add test user to group
   - Verify ability to deploy to GKE cluster
   - Confirm CANNOT modify cluster configuration
   - Test kubectl access

4. **gcp-app-viewers@pcconnect.ai**
   - Add test user to group
   - Verify read-only access to app projects
   - Confirm CANNOT create/modify resources
   - Test listing resources

*Repeat for all 31 groups*

**Documentation:** Create IAM validation matrix with test results

---

## Security Control Validation

### Organization Policy Testing

For each organization policy, attempt to violate it and confirm denial:

1. **iam.disableServiceAccountKeyCreation**
   ```bash
   # Should FAIL
   gcloud iam service-accounts keys create test-key.json \
     --iam-account=test@pcc-prj-app-devtest.iam.gserviceaccount.com \
     --project=pcc-prj-app-devtest
   ```
   **Expected:** Error - service account key creation is disabled

2. **compute.vmExternalIpAccess**
   ```bash
   # Should FAIL
   gcloud compute instances create test-vm \
     --project=pcc-prj-app-devtest \
     --zone=us-east4-a \
     --subnet=pcc-subnet-nonprod-use4
   ```
   **Expected:** Error - external IP assignment is denied

3. **compute.requireOsLogin**
   ```bash
   # Should FAIL - SSH key upload
   gcloud compute instances add-metadata test-vm \
     --project=pcc-prj-app-devtest \
     --zone=us-east4-a \
     --metadata=ssh-keys="user:ssh-rsa AAAA..."
   ```
   **Expected:** Error - OS Login is required, SSH keys not allowed

4. **storage.publicAccessPrevention**
   ```bash
   # Should FAIL
   gsutil iam ch allUsers:objectViewer gs://test-bucket-pcc-app-devtest
   ```
   **Expected:** Error - public access is prevented

*Test all 20 organization policies*

**Documentation:** Create org policy validation report

---

## Logging & Monitoring Validation

### Verify Centralized Logging

1. **Check Log Sink Configuration**
   ```bash
   gcloud logging sinks list --organization=146990108557
   ```
   **Expected:** Organization-level sink to logging project

2. **Query Logs from Multiple Projects**
   ```bash
   # Query logs from app project
   gcloud logging read "resource.labels.project_id=pcc-prj-app-devtest" \
     --project=pcc-prj-logging-monitoring \
     --limit=50

   # Query logs from devops project
   gcloud logging read "resource.labels.project_id=pcc-prj-devops-nonprod" \
     --project=pcc-prj-logging-monitoring \
     --limit=50
   ```
   **Expected:** Logs from all projects appear in logging project

3. **Validate VPC Flow Logs**
   ```bash
   gcloud logging read "resource.type=gce_subnetwork AND logName:vpc_flows" \
     --project=pcc-prj-logging-monitoring \
     --limit=10
   ```
   **Expected:** Flow logs from all subnets

4. **Check Cloud Audit Logs**
   ```bash
   gcloud logging read "logName:cloudaudit.googleapis.com" \
     --project=pcc-prj-logging-monitoring \
     --limit=20
   ```
   **Expected:** Admin activity, data access, and system event logs

### Verify Monitoring

1. **Check Metrics Collection**
   - Navigate to Cloud Console → Monitoring
   - Verify metrics from all projects are visible
   - Confirm GKE cluster metrics appear

2. **Create Test Dashboard**
   - Create dashboard with metrics from multiple projects
   - Add VM CPU utilization charts
   - Add GKE container metrics
   - Add network throughput metrics

3. **Set Up Test Alert**
   - Create alert policy for high VM CPU usage
   - Test alert triggers by generating load
   - Verify notification channels work

---

## Performance & Connectivity Testing

### Network Performance Testing

1. **Inter-Subnet Connectivity**
   ```bash
   # Deploy VMs in both us-east4 and us-central1 subnets
   # Test latency between regions
   ping <vm-in-us-central1>
   iperf3 -c <vm-in-us-central1>
   ```

2. **Cloud NAT Throughput**
   ```bash
   # Generate outbound traffic
   curl https://speed.cloudflare.com/__down?bytes=100000000
   ```

3. **Private Google Access**
   ```bash
   # Test API calls without external IP
   curl -H "Metadata-Flavor: Google" \
     http://metadata.google.internal/computeMetadata/v1/instance/name
   ```

---

## Documentation Deliverables

After completing all tests, create the following documentation:

1. **Test Results Report**
   - Summary of all test scenarios
   - Pass/fail status
   - Issues encountered and resolutions
   - Performance metrics

2. **Operational Runbooks**
   - How to deploy VMs in Shared VPC
   - How to create GKE clusters in devops projects
   - How to troubleshoot connectivity issues
   - How to query centralized logs
   - How to add users to Google Workspace groups

3. **Known Issues & Workarounds**
   - Document any limitations discovered
   - Workarounds for common problems

4. **Security Validation Report**
   - Org policy test results
   - IAM permission test results
   - Recommendations for additional security controls

5. **Architecture Diagram (Updated)**
   - Network topology with actual deployed resources
   - Data flow diagrams
   - Security boundary documentation

---

## Success Criteria

Before marking workload testing complete, ensure:

- [ ] At least one VM deployed successfully in each project type
- [ ] GKE cluster deployed in both devops projects using correct subnets
- [ ] All 31 Google Workspace groups validated
- [ ] All 20 organization policies tested and confirmed working
- [ ] Centralized logging validated with queries from all projects
- [ ] Cloud NAT provides egress connectivity from private VMs
- [ ] IAP SSH access works to VMs without external IPs
- [ ] No Terraform drift detected (run `terraform plan`)
- [ ] All test resources cleaned up or documented
- [ ] All documentation deliverables completed

---

## Cleanup After Testing

Once validation is complete, remove test resources:

```bash
# Delete test VMs
gcloud compute instances delete test-app-vm \
  --project=pcc-prj-app-devtest \
  --zone=us-east4-a

# Delete test GKE cluster
gcloud container clusters delete test-gke-cluster \
  --project=pcc-prj-devops-nonprod \
  --region=us-east4

# Delete test BigQuery datasets
bq rm -r -f -d pcc-prj-data-devtest:test_dataset

# Delete test Cloud SQL instance
gcloud sql instances delete test-postgres \
  --project=pcc-prj-data-devtest

# Run terraform plan to confirm no drift
terraform plan
```

**Note:** Keep test service accounts and IAM bindings for ongoing validation.

---

## Next Steps After Workload Testing

1. **Production Readiness Review**
   - Review all test results with stakeholders
   - Address any issues discovered
   - Update architecture based on findings

2. **Production Deployment**
   - Deploy production GKE clusters in pcc-prj-devops-prod
   - Deploy production workloads in pcc-prj-app-prod
   - Configure production monitoring and alerting

3. **Per-Enterprise Rollout**
   - Create partner folders (pcc-fldr-pe-#####)
   - Deploy isolated projects per enterprise customer
   - Implement multi-tenancy controls

4. **Operational Handoff**
   - Train operations team on runbooks
   - Set up on-call rotation
   - Establish incident response procedures
