# Phase 2.11: Execute Flyway Migrations

**Phase**: 2.11 (Database Migrations - Local Execution)
**Duration**: 15-20 minutes
**Type**: Implementation
**Status**: Ready for Execution

---

## Execution Tool

**Use WARP for this phase** - Running gcloud, Auth Proxy, and Flyway commands locally, no file editing.

**Note**: Phase 2.10 should have already reviewed developer's script and updated validation steps in this phase.

---

## Objective

Execute Flyway database migrations locally against AlloyDB devtest cluster. Verifies end-to-end connectivity from local machine → Auth Proxy → AlloyDB using developer's gcloud credentials.

## Prerequisites

✅ Phase 2.10 completed:
  - Developer's actual script reviewed
  - Validation steps in this phase updated to match actual script content
  - Flyway configuration created
✅ Phase 2.4 completed (AlloyDB cluster deployed)
✅ Phase 2.7 completed (Secrets created in Secret Manager)
✅ gcloud CLI authenticated with appropriate permissions
✅ Flyway CLI installed locally (or will install in Step 1)
✅ `pcc-client-api` repository cloned locally

---

## 🚨 IMPORTANT: Schema Strategy and Developer Scripts

**Schema Approach**: ✅ **CONFIRMED** - Using `public` schema (default PostgreSQL schema)
- Developer has confirmed `public` schema approach
- All tables created in PostgreSQL's default `public` schema
- Validation queries below use `public.*` references

**Developer Script Ownership**:
- ✅ Developer maintains SQL migration scripts (Entity Framework Core generated)
- ✅ Developer's existing script: `01_InitialCreation.sql` → developer is renaming to `V1__InitialCreation.sql`
- ✅ Developer's script contains: 13 tables, 19 indexes, 19 seed records (313 lines)
- ✅ Our responsibility: Database creation only (`CREATE DATABASE client_api_db;`)

**Schema References in This Phase**:
- All table references use `public` schema (e.g., `public.Lookups`, `public.Parents`)
- Flyway history table: `public.flyway_schema_history`
- Validation queries: `\dt public.*` (list tables in public schema)

---

## Architecture Overview

**Local Execution Model**:
```
Developer Machine
├── Flyway CLI (reads SQL from pcc-client-api repo)
├── Auth Proxy (authenticates with gcloud credentials)
└── gcloud CLI (fetches password from Secret Manager)
    ↓
AlloyDB Cluster (pcc-alloydb-devtest)
└── Database: client_api_db
```

**Authentication**: Uses developer's gcloud credentials (no service account keys, no Workload Identity)

---

## Working Directory

```bash
cd ~/pcc/src/pcc-client-api
```

---

## Step 1: Install Flyway CLI (if not installed)

### Option A: Homebrew (macOS/Linux)
```bash
brew install flyway
flyway -v
```

### Option B: Download Binary (All platforms)
```bash
# Download latest Flyway Community Edition
curl -L https://repo1.maven.org/maven2/org/flywaydb/flyway-commandline/9.22.3/flyway-commandline-9.22.3-linux-x64.tar.gz -o flyway.tar.gz

# Extract
tar -xzf flyway.tar.gz

# Move to /usr/local/bin (or add to PATH)
sudo mv flyway-9.22.3 /usr/local/flyway
sudo ln -s /usr/local/flyway/flyway /usr/local/bin/flyway

# Verify
flyway -v
```

**Expected**: `Flyway Community Edition 9.x.x by Redgate`

**Skip this step** if Flyway already installed.

---

## Step 2: Install AlloyDB Auth Proxy

```bash
# Download Auth Proxy binary
curl -o alloydb-auth-proxy https://storage.googleapis.com/alloydb-auth-proxy/v1.10.1/alloydb-auth-proxy.linux.amd64

# Make executable
chmod +x alloydb-auth-proxy

# Move to /usr/local/bin
sudo mv alloydb-auth-proxy /usr/local/bin/

# Verify
alloydb-auth-proxy --version
```

**Expected**: `alloydb-auth-proxy version 1.10.1`

**Skip this step** if Auth Proxy already installed.

---

## Step 3: Start AlloyDB Auth Proxy

### Get AlloyDB Connection Name
```bash
gcloud alloydb clusters describe pcc-alloydb-devtest \
  --region=us-east4 \
  --project=pcc-prj-app-devtest \
  --format="value(name)"
```

**Expected**: `projects/pcc-prj-app-devtest/locations/us-east4/clusters/pcc-alloydb-devtest`

### Start Auth Proxy (in background)
```bash
alloydb-auth-proxy \
  "projects/pcc-prj-app-devtest/locations/us-east4/clusters/pcc-alloydb-devtest" \
  --address=0.0.0.0 \
  --port=5432 \
  &

# Save PID for cleanup later
PROXY_PID=$!
echo $PROXY_PID
```

**Expected Output**:
```
Listening on 0.0.0.0:5432
Ready for new connections
```

**Note**: Auth Proxy runs in background. Keep terminal open or use `nohup`.

### Verify Auth Proxy Running
```bash
# Check process
ps aux | grep alloydb-auth-proxy

# Test connection (should respond)
nc -zv localhost 5432
```

**Expected**: `Connection to localhost port 5432 [tcp/postgresql] succeeded!`

---

## Step 4: Fetch Database Password

```bash
# Fetch password from Secret Manager
export FLYWAY_PASSWORD=$(gcloud secrets versions access latest \
  --secret=alloydb-devtest-password \
  --project=pcc-prj-app-devtest)

# Verify (do NOT echo password, just check it's set)
if [ -z "$FLYWAY_PASSWORD" ]; then
  echo "ERROR: Password not fetched"
  exit 1
else
  echo "Password fetched successfully"
fi
```

**Security Note**: Password stored in environment variable (not displayed). Will be cleared after session.

---

## Step 5: Create Database (First Time Only)

**Check if database exists**:
```bash
PGPASSWORD=$FLYWAY_PASSWORD psql \
  -h localhost \
  -p 5432 \
  -U postgres \
  -d postgres \
  -c "\l" | grep client_api_db
```

**If database does NOT exist**, create it:
```bash
PGPASSWORD=$FLYWAY_PASSWORD psql \
  -h localhost \
  -p 5432 \
  -U postgres \
  -d postgres \
  -c "CREATE DATABASE client_api_db;"
```

**Expected**: `CREATE DATABASE`

**If database exists**, skip this step.

---

## Step 6: Execute Flyway Migrations

```bash
# Run from pcc-client-api root
cd ~/pcc/src/pcc-client-api

# Execute migrations
flyway migrate \
  -url=jdbc:postgresql://localhost:5432/client_api_db \
  -user=postgres \
  -password="$FLYWAY_PASSWORD" \
  -locations=filesystem:./PortfolioConnect.Client.Api/Migrations/Scripts/v1 \
  -schemas=public
```

**Expected Output**:
```
Flyway Community Edition 9.x.x by Redgate

Database: jdbc:postgresql://localhost:5432/client_api_db (PostgreSQL 15.x)
Schema history table "public"."flyway_schema_history" does not exist yet
Successfully validated 1 migration (execution time 00:00.123s)
Creating Schema History table: "public"."flyway_schema_history" ...
Current version of schema "public": << Empty Schema >>
Migrating schema "public" to version "1 - InitialCreation"
Successfully applied 1 migration to schema "public", now at version v1 (execution time 00:01.456s)
```

**Key Success Indicators**:
- ✅ `Successfully validated 1 migration` (developer's V1__InitialCreation.sql)
- ✅ `Creating Schema History table: "public"."flyway_schema_history"`
- ✅ `Migrating schema "public" to version "1 - InitialCreation"`
- ✅ `Successfully applied 1 migration to schema "public"`

---

## Step 7: Verify Database Schema

### List Tables
```bash
PGPASSWORD=$FLYWAY_PASSWORD psql \
  -h localhost \
  -p 5432 \
  -U postgres \
  -d client_api_db \
  -c "\dt public.*"
```

**Expected Output** (showing developer's 13 tables + 2 history tables):
```
                      List of relations
   Schema  |         Name              | Type  |  Owner
-----------+---------------------------+-------+----------
 public    | Lookups                   | table | postgres
 public    | Parents                   | table | postgres
 public    | Portcos                   | table | postgres
 public    | ParentDetails             | table | postgres
 public    | PortcoDetails             | table | postgres
 public    | ParentChildren            | table | postgres
 public    | ParentPortcos             | table | postgres
 public    | ParentAudits              | table | postgres
 public    | PortcoAudits              | table | postgres
 public    | ParentDetailsAudits       | table | postgres
 public    | PortcoDetailsAudits       | table | postgres
 public    | ParentChildAudits         | table | postgres
 public    | ParentPortcoAudits        | table | postgres
 public    | flyway_schema_history     | table | postgres
 public    | __EFMigrationsHistory     | table | postgres
(15 rows)
```

### Verify Migration History
```bash
PGPASSWORD=$FLYWAY_PASSWORD psql \
  -h localhost \
  -p 5432 \
  -U postgres \
  -d client_api_db \
  -c "SELECT installed_rank, version, description, success FROM public.flyway_schema_history ORDER BY installed_rank;"
```

**Expected Output**:
```
 installed_rank | version |    description     | success
----------------+---------+--------------------+---------
              1 | 1       | InitialCreation    | t
(1 row)
```

### Verify Table Structure
```bash
PGPASSWORD=$FLYWAY_PASSWORD psql \
  -h localhost \
  -p 5432 \
  -U postgres \
  -d client_api_db \
  -c "\d public.\"Lookups\""
```

**Expected**: Table definition with columns from developer's script:
- `Id` (integer, primary key)
- `Category` (varchar 50)
- `Name` (varchar 100)
- `Code` (varchar 50)
- `Description` (varchar 500)
- `SortOrder` (integer)
- `IsActive` (boolean)
- `UpdatedAt` (timestamp with time zone)
- `UpdatedBy` (varchar 100)

### Verify Extensions
```bash
PGPASSWORD=$FLYWAY_PASSWORD psql \
  -h localhost \
  -p 5432 \
  -U postgres \
  -d client_api_db \
  -c "\dx"
```

**Expected**: No custom extensions (developer's script uses only built-in PostgreSQL types)
- Default extensions like `plpgsql` may be present
- No `uuid-ossp` or `citext` in this migration

---

## Step 8: Stop Auth Proxy

```bash
# Kill Auth Proxy process
kill $PROXY_PID

# Verify stopped
ps aux | grep alloydb-auth-proxy
```

**Expected**: No Auth Proxy process running

---

## Validation Checklist

- [ ] Flyway CLI installed and verified
- [ ] Auth Proxy installed and verified
- [ ] Auth Proxy started successfully (port 5432)
- [ ] Password fetched from Secret Manager
- [ ] Database `client_api_db` exists
- [ ] Flyway migrations executed successfully (1 applied: V1__InitialCreation)
- [ ] Schema: `public` (confirmed with developer)
- [ ] Tables exist: 13 developer tables + flyway_schema_history + __EFMigrationsHistory (15 total)
- [ ] Developer's tables: Lookups, Parents, Portcos, ParentDetails, PortcoDetails, ParentChildren, ParentPortcos, and 6 audit tables
- [ ] Migration history has 1 row (V1__InitialCreation)
- [ ] Auth Proxy stopped cleanly

---

## Troubleshooting

### Issue: "Permission denied on Secret Manager"
**Cause**: gcloud not authenticated or insufficient IAM permissions

**Resolution**:
```bash
# Check authentication
gcloud auth list

# Authenticate if needed
gcloud auth login

# Verify project
gcloud config get-value project

# Set project if wrong
gcloud config set project pcc-prj-app-devtest
```

### Issue: "Could not connect to AlloyDB"
**Cause**: Auth Proxy not running or wrong connection name

**Resolution**:
```bash
# Verify Auth Proxy running
ps aux | grep alloydb-auth-proxy

# Check connection name format (must be full resource path)
# Correct: projects/pcc-prj-app-devtest/locations/us-east4/clusters/pcc-alloydb-devtest
```

### Issue: "Database does not exist"
**Cause**: First-time setup, database not yet created

**Resolution**: Run Step 5 to create database

### Issue: "Flyway validation failed"
**Cause**: SQL syntax error in migration scripts

**Resolution**:
```bash
# Check developer's SQL file
cat PortfolioConnect.Client.Api/Migrations/Scripts/v1/V1__InitialCreation.sql

# Test SQL manually
PGPASSWORD=$FLYWAY_PASSWORD psql \
  -h localhost \
  -p 5432 \
  -U postgres \
  -d client_api_db \
  -f PortfolioConnect.Client.Api/Migrations/Scripts/v1/V1__InitialCreation.sql
```

### Issue: "Migrations already applied"
**Cause**: Re-running migrations on existing database

**Resolution**: This is normal. Flyway skips already-applied migrations.

**If you need to re-apply** (development only, NEVER in production):
```bash
# DANGER: This drops all tables in public schema
PGPASSWORD=$FLYWAY_PASSWORD psql \
  -h localhost \
  -p 5432 \
  -U postgres \
  -d client_api_db \
  -c "DROP TABLE IF EXISTS public.\"Lookups\", public.\"Parents\", public.\"Portcos\", public.\"ParentDetails\", public.\"PortcoDetails\", public.\"ParentChildren\", public.\"ParentPortcos\", public.\"ParentAudits\", public.\"PortcoAudits\", public.\"ParentDetailsAudits\", public.\"PortcoDetailsAudits\", public.\"ParentChildAudits\", public.\"ParentPortcoAudits\", public.flyway_schema_history, public.\"__EFMigrationsHistory\" CASCADE;"

# Re-run migrations
flyway migrate ...
```

**Note**: Alternatively, drop and recreate the entire database instead of individual tables.

### Issue: "Port 5432 already in use"
**Cause**: Another process (local PostgreSQL, previous Auth Proxy) using port

**Resolution**:
```bash
# Find process
lsof -i :5432

# Kill process
kill <PID>

# Or use different port
alloydb-auth-proxy ... --port=15432
```

---

## Cleanup Commands

### Stop Auth Proxy
```bash
# If PID not saved
pkill -f alloydb-auth-proxy

# Verify stopped
lsof -i :5432
```

### Clear Password Variable
```bash
unset FLYWAY_PASSWORD
```

---

## Post-Deployment Actions

**DO NOT PROCEED** until:
- ✅ 1 migration applied successfully (V1__InitialCreation from developer)
- ✅ 15 tables exist in database (13 developer tables + flyway_schema_history + __EFMigrationsHistory)
- ✅ Migration history shows 1 successful migration
- ✅ No SQL errors

**Connection Info for Applications** (Phase 3+):
- **Host**: Via Auth Proxy (sidecar in K8s pod) or PSC endpoint
- **Port**: 5432
- **Database**: `client_api_db` (NO environment suffix)
- **Schema**: `public` (confirmed by developer)
- **User**: `postgres`
- **Password**: From Secret Manager (`alloydb-devtest-password`)

---

## Future: Cloud Build Integration (Phase 4+)

When migrating to Cloud Build pipeline:
- Auth Proxy runs as Cloud Build step
- Flyway runs as Cloud Build step
- Service account authentication (not user credentials)
- Same SQL scripts, different execution environment

**Example Cloud Build step**:
```yaml
- name: 'flyway/flyway:9-alpine'
  entrypoint: 'flyway'
  args:
  - 'migrate'
  - '-url=jdbc:postgresql://$$CONNECTION_NAME/client_api_db'
  - '-user=postgres'
  - '-password=$$FLYWAY_PASSWORD'
```

---

## Next Steps

**Phase 2.12** will:
- Validate entire deployment end-to-end
- Test AlloyDB connectivity from different methods
- Document connection patterns for applications
- Create deployment summary

---

## References

- **Flyway CLI**: https://flywaydb.org/documentation/usage/commandline
- **AlloyDB Auth Proxy**: https://cloud.google.com/alloydb/docs/auth-proxy/overview
- **PostgreSQL psql**: https://www.postgresql.org/docs/current/app-psql.html

---

## Time Estimate

- **Install Flyway** (if needed): 3-5 minutes
- **Install Auth Proxy** (if needed): 2-3 minutes
- **Start Auth Proxy**: 1 minute
- **Fetch password**: 30 seconds
- **Create database** (first time): 30 seconds
- **Execute migrations**: 2-3 minutes
- **Verify schema**: 3-5 minutes
- **Total**: 12-18 minutes (15-20 if installing tools)

---

**Status**: Ready for execution
**Next**: Phase 2.12 - Validation and Deployment Summary
