# Plan: pcc-demo-descope Docker-First Implementation

## Overview
Build a React demo site for testing Descope authentication, developed entirely in Docker containers with no local Node.js dependency.

## Target
- **Directory**: `/home/jfogarty/pcc/src/pcc-demo-descope`
- **Existing**: Vite React TypeScript scaffold (from chunk 1 of previous plan)
- **Approach**: Docker-only development and runtime

## Descope Configuration (Already Set Up)
- Project ID: `P36Fmk0aqpNEvw8cOxcgvmLMmy2c`
- Flow: `pcc-password-mfa`
- Tenant: `pcc-test`
- Test User: `johnafogarty4+pcctest@gmail.com` with `test-user` role

## Jira Reference
- Epic: PCC-328 (existing)
- Stories: PCC-329-332 (may need status updates)
- Sub-tasks: PCC-333-342 (PCC-333 Done, others need restructuring)

## Phases

### Phase 1: Docker Foundation (Chunks 1-2)
Set up Docker development environment

### Phase 2: Descope Integration (Chunks 3-5)
Implement authentication with Descope SDK

### Phase 3: Protected Routes & UI (Chunks 6-7)
Build protected dashboard and user profile

### Phase 4: Production Ready (Chunks 8-9)
Multi-stage production build and documentation

## Estimated Effort
- **Total Chunks**: 9
- **Story Points**: 12 SP
- **Complexity**: Medium

## Success Criteria
- All development via `docker compose` commands
- No local Node.js/npm required
- Working Descope login flow
- Protected routes with role-based access
- Production-ready multi-stage Docker image
