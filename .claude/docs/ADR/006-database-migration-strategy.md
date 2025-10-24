# ADR 006: Database Migration Strategy

**Date**: 2025-10-24
**Status**: Accepted
**Decision Makers**: Lead Architect, Database Lead, Platform Team
**Consulted**: Flyway Best Practices, Kubernetes Patterns

## Context

PortCo Connect (PCC) requires a reliable, auditable approach to managing database schema changes across 4 environments (devtest, dev, staging, prod) and 7 microservices. We need a migration strategy that supports version control, rollback, multi-environment deployment, and CI/CD integration.

### Business Context
- 7 microservices with independent databases (one DB per service)
- 4 environments requiring consistent schema state
- Small team with limited database administration expertise
- Must support CI/CD pipelines for automated deployments
- Compliance requirements for schema change audit trail

### Technical Requirements
1. **Version Control**: SQL scripts tracked in Git alongside application code
2. **Idempotency**: Migrations can run multiple times safely
3. **Auditability**: Complete history of who changed what and when
4. **Rollback**: Ability to revert schema changes if deployment fails
5. **Multi-Environment**: Same migrations run consistently across all environments
6. **CI/CD Integration**: Automated migration during deployment pipeline
7. **AlloyDB Compatibility**: Works with PostgreSQL-compatible AlloyDB

### Database Migration Options

**Option 1: Flyway (JVM-based)**
- Language: SQL (native) + Java migrations (optional)
- Versioning: Sequential version numbers (V1__, V2__, etc.)
- Execution: Standalone CLI, Docker, Java library
- Rollback: Manual undo scripts (U1__, U2__, etc.)
- Community: Large, mature, widely adopted

**Option 2: Liquibase (JVM-based)**
- Language: XML, JSON, YAML, SQL
- Versioning: Changesets with unique IDs
- Execution: Standalone CLI, Docker, Java library
- Rollback: Automatic rollback generation
- Community: Large, enterprise-focused

**Option 3: Alembic (Python)**
- Language: Python + SQL
- Versioning: Sequential revisions (downgrade support)
- Execution: Python CLI
- Rollback: Downgrade scripts
- Community: Popular in Python/Django ecosystem

**Option 4: golang-migrate (Go)**
- Language: SQL (native) + Go migrations
- Versioning: Up/down migration pairs
- Execution: Go CLI or library
- Rollback: Down migrations
- Community: Growing, used by Go projects

**Option 5: Custom SQL Scripts + Shell**
- Language: SQL + Bash
- Versioning: Manual numbering
- Execution: psql + custom orchestration
- Rollback: Manual undo scripts
- Community: N/A (DIY)

## Decision

We will use **Flyway Community Edition** with the following architecture:

### Execution Pattern: Kubernetes Job

**Kubernetes Job** (NOT Cloud Run, NOT local CLI):
- One-time migration job per deployment
- Runs in GKE cluster (same VPC as AlloyDB)
- Uses Workload Identity for authentication
- Fails fast if migration errors occur
- Leaves audit trail in cluster logs

### Flyway Configuration

**Migration File Naming**:
- Format: `V{version}__{description}.sql`
- Examples: `V1__create_schema.sql`, `V2__create_users_table.sql`, `V3__add_email_index.sql`
- Sequential numbering (enforced by Flyway)

**Migration Storage**:
- ConfigMap: Small SQL scripts (< 1MB total)
- Cloud Storage: Large migrations (data imports, > 1MB)
- Git: Source of truth for all migration files

**Execution Flow**:
```
1. Init Container: Fetch database password from Secret Manager
2. Auth Proxy Sidecar: Establish AlloyDB connection
3. Flyway Container: Run migrations via localhost:5432
4. Job Status: Success (0) or Failure (non-zero exit code)
```

### Architecture Components

**1. Kubernetes Namespace**: `flyway` (isolated from application namespaces)

**2. Kubernetes ServiceAccount**: `flyway-sa` (Workload Identity enabled)

**3. ConfigMap**: `flyway-config`
   - Flyway configuration (flyway.conf)
   - V1__, V2__, V3__ SQL scripts
   - Baselined schema version

**4. Kubernetes Job**: `flyway-migrate`
   - Init container: Fetch secrets
   - Sidecar: AlloyDB Auth Proxy
   - Main container: Flyway CLI

**5. Flyway Schema History Table**: `flyway_schema_history`
   - Tracks applied migrations
   - Prevents duplicate execution
   - Stores checksums for validation

### Migration Workflow

**Development** (devtest):
```bash
1. Developer writes SQL migration: V3__add_email_index.sql
2. Add migration to ConfigMap in Git
3. Deploy ConfigMap to devtest: kubectl apply -f configmap.yaml
4. Run migration job: kubectl apply -f job.yaml
5. Verify migration: kubectl logs job/flyway-migrate -c flyway
6. Test application with new schema
```

**CI/CD Pipeline** (dev → staging → prod):
```bash
1. Git push triggers Cloud Build
2. Build: Update ConfigMap with new migrations
3. Deploy: Apply ConfigMap + Job to environment
4. Validate: Check job completion status
5. Promote: If success, continue to next environment
6. Rollback: If failure, trigger rollback job
```

### Rollback Strategy

**Undo Migrations** (manual):
- File naming: `U{version}__{description}.sql`
- Example: `U3__remove_email_index.sql` (undoes V3)
- Execution: Manual kubectl apply with undo ConfigMap
- Use case: Emergency rollback during incident

**Version Rollback** (automatic):
- Flyway `baseline` command sets starting version
- Deploy previous ConfigMap version (Git revert)
- Flyway skips already-applied migrations
- Use case: Deployment rollback in staging

**Data Rollback** (backup restore):
- AlloyDB automated backups (daily, 7-day retention)
- Point-in-time recovery (PITR) for production
- Use case: Data corruption during migration

## Rationale

### Advantages

1. **Native SQL**
   - Developers write standard PostgreSQL SQL
   - No DSL to learn (unlike Liquibase XML)
   - Full PostgreSQL feature access (no abstraction layer)
   - Easy to review in pull requests

2. **Mature and Stable**
   - Flyway: 10+ years in production use
   - Large community, extensive documentation
   - Proven at scale (used by major enterprises)
   - Predictable behavior, minimal surprises

3. **Kubernetes-Native**
   - Runs in GKE (same VPC as AlloyDB, low latency)
   - Uses Workload Identity (no keys)
   - Integrated with cluster logs and monitoring
   - Fail-fast behavior (job exit code)

4. **Version Control**
   - SQL files in Git (same repo as application)
   - Code review for schema changes
   - Git history = schema change audit trail
   - Easy to see what changed between versions

5. **Audit Trail**
   - `flyway_schema_history` table tracks all migrations
   - Kubernetes Job logs show execution details
   - Cloud Audit Logs show who triggered job
   - Complete audit chain for compliance

6. **CI/CD Integration**
   - Job-based execution fits CI/CD pattern
   - Exit code indicates success/failure
   - Can gate deployment on migration success
   - Automated testing in dev environment

### Trade-offs Accepted

1. **No Automatic Rollback**
   - Must write manual undo scripts (U__ files)
   - Acceptable: Prefer forward-fixing over rollback
   - Mitigation: Test thoroughly in dev before staging

2. **JVM Dependency**
   - Flyway requires Java Runtime
   - Acceptable: Flyway Docker image is 200MB (manageable)
   - Mitigation: Use Alpine-based image to minimize size

3. **Sequential Versioning**
   - V1, V2, V3... must be applied in order
   - Conflicts if multiple developers create V3 simultaneously
   - Mitigation: Use timestamp-based versioning (V20250124120000)

4. **ConfigMap Size Limit**
   - ConfigMap limited to 1MB
   - Large data migrations don't fit
   - Mitigation: Store large migrations in Cloud Storage, reference from ConfigMap

5. **Manual Job Trigger**
   - Migration doesn't run automatically with application deployment
   - Must explicitly run kubectl apply job.yaml
   - Acceptable: Explicit migration gives control over timing
   - Mitigation: CI/CD pipeline can automate job creation

## Consequences

### Positive

- **Reliability**: Proven migration tool with 10+ years production use
- **Simplicity**: Native SQL, no DSL, easy to understand
- **Security**: Workload Identity, no keys, Secret Manager integration
- **Auditability**: Complete change history in Git + flyway_schema_history
- **Observability**: Kubernetes logs, job status, Cloud Monitoring integration

### Negative

- **Manual Rollback**: No automatic undo (must write U__ scripts)
- **JVM Overhead**: Flyway requires Java Runtime (200MB container)
- **Learning Curve**: Team must learn Flyway patterns and conventions
- **Versioning Conflicts**: Potential for V__ number conflicts in parallel development

### Mitigation Strategies

1. **Flyway Module in pcc-tf-library**
   - Reusable Kubernetes manifests
   - Standardized ConfigMap structure
   - Consistent job configuration
   - DRY principle across microservices

2. **Migration Testing**
   - All migrations tested in devtest first
   - Dev environment validates production-like behavior
   - Staging environment final validation before prod
   - Pre-production migration dry-run

3. **Rollback Procedures**
   - Document rollback steps per migration
   - Store undo scripts in Git (U__ files)
   - Backup database before risky migrations
   - Practice rollback in devtest environment

4. **Timestamp-Based Versioning**
   - Recommend: V20250124120000__description.sql
   - Avoids conflicts in parallel development
   - Chronological ordering
   - Unique across developers

## Alternatives Considered

### Alternative 1: Liquibase
**Rejected because:**
- XML/YAML/JSON DSL adds complexity
- Steeper learning curve than Flyway
- Less readable in code reviews
- No significant advantage over Flyway for SQL-centric migrations
- **Quote from comparison**: "Flyway is simpler if you're primarily using SQL"

### Alternative 2: Alembic (Python)
**Rejected because:**
- Platform is .NET/Go-centric (not Python)
- Team unfamiliar with Alembic
- Smaller community than Flyway
- Less mature PostgreSQL support
- Would require Python in CI/CD pipeline
- **Mismatch**: Wrong tool for the tech stack

### Alternative 3: golang-migrate
**Rejected because:**
- Less mature than Flyway (newer project)
- Smaller community and ecosystem
- Fewer integrations (no native Kubernetes Job pattern)
- Team lacks Go expertise for customization
- **Insufficient advantage**: Not compelling enough to justify learning curve

### Alternative 4: Custom Shell Scripts + psql
**Rejected because:**
- Reinventing Flyway functionality
- No versioning, checksum validation, or audit trail
- Error-prone (easy to miss migrations or run duplicates)
- Maintenance burden (custom orchestration code)
- **Antipattern**: Use proven tool, don't build your own

### Alternative 5: Cloud Run for Migrations
**Rejected because:**
- Cloud Run is outside GKE VPC (requires VPC connector)
- Higher latency to AlloyDB
- Additional IAM complexity (Cloud Run SA + Workload Identity)
- Kubernetes Job is more natural in GKE-centric platform
- **Consistency**: Keep migrations in same execution environment as apps

### Alternative 6: Application-Embedded Migrations
**Rejected because:**
- Migrations run on application startup (delays startup, scales poorly)
- Multiple replicas can race to apply same migration
- No separation of concerns (application vs infrastructure)
- Difficult to run migrations independently of app deployment
- **Architecture smell**: Database schema is infrastructure concern, not application concern

## Implementation Notes

### ConfigMap Structure

**File**: `pcc-app-shared-infra/flyway/configmap.yaml`

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: flyway-config
  namespace: flyway
data:
  flyway.conf: |
    flyway.url=jdbc:postgresql://localhost:5432/client_api_db
    flyway.user=postgres
    flyway.password=${FLYWAY_PASSWORD}  # Injected from Secret Manager
    flyway.locations=filesystem:/flyway/sql
    flyway.baselineOnMigrate=true
    flyway.validateOnMigrate=true
    flyway.table=flyway_schema_history

  V1__create_schema.sql: |
    CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
    CREATE SCHEMA IF NOT EXISTS client_api;
    GRANT USAGE ON SCHEMA client_api TO postgres;

  V2__create_users_table.sql: |
    CREATE TABLE client_api.users (
      id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
      email CITEXT NOT NULL UNIQUE,
      created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP
    );
    CREATE INDEX idx_users_email ON client_api.users(email);
```

### Job Manifest

**File**: `pcc-app-shared-infra/flyway/job.yaml`

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: flyway-migrate
  namespace: flyway
spec:
  backoffLimit: 3  # Retry up to 3 times on failure
  ttlSecondsAfterFinished: 86400  # Keep job logs for 24 hours

  template:
    spec:
      serviceAccountName: flyway-sa  # Workload Identity
      restartPolicy: OnFailure

      # Init: Fetch database password from Secret Manager
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

      containers:
      # Sidecar: AlloyDB Auth Proxy
      - name: alloydb-auth-proxy
        image: gcr.io/cloud-sql-connectors/cloud-sql-proxy:latest
        args:
        - "--private-ip"
        - "--address=0.0.0.0"
        - "--port=5432"
        - "pcc-prj-app-${ENVIRONMENT}:us-east4:pcc-alloydb-${ENVIRONMENT}:primary"

      # Main: Flyway Migration
      - name: flyway
        image: flyway/flyway:latest
        command:
        - /bin/sh
        - -c
        - |
          export FLYWAY_PASSWORD=$(cat /secrets/password.txt)
          flyway migrate
        volumeMounts:
        - name: flyway-config
          mountPath: /flyway/conf/flyway.conf
          subPath: flyway.conf
        - name: flyway-config
          mountPath: /flyway/sql/V1__create_schema.sql
          subPath: V1__create_schema.sql
        - name: flyway-config
          mountPath: /flyway/sql/V2__create_users_table.sql
          subPath: V2__create_users_table.sql
        - name: secrets
          mountPath: /secrets
          readOnly: true

      volumes:
      - name: flyway-config
        configMap:
          name: flyway-config
      - name: secrets
        emptyDir:
          medium: Memory  # Store password in memory, not disk
```

### CI/CD Integration

**Cloud Build** (example):
```yaml
steps:
# Build application image
- name: 'gcr.io/cloud-builders/docker'
  args: ['build', '-t', 'gcr.io/$PROJECT_ID/client-api:$SHORT_SHA', '.']

# Push image
- name: 'gcr.io/cloud-builders/docker'
  args: ['push', 'gcr.io/$PROJECT_ID/client-api:$SHORT_SHA']

# Update migration ConfigMap
- name: 'gcr.io/cloud-builders/kubectl'
  args:
  - 'apply'
  - '-f'
  - 'flyway/configmap.yaml'
  env:
  - 'CLOUDSDK_COMPUTE_REGION=us-east4'
  - 'CLOUDSDK_CONTAINER_CLUSTER=pcc-gke-devtest'

# Run migration job
- name: 'gcr.io/cloud-builders/kubectl'
  args:
  - 'apply'
  - '-f'
  - 'flyway/job.yaml'
  env:
  - 'CLOUDSDK_COMPUTE_REGION=us-east4'
  - 'CLOUDSDK_CONTAINER_CLUSTER=pcc-gke-devtest'

# Wait for migration to complete
- name: 'gcr.io/cloud-builders/kubectl'
  args:
  - 'wait'
  - '--for=condition=complete'
  - '--timeout=5m'
  - 'job/flyway-migrate'
  - '-n'
  - 'flyway'
  env:
  - 'CLOUDSDK_COMPUTE_REGION=us-east4'
  - 'CLOUDSDK_CONTAINER_CLUSTER=pcc-gke-devtest'

# If migration fails, exit (halt deployment)
- name: 'gcr.io/cloud-builders/kubectl'
  args:
  - 'get'
  - 'job/flyway-migrate'
  - '-n'
  - 'flyway'
  - '-o'
  - 'jsonpath={.status.conditions[?(@.type=="Failed")].status}'
  env:
  - 'CLOUDSDK_COMPUTE_REGION=us-east4'
  - 'CLOUDSDK_CONTAINER_CLUSTER=pcc-gke-devtest'

# Deploy application (only if migration succeeded)
- name: 'gcr.io/cloud-builders/kubectl'
  args:
  - 'set'
  - 'image'
  - 'deployment/client-api'
  - 'client-api=gcr.io/$PROJECT_ID/client-api:$SHORT_SHA'
  env:
  - 'CLOUDSDK_COMPUTE_REGION=us-east4'
  - 'CLOUDSDK_CONTAINER_CLUSTER=pcc-gke-devtest'
```

### Monitoring and Alerts

**Cloud Monitoring Metrics**:
- Job completion status (success/failure)
- Migration duration (time to complete)
- Number of migrations applied per run
- Failure rate per environment

**Alerts**:
- Alert on job failure (immediate notification)
- Alert on long-running migration (> 10 minutes)
- Alert on high failure rate (> 10% in 24 hours)

## References

- [Flyway Documentation](https://flywaydb.org/documentation)
- [Kubernetes Jobs](https://kubernetes.io/docs/concepts/workloads/controllers/job/)
- [Phase 2.10: Create Flyway Configuration](./../plans/devtest-deployment/phase-2.10-create-flyway-configuration.md)
- [Phase 2.11: Deploy Flyway Resources](./../plans/devtest-deployment/phase-2.11-deploy-flyway-resources.md)
- [ADR-003: AlloyDB HA Strategy](./003-alloydb-ha-strategy.md)
- [ADR-004: Secret Management Approach](./004-secret-management-approach.md)
- [ADR-005: Workload Identity Pattern](./005-workload-identity-pattern.md)

## Approval

- [x] Lead Architect Approval
- [x] Database Lead Approval
- [x] Platform Team Approval
- [ ] Dev Partner Approval

---

*This ADR establishes Flyway + Kubernetes Job as the standard database migration pattern for all PCC microservices. Custom migration scripts are explicitly prohibited.*
