# Phase 2.10: Create Flyway Migration Scripts

<!-- Script Review: 2025-10-24
Found 14 tables in developer's 01_InitialCreation.sql:
- Main: Lookups, Parents, Portcos, ParentDetails, PortcoDetails, ParentChildren, ParentPortcos (7)
- Audit: ParentAudits, PortcoAudits, ParentDetailsAudits, PortcoDetailsAudits, ParentChildAudits, ParentPortcoAudits (6)
- History: __EFMigrationsHistory (1)
Total expected with Flyway: 15 tables (14 from script + flyway_schema_history)
Schema: public (default, no explicit prefix)
Extensions: NONE (uses only built-in PostgreSQL types)
Indexes: 19 indexes, Seed data: 19 lookup records
-->

**Phase**: 2.10 (Database Migrations - Preparation)
**Duration**: 20-27 minutes (includes script review + validation updates)
**Type**: Implementation
**Status**: Ready for Execution

---

## Execution Tool

**Use Claude Code for this phase** - Creating SQL migration scripts in the microservice repository, no CLI commands.

---

## Objective

Prepare for Flyway migration execution by:
1. Creating Flyway configuration file
2. **Critically**: Reviewing developer's actual migration script (which may have changed)
3. **Updating Phase 2.11 validation steps** to match developer's actual SQL content

This ensures Phase 2.11 execution and validation work correctly with the developer's current script. Flyway will execute locally on developer's machine (and later in Cloud Build pipeline).

## Prerequisites

✅ Phase 2.4 completed (AlloyDB cluster deployed)
✅ Phase 2.7 completed (secrets created)
✅ Phase 2.9 completed (IAM bindings, service accounts)
✅ `pcc-client-api` repository cloned locally

---

## 🚨 IMPORTANT: Developer-Maintained SQL Scripts

**Schema Strategy**: ✅ **CONFIRMED** - Using `public` schema (default PostgreSQL schema)
- Developer has confirmed `public` schema approach
- All tables will be created in PostgreSQL's default `public` schema
- No custom schema creation needed

**SQL Script Ownership**:
- ✅ **Developer maintains all migration scripts** (generated via Entity Framework Core in Visual Studio)
- ✅ **Existing script**: `01_InitialCreation.sql` (313 lines, comprehensive schema)
  - Contains: 13 tables, 19 indexes, 19 seed records
  - **Developer is renaming**: `01_InitialCreation.sql` → `V1__InitialCreation.sql` for Flyway compatibility
- ✅ **Our responsibility**: Create database via command line: `CREATE DATABASE client_api_db;`
- ❌ **We do NOT create**: V1__create_schema.sql, V2__create_tables.sql (developer owns these)

**Current File Status**:
- The SQL scripts shown in Steps 2-3 below are **placeholder examples** for illustration only
- **Actual migration scripts** come from developer's Entity Framework migrations
- Developer is handling file rename to follow Flyway naming convention
- ⚠️ **Developer notes**: Current script is stale and will change
  - **Action required**: Step 5 of this phase reviews the actual script and updates Phase 2.11 validations
  - This ensures Phase 2.11 validation steps match the developer's actual SQL content
  - Table names, schema, and counts in Phase 2.11 Step 7 will be updated based on actual script

---

## Architecture Overview

**Local Execution Model**:
1. **Auth Proxy**: Runs locally, authenticates with developer's gcloud credentials
2. **Flyway**: Runs locally on developer's machine
3. **SQL Scripts**: Stored in microservice repo (`pcc-client-api`)
4. **Future**: Migrate to Cloud Build pipeline (Phase 4+)

**Flow**: Flyway (local) → Auth Proxy (local) → AlloyDB

**No Kubernetes deployment** - Flyway runs on local machine, not in GKE cluster.

---

## File Structure

Create files in `pcc-client-api` repository:

```
pcc-client-api/
└── PortfolioConnect.Client.Api/
    └── Migrations/
        └── Scripts/
            └── v1/
                ├── V1__create_schema.sql
                ├── V2__create_tables.sql
                └── flyway.conf
```

---

## Step 1: Create Migrations Directory

**Repository**: `pcc-client-api`

Create directory structure:
```
PortfolioConnect.Client.Api/Migrations/Scripts/v1/
```

**Purpose**: Organize SQL migrations by version (v1, v2, etc. for major schema changes)

---

## Step 2: Example Schema Initialization Script (Illustration Only)

**Note**: This is a **placeholder example**. Developer's actual `V1__InitialCreation.sql` handles all schema initialization.

**Example File**: `pcc-client-api/PortfolioConnect.Client.Api/Migrations/Scripts/v1/V1__InitialCreation.sql`

```sql
-- Example: Database initialization script
-- Version: 1
-- Description: Initial database setup
-- Note: Actual script maintained by developer via Entity Framework Core

-- Extension for UUID generation (if needed)
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- Extension for case-insensitive text (if needed)
CREATE EXTENSION IF NOT EXISTS "citext";

-- Using default public schema (no custom schema creation needed)
-- Tables will be created in public schema

-- Note: Developer's actual script contains:
-- - 13 tables (Lookups, Parents, Portcos, ParentDetails, etc.)
-- - 19 indexes for performance
-- - 19 seed lookup records
-- - Migration history table
```

**Key Design Decisions**:
- ✅ **Schema**: Using PostgreSQL default `public` schema (confirmed by developer)
- ✅ **Extensions**: May include `uuid-ossp`, `citext` depending on developer's needs
- ✅ **Actual content**: Developer's EF Core-generated script (313 lines)

---

## Step 3: Example Application Tables (Illustration Only)

**Note**: This step is **not needed**. Developer's `V1__InitialCreation.sql` already contains all table definitions.

**Example concept** (for reference only):

```sql
-- Example: Application tables
-- Note: Developer's actual V1__InitialCreation.sql contains complete table definitions

-- Tables created in public schema (default)
-- No SET search_path needed for public schema

-- ============================================================================
-- Users table
-- ============================================================================
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  email CITEXT NOT NULL UNIQUE,
  first_name VARCHAR(255),
  last_name VARCHAR(255),
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  deleted_at TIMESTAMP WITH TIME ZONE,

  -- Constraints
  CONSTRAINT users_email_check CHECK (email ~ '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
);

-- Indexes for users
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_users_deleted_at ON users(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_users_created_at ON users(created_at DESC);

-- Comments
COMMENT ON TABLE users IS 'Application users with soft delete support';
COMMENT ON COLUMN users.email IS 'User email address (case-insensitive, unique)';
COMMENT ON COLUMN users.deleted_at IS 'Soft delete timestamp (NULL = active)';

-- ============================================================================
-- Clients table
-- ============================================================================
CREATE TABLE IF NOT EXISTS clients (
  id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  name VARCHAR(255) NOT NULL,
  description TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT CURRENT_TIMESTAMP,
  deleted_at TIMESTAMP WITH TIME ZONE,

  -- Constraints
  CONSTRAINT clients_name_check CHECK (length(name) >= 1)
);

-- Indexes for clients
CREATE INDEX IF NOT EXISTS idx_clients_name ON clients(name);
CREATE INDEX IF NOT EXISTS idx_clients_deleted_at ON clients(deleted_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_clients_created_at ON clients(created_at DESC);

-- Comments
COMMENT ON TABLE clients IS 'Client organizations with soft delete support';
COMMENT ON COLUMN clients.name IS 'Client organization name';
COMMENT ON COLUMN clients.deleted_at IS 'Soft delete timestamp (NULL = active)';

-- ============================================================================
-- Trigger function: Auto-update updated_at column
-- ============================================================================
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = CURRENT_TIMESTAMP;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_updated_at_column() IS 'Automatically updates updated_at timestamp on row modification';

-- ============================================================================
-- Apply triggers to tables
-- ============================================================================
CREATE TRIGGER update_users_updated_at
  BEFORE UPDATE ON users
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_clients_updated_at
  BEFORE UPDATE ON clients
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();
```

**Key Design Decisions**:
- ✅ **UUID Primary Keys**: Using `uuid_generate_v4()` for distributed systems
- ✅ **CITEXT for emails**: Case-insensitive email matching
- ✅ **Soft Deletes**: `deleted_at` timestamp instead of hard deletes
- ✅ **Automatic Timestamps**: `created_at`, `updated_at` with triggers
- ✅ **Partial Indexes**: `WHERE deleted_at IS NULL` for active-only queries
- ✅ **Email Validation**: Basic regex constraint for email format
- ✅ **Comments**: Table and column documentation in database

---

## Step 4: Create Flyway Configuration

**File**: `pcc-client-api/PortfolioConnect.Client.Api/Migrations/Scripts/v1/flyway.conf`

```conf
# Flyway Configuration for PortCo Connect Client API
# Environment: All (devtest, dev, staging, prod)
# Execution: Local machine or Cloud Build

# Database Connection
# Note: Connection details provided via command-line arguments or environment variables
# flyway.url will be: jdbc:postgresql://localhost:5432/client_api_db
# flyway.user will be: postgres
# flyway.password will be: from Secret Manager

# Migration Scripts Location
flyway.locations=filesystem:./PortfolioConnect.Client.Api/Migrations/Scripts/v1

# Baseline Configuration
flyway.baselineOnMigrate=true
flyway.baselineVersion=0
flyway.baselineDescription=Initial baseline

# Validation Rules
flyway.validateOnMigrate=true
flyway.outOfOrder=false
flyway.ignoreMissingMigrations=false
flyway.ignoreIgnoredMigrations=false

# Safety Features
flyway.cleanDisabled=true  # Prevent accidental data loss

# Schema History Table
flyway.table=flyway_schema_history
flyway.schemas=public

# Placeholders (not used in current scripts)
flyway.placeholderReplacement=false

# Output Configuration
flyway.outputType=json
```

**Key Configuration**:
- ✅ Database name: `client_api_db` (NO environment suffix)
- ✅ Schema: `public` (PostgreSQL default schema)
- ✅ History table: `flyway_schema_history` (in public schema)
- ✅ Clean disabled: Prevents accidental `flyway clean` in production
- ✅ Baseline on migrate: Allows applying to existing database

---

## Database Naming Convention

**CRITICAL**: Database name does NOT include environment suffix

✅ **Correct**: `client_api_db` (same across all environments)
❌ **Incorrect**: `client_api_db_devtest`

**Rationale**:
- Same database name across all environments (devtest, dev, staging, prod)
- Differentiation at **cluster level**: `pcc-alloydb-devtest` vs `pcc-alloydb-prod`
- Simplifies application configuration (no environment-specific database names)
- Follows ADR-003 and ADR-007 patterns

---

## Validation Checklist

**Developer Responsibilities**:
- [ ] Developer renames `01_InitialCreation.sql` to `V1__InitialCreation.sql`
- [ ] Directory exists: `PortfolioConnect.Client.Api/Migrations/Scripts/v1/`
- [ ] Developer's script follows Flyway naming convention: `V{version}__{description}.sql`
- [ ] Developer's script uses `public` schema (confirmed)
- [ ] Database name: `client_api_db` (NO environment suffix)

**Infrastructure Team Responsibilities** (Phase 2.10):
- [ ] Flyway configuration created (`flyway.conf`)
- [ ] Developer's actual script reviewed (Step 5)
- [ ] Phase 2.11 validation steps updated to match actual script (Step 5)
- [ ] Ready to proceed to Phase 2.11 execution

**Infrastructure Team Responsibilities** (Phase 2.11):
- [ ] Database created via command line: `CREATE DATABASE client_api_db;`
- [ ] Auth Proxy running locally
- [ ] Flyway configuration tested with developer's scripts
- [ ] Flyway execution successful (local machine)

**Note**: Steps 2-3 in this phase show **example SQL scripts** for illustration only. Actual migration scripts are maintained by developer using Entity Framework Core.

---

## SQL Migration Best Practices

**Followed in scripts**:
- ✅ Idempotent: `CREATE ... IF NOT EXISTS` for safe re-runs
- ✅ Versioned: V1, V2 for sequential application
- ✅ Documented: Comments explaining purpose and design
- ✅ Constraints: Email validation, name length checks
- ✅ Performance: Indexes on frequently queried columns
- ✅ Partial indexes: `WHERE deleted_at IS NULL` for active records only

---

## Environment-Specific Execution

**Phase 2.11 will execute with**:

```bash
# Devtest environment
flyway migrate \
  -url=jdbc:postgresql://localhost:5432/client_api_db \
  -user=postgres \
  -password=$(gcloud secrets versions access latest --secret=alloydb-devtest-password) \
  -locations=filesystem:./PortfolioConnect.Client.Api/Migrations/Scripts/v1
```

**No Kubernetes manifests needed** - Flyway runs locally on developer's machine.

---

## Step 5: 🚨 CRITICAL - Review Developer's Script & Update Phase 2.11 Validations

**⚠️ IMPORTANT**: Developer has indicated the script is stale and will change. Before moving to Phase 2.11, review the actual script and update Phase 2.11 validation steps.

### Action Required (Use Claude Code)

**Purpose**: Ensure Phase 2.11 validation steps match the developer's actual SQL script content.

**Steps**:

1. **Read the developer's actual script**:
   ```
   ~/pcc/src/pcc-client-api/PortfolioConnect.Client.Api/Migrations/Scripts/v1/V1__InitialCreation.sql
   ```

2. **Analyze the script to identify**:
   - All tables being created (with exact names and casing)
   - Schema being used (confirm it's `public` as expected)
   - Any extensions being loaded (e.g., uuid-ossp, citext)
   - Total number of tables expected

3. **Update Phase 2.11 file** (`phase-2.11-execute-flyway-migrations.md`):
   - **Step 7 "List Tables"** - Update expected output with actual table names
   - **Step 7 "Verify Table Structure"** - Update query to use an actual table name from script
   - **Step 7 "Verify Extensions"** - Update expected extensions based on script
   - **Validation Checklist** - Update table count and table names
   - **Post-Deployment Actions** - Update table count and names

4. **Document your findings** in a comment at top of this file:
   ```markdown
   <!-- Script Review: [Date] - Found X tables: [list], schema: public, extensions: [list] -->
   ```

**Example**: If developer's script creates tables `Users`, `Accounts`, `Transactions` (3 tables):
- Step 7 expected output should show those 3 table names (not the current 15)
- Verify Table Structure should query `public."Users"` (not `public."Lookups"`)
- Validation checklist should expect 3 tables + 2 history tables = 5 total

**Why This Matters**:
- Current Phase 2.11 expects 15 tables based on stale script
- Actual script may have different tables, counts, names
- Without this update, Phase 2.11 validation will fail with false negatives

**Time Estimate**: 5-7 minutes

---

## Next Phase Dependencies

**Phase 2.11** will:
- Start AlloyDB Auth Proxy locally
- Execute Flyway migrations locally
- Verify database schema created
- Verify tables exist (users, clients, flyway_schema_history)

**NO Workload Identity needed** - Using developer's gcloud credentials for local execution.

---

## Future: Cloud Build Integration (Phase 4+)

When migrating to Cloud Build pipeline:
- Auth Proxy will run as Cloud Build step
- Flyway will run as Cloud Build step
- Service account authentication (not Workload Identity)
- Same SQL scripts, different execution environment

---

## References

- **Flyway Documentation**: https://flywaydb.org/documentation
- **PostgreSQL Extensions**: https://www.postgresql.org/docs/current/contrib.html
- **AlloyDB Best Practices**: https://cloud.google.com/alloydb/docs/best-practices

---

## Time Estimate

- **Create directory structure**: 1 minute
- **Example scripts (Steps 2-3)**: 0 minutes (developer maintains actual scripts)
- **Create flyway.conf**: 3 minutes
- **🚨 Review developer's script** (Step 5): 5-7 minutes
- **Update Phase 2.11 validations** (Step 5): 10-15 minutes
- **Review and validation**: 2 minutes
- **Total**: 20-27 minutes

---

**Status**: Ready for execution
**Next**: Phase 2.11 - Execute Flyway Migrations (Local)
