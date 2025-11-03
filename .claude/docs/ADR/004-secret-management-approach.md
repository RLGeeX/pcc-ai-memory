# ADR 004: Secret Management Approach

**Date**: 2025-10-24
**Status**: Accepted
**Decision Makers**: Lead Architect, Security Lead
**Consulted**: Google Cloud Security Best Practices, OWASP Secrets Management Guide

## Context

PortCo Connect (PCC) microservices require secure storage and access to sensitive credentials including database passwords, API keys, and connection strings. We need a secret management solution that balances security, operational simplicity, cost, and developer experience.

### Business Context
- Small team managing 7 microservices across 4 environments
- Security compliance requirements for customer data protection
- Need automated secret rotation without manual intervention
- Must support both Kubernetes workloads and Terraform-managed infrastructure
- Limited budget for enterprise secret management solutions

### Technical Requirements
1. **Secret Storage**: Encrypted at rest, auditable access
2. **Secret Rotation**: Automated rotation with minimal downtime
3. **Access Control**: Fine-grained IAM, principle of least privilege
4. **Integration**: Native GCP service integration, Kubernetes Workload Identity support
5. **Versioning**: Historical secret versions for rollback
6. **Cost**: Predictable, usage-based pricing
7. **Auditability**: Complete access logs for compliance

### Secret Management Options

**Option 1: Kubernetes Secrets**
- Storage: Base64-encoded, stored in etcd
- Rotation: Manual or custom controllers
- Access: RBAC-based
- Cost: Free (included with GKE)
- Encryption: At rest via etcd encryption

**Option 2: HashiCorp Vault**
- Storage: Backend-agnostic (GCS, disk, etc.)
- Rotation: Built-in dynamic secrets
- Access: Token-based, policies
- Cost: Enterprise license or self-hosted operational overhead
- Encryption: Application-level encryption

**Option 3: Google Secret Manager**
- Storage: Google-managed, encrypted at rest
- Rotation: Native rotation policies, Cloud Functions triggers
- Access: IAM-based, per-secret permissions
- Cost: $0.06 per 10,000 accesses, $0.40/month per secret
- Encryption: Google-managed encryption keys

**Option 4: Environment Variables**
- Storage: Unencrypted, visible in process listings
- Rotation: Requires application restart
- Access: No fine-grained control
- Cost: Free
- Encryption: None (unless container encrypted)

## Decision

We will use **Google Secret Manager** as the primary secret management solution for all PCC environments, with the following architecture:

### Secret Organization

**Per-Environment Secrets** (format: `{resource}-{environment}-{type}`):
- `alloydb-devtest-password`
- `alloydb-devtest-connection-string`
- `alloydb-devtest-connection-name`
- `alloydb-dev-password`
- `alloydb-staging-password`
- `alloydb-prod-password`
- (etc. for all environments and services)

**Replication Strategy**:
- **User-managed replication** (required): Organization policies forbid automatic (global) replication
- **Devtest/Dev**: No replication (single region: us-east4)
- **Staging/Prod**: User-managed replicas in us-east4 (primary) and us-central1 (secondary) per ADR-009
- **Rationale**: Compliance with org-level policies, regional control, cost optimization for non-prod

### Secret Types

**1. Database Credentials**
- **Password secrets**: Raw password strings
- **Connection string secrets**: Full PostgreSQL connection URI (includes password)
- **Connection name secrets**: AlloyDB connection identifier for Auth Proxy
- **Rotation**: 90-day automatic rotation

**2. API Keys** (future Phase 3+)
- **Service API keys**: External service credentials (SendGrid, etc.)
- **Rotation**: Service-specific policies

**3. OAuth Credentials** (future Phase 3+)
- **Client secrets**: Descope OAuth client secrets
- **Rotation**: Manual rotation on security events

### Access Control Pattern

**Per-Secret IAM Bindings** (NOT project-wide):
```hcl
# Grant specific service account access to specific secret
resource "google_secret_manager_secret_iam_member" "flyway_password_access" {
  project   = "pcc-prj-app-${var.environment}"
  secret_id = "alloydb-${var.environment}-password"
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:flyway-${var.environment}-sa@pcc-prj-app-${var.environment}.iam.gserviceaccount.com"
}
```

**Principle of Least Privilege**:
- Flyway SA: Access to password + connection name (migrations only)
- Client API SA: Access to connection string + connection name (runtime only)
- NO service accounts with project-wide Secret Manager access
- NO shared service accounts across services

### Secret Rotation Strategy

**Automated Rotation** (90 days):
```hcl
resource "google_secret_manager_secret" "alloydb_password" {
  secret_id = "alloydb-${var.environment}-password"

  rotation {
    rotation_period = "7776000s"  # 90 days
  }
}
```

**Rotation Triggers**:
- Cloud Function monitors rotation schedule
- Function generates new password via Cloud KMS
- Function updates AlloyDB password via Admin API
- Function creates new secret version
- Applications pick up new version on next fetch (cached for 5 minutes)

**Static Secrets** (NO rotation):
- Connection name secrets (reference only, not credentials)
- Cluster identifiers (immutable metadata)

## Rationale

### Advantages

1. **Native GCP Integration**
   - Workload Identity: Kubernetes pods access secrets via service account impersonation
   - No additional credentials management (no keys or tokens)
   - IAM-native access control (familiar to GCP admins)
   - Built-in Cloud Audit Logs for compliance

2. **Automated Secret Rotation**
   - 90-day rotation policies enforced automatically
   - Cloud Functions handle rotation logic
   - Zero-downtime rotation (versioned secrets)
   - Compliance-ready audit trail

3. **Fine-Grained Access Control**
   - Per-secret IAM bindings (not project-wide)
   - Separate access for different purposes (migrations vs runtime)
   - Service account isolation per microservice
   - Audit logs per secret access

4. **Operational Simplicity**
   - Google-managed service (no infrastructure to maintain)
   - High availability built-in (multi-region replication)
   - Terraform-native resource management
   - No additional licensing costs

5. **Cost-Effective**
   - $0.06 per 10,000 accesses (typical: $1-2/month per secret)
   - $0.40/month per active secret version
   - 6 free secret versions per secret
   - Phase 2 estimated cost: $15/month for all secrets across all environments

6. **Developer Experience**
   - Standard gcloud CLI for local development
   - Native SDKs for all languages (.NET, Python, Node.js)
   - Transparent caching (5-minute TTL reduces API calls)
   - Familiar Google Cloud patterns

### Trade-offs Accepted

1. **Vendor Lock-In**
   - Tied to Google Cloud ecosystem
   - Migration to another cloud requires rewrite
   - Acceptable: Platform is GCP-native, no multi-cloud requirement

2. **No Built-In Dynamic Secrets**
   - Unlike Vault, does not generate ephemeral credentials
   - Mitigation: 90-day rotation + versioning provides sufficient security
   - Alternative: Use Cloud KMS for generating dynamic tokens if needed

3. **API Rate Limits**
   - 1,500 access requests per minute per project
   - Mitigation: 5-minute client-side caching, connection pooling
   - Monitoring: Cloud Monitoring alerts on approaching limits

4. **No Secret Templating**
   - Cannot compose secrets from multiple sources in Secret Manager UI
   - Mitigation: Use Terraform to construct composite secrets
   - Example: Connection string includes password reference

## Consequences

### Positive

- **Security**: Encrypted at rest, automatic rotation, fine-grained IAM
- **Compliance**: Complete audit trail, versioned secrets, rotation policies
- **Reliability**: Google-managed HA, multi-region replication
- **Cost**: Predictable, low monthly cost (~$15/month Phase 2)
- **Developer Experience**: Native gcloud CLI, familiar patterns

### Negative

- **GCP Dependency**: Cannot migrate to AWS/Azure without rewrite
- **Learning Curve**: Team must learn Secret Manager patterns
- **Initial Setup**: Terraform boilerplate for each secret
- **Caching Complexity**: Must manage 5-minute cache TTL in application code

### Mitigation Strategies

1. **Secret Manager Module**
   - Reusable Terraform module: `pcc-tf-library/modules/secret-manager`
   - DRY principle: Define secrets once, reuse across environments
   - Automated IAM binding generation

2. **Caching Best Practices**
   - Document 5-minute cache TTL in application guides
   - Connection pooling to minimize secret fetches
   - Graceful secret refresh without connection drops

3. **Rotation Testing**
   - Test rotation in devtest environment first
   - Validate application behavior during rotation
   - Document emergency rollback procedures (previous secret version)

4. **Cost Monitoring**
   - Budget alert: $50/month threshold (3x expected cost)
   - Monitor access patterns via Cloud Monitoring
   - Optimize caching if costs increase

## Alternatives Considered

### Alternative 1: Kubernetes Secrets
**Rejected because:**
- Base64 encoding is NOT encryption
- No automatic rotation (requires custom controllers)
- etcd encryption must be manually configured
- No fine-grained IAM (RBAC only)
- No built-in audit logs
- Secrets visible in kubectl output
- **Quote from OWASP**: "Kubernetes Secrets are not designed for secure storage"

### Alternative 2: HashiCorp Vault
**Rejected because:**
- Enterprise license cost: $150-300/month (prohibitive for small team)
- Self-hosted operational overhead: HA cluster, upgrades, backups
- Additional infrastructure to secure (Vault itself needs secret storage)
- Learning curve: New tool outside GCP ecosystem
- Integration complexity: Custom auth methods, policy management
- **Trade-off not justified**: Secret Manager provides 90% of Vault features at 10% of cost

### Alternative 3: Environment Variables in Docker/K8s
**Rejected because:**
- Unencrypted: Visible in `docker inspect`, `kubectl describe`
- No rotation: Requires pod restart
- No audit trail: Cannot track who accessed secrets
- Process listings expose secrets: `ps aux` shows env vars
- **Security antipattern**: OWASP explicitly warns against env var secrets

### Alternative 4: Encrypted ConfigMaps with KMS
**Rejected because:**
- Custom encryption logic prone to errors
- No automatic rotation
- Increased operational complexity
- No IAM integration
- Reinventing Secret Manager capabilities
- **Maintenance burden**: Team must maintain encryption code

### Alternative 5: Application-Level Secret Storage
**Rejected because:**
- Secrets stored in application database (chicken-and-egg problem)
- Application code has secret management responsibility
- No centralized rotation
- Difficult to audit
- Breaks separation of concerns
- **Architecture smell**: Application should consume secrets, not manage them

## Implementation Notes

### Terraform Module Structure

**Module**: `pcc-tf-library/modules/secret-manager`

```hcl
variable "secret_id" {
  description = "Unique secret identifier (e.g., alloydb-devtest-password)"
  type        = string
}

variable "secret_data" {
  description = "Secret value to store"
  type        = string
  sensitive   = true
}

variable "rotation_period" {
  description = "Rotation period in seconds (90 days = 7776000s)"
  type        = string
  default     = null  # No rotation by default
}

variable "replica_locations" {
  description = "List of regions for user-managed replication (empty = no replication)"
  type        = list(string)
  default     = []  # No replication by default (devtest/dev)
}

resource "google_secret_manager_secret" "secret" {
  secret_id = var.secret_id
  project   = var.project_id

  # User-managed replication (required by org policy)
  # Devtest/dev: single region only
  # Staging/prod: us-east4 + us-central1
  replication {
    dynamic "user_managed" {
      for_each = length(var.replica_locations) > 0 ? [1] : []
      content {
        dynamic "replicas" {
          for_each = var.replica_locations
          content {
            location = replicas.value
          }
        }
      }
    }

    # Single region (no replication) - for devtest/dev
    dynamic "auto" {
      for_each = length(var.replica_locations) == 0 ? [1] : []
      content {}
    }
  }

  dynamic "rotation" {
    for_each = var.rotation_period != null ? [1] : []
    content {
      rotation_period = var.rotation_period
    }
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "secret_version" {
  secret      = google_secret_manager_secret.secret.id
  secret_data = var.secret_data
}
```

### Application Integration

**.NET Example** (Phase 3):
```csharp
using Google.Cloud.SecretManager.V1;

var client = SecretManagerServiceClient.Create();
var secretVersionName = new SecretVersionName(
    projectId: "pcc-prj-app-devtest",
    secretId: "alloydb-devtest-connection-string",
    secretVersionId: "latest"
);

var response = await client.AccessSecretVersionAsync(secretVersionName);
var connectionString = response.Payload.Data.ToStringUtf8();

// Cache for 5 minutes
_memoryCache.Set("db-connection-string", connectionString, TimeSpan.FromMinutes(5));
```

**Kubernetes Example** (Flyway Job):
```yaml
initContainers:
- name: fetch-secrets
  image: google/cloud-sdk:alpine
  command:
  - /bin/sh
  - -c
  - |
    gcloud secrets versions access latest \
      --secret=alloydb-${ENVIRONMENT}-password \
      --project=pcc-prj-app-${ENVIRONMENT} \
      > /secrets/password.txt
  volumeMounts:
  - name: secrets
    mountPath: /secrets

volumes:
- name: secrets
  emptyDir:
    medium: Memory  # Store in memory, not disk
```

### Secret Naming Convention

**Pattern**: `{resource}-{environment}-{type}`

Examples:
- `alloydb-devtest-password` ✅
- `alloydb-prod-connection-string` ✅
- `sendgrid-staging-api-key` ✅ (future)
- `descope-prod-client-secret` ✅ (future)

**Avoid**:
- `db-password` ❌ (no resource or environment)
- `prod-alloydb-password` ❌ (environment should be second)
- `AlloyDB_Devtest_Password` ❌ (use kebab-case, not PascalCase)

### Rotation Implementation (Phase 3)

**Cloud Function** (TypeScript):
```typescript
import { SecretManagerServiceClient } from '@google-cloud/secret-manager';
import { AlloyDBAdmin } from '@google-cloud/alloydb';

export async function rotateAlloyDBPassword(event: any): Promise<void> {
  const { secretId, projectId } = event;

  // Generate new password
  const newPassword = generateSecurePassword(24);

  // Update AlloyDB
  const alloydb = new AlloyDBAdmin();
  await alloydb.updateUserPassword({
    cluster: `pcc-alloydb-${env}`,
    user: 'postgres',
    password: newPassword
  });

  // Create new secret version
  const secretManager = new SecretManagerServiceClient();
  await secretManager.addSecretVersion({
    parent: `projects/${projectId}/secrets/${secretId}`,
    payload: { data: Buffer.from(newPassword) }
  });
}
```

### Emergency Rollback

**Rollback to previous secret version**:
```bash
# List versions
gcloud secrets versions list alloydb-devtest-password \
  --project=pcc-prj-app-devtest

# Access previous version (e.g., version 2 instead of 3)
gcloud secrets versions access 2 \
  --secret=alloydb-devtest-password \
  --project=pcc-prj-app-devtest
```

**Application rollback**:
- Update secret version reference: `latest` → specific version number
- Restart application pods
- Verify connectivity
- Update AlloyDB password to match secret version

## References

- [Google Secret Manager Documentation](https://cloud.google.com/secret-manager/docs)
- [OWASP Secrets Management Guide](https://owasp.org/www-community/vulnerabilities/Use_of_hard-coded_password)
- [Phase 2.6: Create Secrets Configuration](./../plans/devtest-deployment/phase-2.6-create-secrets-configuration.md)
- [Phase 2.7: Deploy Secrets](./../plans/devtest-deployment/phase-2.7-deploy-secrets.md)
- [ADR-003: AlloyDB HA Strategy](./003-alloydb-ha-strategy.md)
- [ADR-009: Regional Deployment Strategy](./009-regional-deployment-strategy.md) (us-east4 primary, us-central1 secondary)

## Approval

- [x] Lead Architect Approval
- [x] Security Lead Approval
- [ ] Compliance Team Review
- [ ] Dev Partner Approval

---

*This ADR establishes the secret management strategy for all PCC environments. All secrets must be stored in Secret Manager with appropriate IAM bindings and rotation policies.*
