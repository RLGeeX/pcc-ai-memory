# Phase 2.4: Plan 7 Database Resources

**Phase**: 2.4 (AlloyDB Infrastructure - Database Design)
**Duration**: 20-25 minutes
**Type**: Planning
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/20+)

---

## Objective

Document the 7 database resources that will be created in the AlloyDB cluster for the devtest environment, including naming conventions, schemas, and microservice mappings.

## Prerequisites

✅ Phase 2.3 completed (module call created)
✅ Understanding of 7 microservices and their data requirements
✅ Database naming conventions established
✅ Terraform module supports `databases` variable (list of strings)

---

## Database Design

### Overview

**Cluster**: `pcc-alloydb-cluster-devtest` (Phase 2.1)
**Instance**: `pcc-alloydb-instance-devtest-primary` (read-write)
**Replica**: `pcc-alloydb-instance-devtest-replica` (read-only)
**Total Databases**: 7 (one per microservice)

**Database Creation**: Defined in Phase 2.3 module call (`databases` variable)
**Schema Management**: Flyway migrations (CI/CD, not terraform)

---

## Database Specifications

### 1. auth_db_devtest

**Microservice**: `pcc-auth-api`
**Purpose**: Authentication and authorization
**Owner**: `auth_api_user` (Phase 2.5)

**Schema Overview** (managed by Flyway):
- Users table (local auth fallback)
- Sessions table (JWT token tracking)
- Refresh tokens
- OAuth provider mappings (Descope)

**Connection Pattern**:
```
Descope SSO → pcc-auth-api → auth_db_devtest
```

---

### 2. client_db_devtest

**Microservice**: `pcc-client-api`
**Purpose**: Client portfolio management
**Owner**: `client_api_user` (Phase 2.5)

**Schema Overview** (managed by Flyway):
- Clients table (portfolio companies)
- Client hierarchy (parent-child relationships)
- Client metadata (industry, size, risk category)
- Client contacts

**Connection Pattern**:
```
pcc-client-api → client_db_devtest (read-write)
pcc-client-api → replica (read-only for reporting)
```

---

### 3. user_db_devtest

**Microservice**: `pcc-user-api`
**Purpose**: User profile and preferences
**Owner**: `user_api_user` (Phase 2.5)

**Schema Overview** (managed by Flyway):
- User profiles
- User preferences (notifications, UI settings)
- User roles and permissions
- Audit log (user actions)

**Connection Pattern**:
```
pcc-user-api → user_db_devtest (read-write)
pcc-auth-api → user_db_devtest (read-only for profile lookup)
```

---

### 4. metric_builder_db_devtest

**Microservice**: `pcc-metric-builder-api`
**Purpose**: Metric definitions and templates
**Owner**: `metric_builder_api_user` (Phase 2.5)

**Schema Overview** (managed by Flyway):
- Metric definitions (KPIs, thresholds)
- Metric templates (reusable across clients)
- Metric categories
- Calculation formulas

**Connection Pattern**:
```
pcc-metric-builder-api → metric_builder_db_devtest (read-write)
pcc-metric-tracker-api → metric_builder_db_devtest (read-only for definitions)
```

---

### 5. metric_tracker_db_devtest

**Microservice**: `pcc-metric-tracker-api`
**Purpose**: Metric values and tracking
**Owner**: `metric_tracker_api_user` (Phase 2.5)

**Schema Overview** (managed by Flyway):
- Metric values (time-series data)
- Metric snapshots (historical)
- Metric alerts (threshold breaches)
- Metric trends

**Connection Pattern**:
```
pcc-metric-tracker-api → metric_tracker_db_devtest (read-write)
pcc-metric-tracker-api → replica (read-only for analytics)
BigQuery sync → metric_tracker_db_devtest (read-only)
```

---

### 6. task_builder_db_devtest

**Microservice**: `pcc-task-builder-api`
**Purpose**: Task definitions and workflows
**Owner**: `task_builder_api_user` (Phase 2.5)

**Schema Overview** (managed by Flyway):
- Task definitions (templates)
- Workflow definitions (task sequences)
- Task categories
- SLA definitions

**Connection Pattern**:
```
pcc-task-builder-api → task_builder_db_devtest (read-write)
pcc-task-tracker-api → task_builder_db_devtest (read-only for definitions)
```

---

### 7. task_tracker_db_devtest

**Microservice**: `pcc-task-tracker-api`
**Purpose**: Task instances and execution
**Owner**: `task_tracker_api_user` (Phase 2.5)

**Schema Overview** (managed by Flyway):
- Task instances (active tasks)
- Task assignments (user → task)
- Task status tracking
- Task comments and attachments
- Task history (audit log)

**Connection Pattern**:
```
pcc-task-tracker-api → task_tracker_db_devtest (read-write)
pcc-task-tracker-api → replica (read-only for reporting)
```

---

## Database Naming Convention

**Pattern**: `{service}_db_{environment}`

**Examples**:
- **Devtest**: `auth_db_devtest`, `client_db_devtest`, etc.
- **Production** (future): `auth_db_prod`, `client_db_prod`, etc.

**Rationale**:
- Environment suffix prevents cross-environment access
- Service prefix groups related databases
- Underscore separator for readability

---

## Terraform Configuration

### Module Call (from Phase 2.3)

```hcl
module "alloydb_cluster_devtest" {
  source = "git::https://github.com/your-org/pcc-tf-library.git//modules/alloydb-cluster?ref=v1.0.0"

  # ... other parameters ...

  # Databases (7 microservices)
  databases = [
    "auth_db_devtest",
    "client_db_devtest",
    "user_db_devtest",
    "metric_builder_db_devtest",
    "metric_tracker_db_devtest",
    "task_builder_db_devtest",
    "task_tracker_db_devtest"
  ]
}
```

### Terraform Resource (from Phase 2.2 module)

```hcl
# pcc-tf-library/modules/alloydb-cluster/main.tf
resource "google_alloydb_database" "databases" {
  for_each = toset(var.databases)

  database  = each.value
  cluster   = google_alloydb_cluster.cluster.name
  instance  = google_alloydb_instance.primary.instance_id

  depends_on = [google_alloydb_instance.primary]
}
```

**Note**: Terraform creates empty databases. Flyway creates schemas (Phase 2.7).

---

## Database User Strategy

### User per Service (Phase 2.5)

Each database gets a dedicated PostgreSQL user:

1. **auth_api_user** → auth_db_devtest
2. **client_api_user** → client_db_devtest
3. **user_api_user** → user_db_devtest
4. **metric_builder_api_user** → metric_builder_db_devtest
5. **metric_tracker_api_user** → metric_tracker_db_devtest
6. **task_builder_api_user** → task_builder_db_devtest
7. **task_tracker_api_user** → task_tracker_db_devtest

**Additional Users**:
- **pcc_admin** (superuser for migrations and maintenance)
- **flyway_user** (schema migration user)

**Credentials**: Stored in Secret Manager (Phase 2.5)

---

## Database Sizing

### Storage Estimates (Initial)

| Database | Estimated Size | Growth Rate |
|----------|----------------|-------------|
| auth_db_devtest | 100 MB | Low |
| client_db_devtest | 500 MB | Medium |
| user_db_devtest | 200 MB | Low |
| metric_builder_db_devtest | 100 MB | Low |
| metric_tracker_db_devtest | 2 GB | High (time-series) |
| task_builder_db_devtest | 100 MB | Low |
| task_tracker_db_devtest | 1 GB | Medium |

**Total Initial**: ~4 GB
**Cluster Storage**: 100 GB (Phase 2.1) with auto-scaling to 1 TB

---

## Connection Pooling

### Per-Service Configuration

**Connection Pool Size**: 10-20 connections per service
**Total Connections**: 7 services × 15 avg = ~105 connections
**AlloyDB Max**: 500 connections (Phase 2.1)

**Pooling Strategy**:
- **Primary Instance**: Read-write workloads
- **Replica Instance**: Read-only queries (reporting, analytics)

**Connection String Format**:
```
Host=10.28.48.10;Port=5432;Database={db_name};Username={user};Password={secret}
```

---

## Read Replica Usage

### Read-Heavy Workloads

**Services Using Replica**:
- **metric_tracker_api**: Analytics queries (read-only)
- **task_tracker_api**: Reporting queries (read-only)
- **client_api**: Client list queries (read-only)

**Replica Connection String**:
```
Host=10.28.48.10;Port=5432;Database={db_name};Username={user};Password={secret};Target Session Attributes=read-only
```

**Application Configuration**:
- Primary: Write operations + transactional reads
- Replica: Reporting, analytics, dashboards

---

## Tasks (Planning)

1. **Database List**:
   - [x] Document 7 database names (defined in Phase 2.3)
   - [x] Define naming convention
   - [x] Map databases to microservices

2. **Schema Planning**:
   - [x] Document schema overview for each database
   - [x] Clarify Flyway manages schemas (not terraform)
   - [x] Identify cross-database read patterns

3. **User Strategy**:
   - [x] Define user-per-service pattern
   - [x] Plan admin and Flyway users
   - [x] Reference Phase 2.5 for credential management

4. **Sizing**:
   - [x] Estimate initial database sizes
   - [x] Project growth rates
   - [x] Confirm cluster storage sufficient

---

## Dependencies

**Upstream**:
- Phase 2.3: Database list defined in module call
- Phase 2.1: Cluster sizing (100 GB storage, 500 max connections)

**Downstream**:
- Phase 2.5: Secret Manager will store credentials for 7 database users
- Phase 2.7: Flyway will create schemas for all 7 databases
- Phase 3: Microservices will connect to these databases

---

## Validation Criteria

- [x] 7 database names documented
- [x] Naming convention established (`{service}_db_{environment}`)
- [x] Each database mapped to microservice
- [x] Schema management strategy clarified (Flyway, not terraform)
- [x] User-per-service strategy documented
- [x] Sizing estimates calculated
- [x] Connection pooling strategy defined
- [x] Read replica usage planned

---

## Deliverables

- [x] Database design document (this file)
- [x] 7 database names (already in Phase 2.3 module call)
- [x] User strategy (input for Phase 2.5)
- [x] Schema overview (input for Phase 2.7 Flyway)

---

## References

- Phase 2.1 (cluster configuration)
- Phase 2.2 (terraform module, `for_each` database resource)
- Phase 2.3 (module call with `databases` variable)
- Phase 2.5 (Secret Manager for database credentials)
- Phase 2.7 (Flyway for schema migrations)

---

## Notes

- **Terraform Role**: Creates empty databases only (no schemas, no tables)
- **Flyway Role**: Creates schemas, tables, indexes, constraints (Phase 2.7)
- **User Creation**: Manual or via Flyway migration (not terraform)
- **Credentials**: Stored in Secret Manager with 30-90 day rotation (Phase 2.5)
- **Connection Pooling**: Npgsql (.NET) with 10-20 connections per service
- **Read Replicas**: Used for analytics and reporting (not transactional)
- **Cross-Database Reads**: Some services read from other databases (e.g., auth_api → user_db)

---

## Time Estimate

**Planning**: 20-25 minutes
- 5 min: Document 7 database names and purposes
- 5 min: Define naming convention and user strategy
- 5 min: Estimate sizing and connection pooling
- 5 min: Document schema overview and Flyway handoff

---

**Next Phase**: 2.5 - Plan Secret Manager & Credential Rotation
