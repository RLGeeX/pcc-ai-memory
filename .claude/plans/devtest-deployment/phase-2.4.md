# Phase 2.4: Plan Database Resource

**Phase**: 2.4 (AlloyDB Infrastructure - Database Design)
**Duration**: 20-25 minutes
**Type**: Planning
**Status**: 📋 Planning (Not Started)
**Date**: TBD (10/20+)

---

## Objective

Document the 1 database resource that will be created in the AlloyDB cluster for the devtest environment, including naming conventions, schema, and microservice mapping.

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
**Total Databases**: 1 (for pcc-client-api microservice)

**Database Creation**: Flyway migrations (CI/CD, not terraform)
**Schema Management**: Flyway migrations (CI/CD, not terraform)

---

## Database Specifications

### 1. client_api_db_devtest

**Microservice**: `pcc-client-api` (deployed as `pcc-client-api-devtest` in devtest namespace)
**Purpose**: Client portfolio management
**Owner**: `client_api_user` (Phase 2.5)

**Schema Overview** (managed by Flyway):
- Clients table (portfolio companies)
- Client hierarchy (parent-child relationships)
- Client metadata (industry, size, risk category)
- Client contacts

**Connection Pattern**:
```
pcc-client-api-devtest (namespace) → client_api_db_devtest (read-write)
pcc-client-api-devtest (namespace) → replica (read-only for reporting)
```

---

## Database Naming Convention

**Pattern**: `{service}_db_{environment}`

**Examples**:
- **Devtest**: `client_api_db_devtest`
- **Production** (future): `client_api_db_prod`

**Rationale**:
- Environment suffix prevents cross-environment access
- Service prefix groups related databases
- Underscore separator for readability

**Important**:
- **Microservice code/containers**: Use base name without environment (e.g., `pcc-client-api`, `pcc-app-client` container image)
- **Deployed infrastructure**: Always include environment suffix (e.g., `pcc-client-api-devtest` namespace, service account, K8s service names)

---

## Terraform Configuration

### Database Creation via Flyway (Phase 2.7)

**Important**: AlloyDB clusters come with a default `postgres` database. The `google_alloydb_database` Terraform resource **does not exist** in the Google provider.

**Database `client_api_db_devtest` will be created by Flyway** via SQL:

```sql
-- V1__create_database_and_initial_schema.sql (Example - actual implementation in Phase 2.7)
CREATE DATABASE client_api_db_devtest;

\c client_api_db_devtest

-- Then create schema (tables, indexes, etc.)
CREATE TABLE users (...);
CREATE TABLE sessions (...);
-- etc.
```

**Note**: Flyway creates both the database AND the schema, executed via Cloud Build CI/CD pipeline (Phase 2.7).

---

## Database User Strategy

### User per Service (Phase 2.5)

Each database gets a dedicated PostgreSQL user:

1. **client_api_user** → client_api_db_devtest

**Additional Users**:
- **pcc_admin** (superuser for migrations and maintenance)
- **flyway_user** (schema migration user)

**Credentials**: Stored in Secret Manager (Phase 2.5)

**Note**: Additional service users will be created in Phase 10 when remaining services are deployed

---

## Database Sizing

### Storage Estimates (Initial)

| Database | Estimated Size | Growth Rate |
|----------|----------------|-------------|
| client_api_db_devtest | 500 MB | Medium |

**Total Initial**: ~500 MB
**Cluster Storage**: 100 GB (Phase 2.1) with auto-scaling to 1 TB (ample room for future services)

---

## Connection Pooling

### Per-Service Configuration

**Connection Pool Size**: 10-20 connections per service
**Total Connections**: 1 service (pcc-client-api) × 15 avg = ~15 connections
**AlloyDB Max**: 500 connections (Phase 2.1, ample headroom)

**Pooling Strategy**:
- **Primary Instance**: Read-write workloads
- **Replica Instance**: Read-only queries (reporting, analytics)

**Connection String Format**:
```
Host=10.28.48.10;Port=5432;Database={db_name};Username={user};Password={secret};SSL Mode=Require
```

---

## Read Replica Usage

### Read-Heavy Workloads

**Services Using Replica**:
- **pcc-client-api**: Client list queries, reporting (read-only)

**Replica Connection String**:
```
Host=10.28.48.10;Port=5432;Database={db_name};Username={user};Password={secret};Target Session Attributes=read-only;SSL Mode=Require
```

**Application Configuration**:
- Primary: Write operations + transactional reads
- Replica: Reporting, analytics, dashboards

**Note**: Additional services will use replica in Phase 10 when deployed

---

## Tasks (Planning)

1. **Database List**:
   - [x] Document 1 database name (client_api_db_devtest)
   - [x] Define naming convention
   - [x] Map databases to microservices

2. **Database & Schema Planning**:
   - [x] Document schema overview for each database
   - [x] Clarify Flyway creates databases AND schemas (not terraform)
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
- Phase 2.1: Cluster sizing (100 GB storage, 500 max connections)
- Phase 2.3: AlloyDB cluster/instances deployed (default `postgres` DB auto-created)

**Downstream**:
- Phase 2.5: Secret Manager will store credentials for 3 database users (client_api_user, pcc_admin, flyway_user)
- Phase 2.7: Flyway will create database `client_api_db_devtest` AND its schema
- Phase 7+: Microservices will connect to these databases when deployed to devtest

---

## Validation Criteria

- [x] 1 database name documented (client_api_db_devtest)
- [x] Naming convention established (`{service}_db_{environment}`)
- [x] Each database mapped to microservice
- [x] Database AND schema creation strategy clarified (Flyway, not terraform)
- [x] User-per-service strategy documented
- [x] Sizing estimates calculated
- [x] Connection pooling strategy defined
- [x] Read replica usage planned

---

## Deliverables

- [x] Database design document (this file)
- [x] 1 database name (client_api_db_devtest - created by Flyway in Phase 2.7)
- [x] User strategy (input for Phase 2.5)
- [x] Schema overview (input for Phase 2.7 Flyway migrations)

---

## References

- Phase 2.1 (cluster configuration)
- Phase 2.2 (terraform module - cluster/instances only)
- Phase 2.3 (module call - deploys cluster with default `postgres` DB)
- Phase 2.5 (Secret Manager for database credentials)
- Phase 2.7 (Flyway for database AND schema creation)

---

## Notes

- **Terraform Role**: Creates cluster and instances only (AlloyDB auto-creates default `postgres` database)
- **Flyway Role**: Creates database `client_api_db_devtest` AND all schemas, tables, indexes, constraints (Phase 2.7)
- **No `google_alloydb_database` Resource**: This Terraform resource does not exist in the Google provider
- **User Creation**: Manual or via Flyway migration (not terraform)
- **Credentials**: Stored in Secret Manager with 30-90 day rotation (Phase 2.5)
- **Connection Pooling**: Npgsql (.NET) with 10-20 connections per service
- **Read Replicas**: Used for analytics and reporting (not transactional)
- **Single Service Scope**: Only pcc-client-api deployed end-to-end in this phase
- **Additional Services**: Remaining 6 services deployed in Phase 10

---

## Time Estimate

**Planning**: 20-25 minutes
- 5 min: Document 1 database name and purpose
- 5 min: Define naming convention and user strategy
- 5 min: Estimate sizing and connection pooling
- 5 min: Document schema overview and Flyway handoff

---

**Next Phase**: 2.5 - Plan Secret Manager & Credential Rotation
