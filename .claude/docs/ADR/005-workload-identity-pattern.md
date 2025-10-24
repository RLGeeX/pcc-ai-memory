# ADR 005: Workload Identity Pattern

**Date**: 2025-10-24
**Status**: Accepted
**Decision Makers**: Lead Architect, Security Lead, Platform Team
**Consulted**: Google Cloud Security Best Practices, CIS GKE Benchmark

## Context

PortCo Connect (PCC) runs workloads in Google Kubernetes Engine (GKE) that need to access Google Cloud services such as AlloyDB, Secret Manager, and Cloud Storage. We must establish a secure authentication pattern that eliminates long-lived credentials while maintaining operational simplicity.

### Business Context
- 7 microservices running in GKE across 4 environments
- Flyway migration jobs accessing AlloyDB and Secret Manager
- Future: application pods accessing databases, Pub/Sub, Cloud Storage
- Security compliance requirements: no long-lived credentials, full audit trail
- Small team: minimal operational overhead for credential management

### Security Challenges
1. **Service Account Keys Are Risky**:
   - Long-lived credentials (valid until explicitly revoked)
   - Can be exfiltrated from pods or version control
   - Difficult to rotate without application downtime
   - No automatic expiration

2. **Kubernetes Service Accounts ≠ Google Service Accounts**:
   - K8s ServiceAccounts are for RBAC within cluster
   - Google ServiceAccounts are for IAM within GCP
   - Must bridge the two identity systems

3. **Traditional Metadata Server Approach**:
   - All pods on a node share the node's service account
   - No pod-level isolation
   - Requires pod-to-pod network policies to prevent lateral movement

### Authentication Options

**Option 1: Service Account JSON Keys**
- Method: Mount key file as Kubernetes Secret
- Credential Type: Long-lived (manually managed)
- Rotation: Manual, requires pod restart
- Security: High risk of key theft
- Audit: Only initial key creation logged

**Option 2: Node Service Account**
- Method: GKE node uses single service account
- Credential Type: Short-lived (GCE metadata server)
- Rotation: Automatic via metadata server
- Security: All pods share node identity (no isolation)
- Audit: Cannot distinguish between pods

**Option 3: Workload Identity**
- Method: K8s ServiceAccount impersonates Google ServiceAccount
- Credential Type: Short-lived tokens (auto-refreshed)
- Rotation: Automatic every hour
- Security: Pod-level isolation, no long-lived credentials
- Audit: Per-pod access logs

**Option 4: Service Mesh (Istio) mTLS + External IdP**
- Method: Service mesh issues certificates, exchanges for GCP token
- Credential Type: Short-lived certificates
- Rotation: Automatic via mesh CA
- Security: Strong pod identity, mTLS encryption
- Audit: Full service mesh telemetry
- Complexity: Requires Istio installation, learning curve

## Decision

We will use **Workload Identity** as the standard authentication pattern for all GKE workloads accessing Google Cloud services, with the following architecture:

### Workload Identity Architecture

**Three-Layer Binding**:
```
Kubernetes Pod (app container)
  ↓ uses
Kubernetes ServiceAccount (flyway-sa)
  ↓ annotated with
Google ServiceAccount (flyway-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com)
  ↓ granted
IAM Permissions (secretAccessor, alloydb.client)
```

### Implementation Pattern

**1. GKE Cluster Configuration**
```bash
# Enable Workload Identity at cluster level
gcloud container clusters update <CLUSTER> \
  --workload-pool=pcc-prj-app-${ENVIRONMENT}.svc.id.goog \
  --region=us-east4 \
  --project=pcc-prj-app-${ENVIRONMENT}
```

**2. Create Google Service Account** (Terraform)
```hcl
resource "google_service_account" "flyway" {
  project      = "pcc-prj-app-${var.environment}"
  account_id   = "flyway-${var.environment}-sa"
  display_name = "Flyway Database Migration Service Account"
}
```

**3. Grant IAM Permissions** (Terraform)
```hcl
# Grant access to specific secrets
resource "google_secret_manager_secret_iam_member" "flyway_password" {
  secret_id = "alloydb-${var.environment}-password"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.flyway.email}"
}

# Grant access to AlloyDB cluster
resource "google_alloydb_cluster_iam_member" "flyway_cluster" {
  cluster = "pcc-alloydb-${var.environment}"
  role    = "roles/alloydb.client"
  member  = "serviceAccount:${google_service_account.flyway.email}"
}
```

**4. Bind K8s ServiceAccount to Google ServiceAccount** (Terraform)
```hcl
resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = google_service_account.flyway.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:pcc-prj-app-${var.environment}.svc.id.goog[flyway/flyway-sa]"
}
```

**5. Create Kubernetes ServiceAccount** (Kubernetes manifest)
```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: flyway-sa
  namespace: flyway
  annotations:
    iam.gke.io/gcp-service-account: flyway-${ENVIRONMENT}-sa@pcc-prj-app-${ENVIRONMENT}.iam.gserviceaccount.com
```

**6. Reference ServiceAccount in Pod** (Kubernetes manifest)
```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: flyway-migrate
  namespace: flyway
spec:
  template:
    spec:
      serviceAccountName: flyway-sa  # This line enables Workload Identity
      containers:
      - name: flyway
        image: flyway/flyway:latest
```

### Naming Convention

**Google Service Accounts**:
- Format: `{purpose}-${environment}-sa`
- Examples: `flyway-devtest-sa`, `client-api-prod-sa`, `task-tracker-staging-sa`

**Kubernetes ServiceAccounts**:
- Format: `{purpose}-sa`
- Examples: `flyway-sa`, `client-api-sa`, `task-tracker-sa`
- Namespace: Each microservice gets its own namespace

**Workload Identity Binding**:
- Format: `serviceAccount:{PROJECT}.svc.id.goog[{NAMESPACE}/{K8S_SA}]`
- Example: `serviceAccount:pcc-prj-app-devtest.svc.id.goog[flyway/flyway-sa]`

### Security Posture

**No Long-Lived Credentials**:
- No JSON key files in version control
- No JSON key files in Kubernetes Secrets
- No JSON key files mounted in pods

**Short-Lived Tokens**:
- Tokens valid for 1 hour
- Auto-refreshed by GKE mutating webhook
- Cannot be exfiltrated and reused long-term

**Pod-Level Isolation**:
- Each pod can have different Google ServiceAccount
- Blast radius limited to single pod
- Network policies can enforce pod-to-pod access

**Audit Trail**:
- Cloud Audit Logs show pod identity (via K8s ServiceAccount)
- Can trace specific pod accessing specific resource
- Logs include K8s namespace, pod name, service account

## Rationale

### Advantages

1. **Eliminates Long-Lived Credentials**
   - No JSON key files to manage, rotate, or secure
   - No risk of keys committed to version control
   - No key exfiltration risk (tokens expire in 1 hour)
   - CIS GKE Benchmark compliance

2. **Automatic Token Rotation**
   - GKE mutating webhook injects short-lived tokens
   - Tokens auto-refresh every hour
   - No application code changes required
   - No manual rotation procedures

3. **Fine-Grained Access Control**
   - Each pod can have different permissions
   - Separate Google ServiceAccounts for Flyway vs applications
   - IAM bindings are per-service-account (not per-node)
   - Principle of least privilege enforced

4. **Operational Simplicity**
   - Native GKE feature (no additional infrastructure)
   - Transparent to application code (uses Application Default Credentials)
   - Standard gcloud SDK works automatically
   - No custom authentication logic

5. **Complete Audit Trail**
   - Cloud Audit Logs show K8s identity (namespace + pod + serviceaccount)
   - Can trace which pod accessed which secret at which time
   - Compliance-ready logging
   - Integration with Security Command Center

6. **Multi-Tenancy Support**
   - Different teams can manage different namespaces
   - Namespace-level Google ServiceAccount isolation
   - Clear security boundaries
   - Future-proof for team growth

### Trade-offs Accepted

1. **GKE Dependency**
   - Workload Identity is GKE-specific (not standard Kubernetes)
   - Cannot use on non-GKE clusters (EKS, AKS, on-prem)
   - Acceptable: Platform is GCP-native, no multi-cloud requirement

2. **Initial Setup Complexity**
   - Requires cluster configuration, IAM binding, annotation
   - More steps than mounting a key file
   - Mitigation: Terraform automates all steps, reusable modules

3. **Debugging Challenges**
   - Token errors can be cryptic ("permission denied" without context)
   - Must check cluster config, IAM binding, annotation
   - Mitigation: Clear documentation, troubleshooting runbooks

4. **Namespace Coupling**
   - Workload Identity binding includes K8s namespace
   - Moving pod to different namespace breaks authentication
   - Acceptable: Namespaces map to microservices, rarely change

## Consequences

### Positive

- **Security**: No long-lived credentials, short-lived tokens, full audit trail
- **Compliance**: CIS GKE Benchmark 5.2.1 "Minimize the admission of containers with capabilities assigned"
- **Developer Experience**: Application Default Credentials "just work"
- **Operational**: Zero manual credential rotation
- **Cost**: Free (included with GKE)

### Negative

- **GKE Lock-In**: Cannot migrate to non-GKE cluster without rewrite
- **Initial Complexity**: More setup steps than key files
- **Debugging**: Token errors require understanding Workload Identity flow
- **Documentation**: Must train team on Workload Identity concepts

### Mitigation Strategies

1. **Terraform Automation**
   - Reusable module: `pcc-tf-library/modules/workload-identity-binding`
   - Encapsulates all IAM binding complexity
   - DRY principle: define once, reuse across services

2. **Clear Documentation**
   - Step-by-step setup guide in each infra repo
   - Troubleshooting runbook for common errors
   - Diagram showing authentication flow
   - Examples for each microservice

3. **Validation Scripts**
   - Script to verify cluster Workload Identity enabled
   - Script to verify K8s ServiceAccount annotation
   - Script to verify Google ServiceAccount IAM binding
   - Script to test authentication from pod

4. **Monitoring and Alerts**
   - Alert on authentication failures (Cloud Monitoring)
   - Dashboard showing token refresh rate
   - Logs for debugging authentication issues

## Alternatives Considered

### Alternative 1: Service Account JSON Keys
**Rejected because:**
- Long-lived credentials are security antipattern
- Manual rotation required (operational burden)
- Key theft risk (exfiltration from pods or version control)
- CIS GKE Benchmark explicitly warns against keys
- **CIS 5.2.2**: "Prefer using Workload Identity over key-based authentication"
- Google recommendation: "Workload Identity is the recommended way..."

### Alternative 2: Node Service Account
**Rejected because:**
- All pods on node share same identity (no isolation)
- Cannot grant different permissions to different pods
- Blast radius = entire node
- Cannot audit which pod accessed which resource
- **Security smell**: Violates principle of least privilege

### Alternative 3: GKE Metadata Concealment + Node SA
**Rejected because:**
- Concealment protects metadata server, but still no pod isolation
- All pods still share node identity
- Complex network policies required to prevent lateral movement
- More operational complexity than Workload Identity
- **Partial solution**: Doesn't solve core multi-tenancy problem

### Alternative 4: Service Mesh (Istio) with External IdP
**Rejected because:**
- Requires Istio installation (significant operational overhead)
- Team unfamiliar with Istio (learning curve)
- Over-engineering for current scale (7 microservices)
- Workload Identity provides 90% of benefit with 10% of complexity
- **Future consideration**: Revisit when scale justifies service mesh

### Alternative 5: Custom Authentication Sidecar
**Rejected because:**
- Reinventing Workload Identity functionality
- Maintenance burden (custom code to maintain)
- Security risk (custom crypto code prone to errors)
- No audit trail integration
- **Antipattern**: Use platform-provided solution, don't build your own

## Implementation Notes

### Terraform Module Structure

**Module**: `pcc-tf-library/modules/workload-identity-binding`

```hcl
variable "google_service_account_email" {
  description = "Email of Google ServiceAccount to bind"
  type        = string
}

variable "k8s_namespace" {
  description = "Kubernetes namespace"
  type        = string
}

variable "k8s_service_account_name" {
  description = "Kubernetes ServiceAccount name"
  type        = string
}

variable "project_id" {
  description = "GCP project ID"
  type        = string
}

resource "google_service_account_iam_member" "workload_identity" {
  service_account_id = "projects/${var.project_id}/serviceAccounts/${var.google_service_account_email}"
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[${var.k8s_namespace}/${var.k8s_service_account_name}]"
}

output "k8s_service_account_annotation" {
  description = "Annotation to add to Kubernetes ServiceAccount"
  value       = "iam.gke.io/gcp-service-account=${var.google_service_account_email}"
}
```

### Validation Script

**Script**: `pcc-app-shared-infra/scripts/validate-workload-identity.sh`

```bash
#!/bin/bash
set -e

NAMESPACE=$1
K8S_SA=$2
GOOGLE_SA=$3
PROJECT_ID=$4

echo "Validating Workload Identity setup..."

# 1. Check GKE cluster has Workload Identity enabled
WORKLOAD_POOL=$(gcloud container clusters describe <CLUSTER> \
  --region=us-east4 \
  --project=$PROJECT_ID \
  --format="value(workloadIdentityConfig.workloadPool)")

if [ "$WORKLOAD_POOL" == "${PROJECT_ID}.svc.id.goog" ]; then
  echo "✅ Cluster Workload Identity enabled"
else
  echo "❌ Cluster Workload Identity NOT enabled"
  exit 1
fi

# 2. Check K8s ServiceAccount annotation
ANNOTATION=$(kubectl get serviceaccount $K8S_SA -n $NAMESPACE \
  -o jsonpath='{.metadata.annotations.iam\.gke\.io/gcp-service-account}')

if [ "$ANNOTATION" == "$GOOGLE_SA" ]; then
  echo "✅ K8s ServiceAccount annotation correct"
else
  echo "❌ K8s ServiceAccount annotation missing or incorrect"
  exit 1
fi

# 3. Check Google ServiceAccount IAM binding
MEMBER="serviceAccount:${PROJECT_ID}.svc.id.goog[${NAMESPACE}/${K8S_SA}]"
BINDING=$(gcloud iam service-accounts get-iam-policy $GOOGLE_SA \
  --project=$PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:${MEMBER}" \
  --format="value(bindings.role)")

if [[ "$BINDING" == *"workloadIdentityUser"* ]]; then
  echo "✅ Google ServiceAccount IAM binding correct"
else
  echo "❌ Google ServiceAccount IAM binding missing"
  exit 1
fi

echo ""
echo "✅ Workload Identity setup validated successfully"
```

### Troubleshooting Guide

**Error: "Permission denied" accessing Secret Manager**

1. Verify K8s ServiceAccount annotation:
```bash
kubectl describe serviceaccount flyway-sa -n flyway | grep iam.gke.io
```

2. Verify Google ServiceAccount IAM binding:
```bash
gcloud iam service-accounts get-iam-policy \
  flyway-devtest-sa@pcc-prj-app-devtest.iam.gserviceaccount.com \
  --project=pcc-prj-app-devtest
```

3. Verify secret IAM binding:
```bash
gcloud secrets get-iam-policy alloydb-devtest-password \
  --project=pcc-prj-app-devtest | grep flyway
```

4. Test from pod:
```bash
kubectl exec -n flyway -it <POD_NAME> -- /bin/sh
gcloud auth list  # Should show Google ServiceAccount
gcloud secrets versions access latest --secret=alloydb-devtest-password
```

**Error: "Workload Identity pool not enabled"**

1. Check cluster Workload Identity config:
```bash
gcloud container clusters describe <CLUSTER> \
  --region=us-east4 \
  --project=pcc-prj-app-devtest \
  --format="value(workloadIdentityConfig.workloadPool)"
```

2. Enable if missing (15-20 min):
```bash
gcloud container clusters update <CLUSTER> \
  --workload-pool=pcc-prj-app-devtest.svc.id.goog \
  --region=us-east4 \
  --project=pcc-prj-app-devtest
```

### Migration from Keys to Workload Identity

**Steps** (if migrating existing workload):
1. Create Google ServiceAccount (if doesn't exist)
2. Grant IAM permissions to Google ServiceAccount
3. Enable Workload Identity on cluster
4. Create Workload Identity IAM binding
5. Add annotation to K8s ServiceAccount
6. Remove JSON key from Kubernetes Secret
7. Restart pods to pick up new authentication
8. Verify pods can access resources
9. Delete JSON key from Google Cloud

## References

- [Google Workload Identity Documentation](https://cloud.google.com/kubernetes-engine/docs/how-to/workload-identity)
- [CIS GKE Benchmark](https://www.cisecurity.org/benchmark/kubernetes)
- [Phase 2.10: Create Flyway Configuration](./../plans/devtest-deployment/phase-2.10-create-flyway-configuration.md)
- [Phase 2.11: Deploy Flyway Resources](./../plans/devtest-deployment/phase-2.11-deploy-flyway-resources.md)
- [ADR-004: Secret Management Approach](./004-secret-management-approach.md)

## Approval

- [x] Lead Architect Approval
- [x] Security Lead Approval
- [x] Platform Team Approval
- [ ] Dev Partner Approval

---

*This ADR establishes Workload Identity as the mandatory authentication pattern for all GKE workloads. Service account JSON keys are explicitly prohibited.*
