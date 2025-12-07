# Chunk 1: Docker Development Environment

## Objective
Create Dockerfile and docker-compose.yml for containerized development with hot reload.

## Tasks
1. Create `Dockerfile.dev` for development:
   - Base: `node:20-alpine`
   - Working directory: `/app`
   - Install dependencies via volume mount
   - Expose port 5173 for Vite dev server

2. Create `docker-compose.yml`:
   - Service: `app` using Dockerfile.dev
   - Volume mounts for source code and node_modules
   - Port mapping: 5173:5173
   - Environment variables placeholder for Descope

3. Create `docker-compose.override.yml` (optional local settings)

4. Add `.dockerignore` to exclude node_modules, dist, etc.

5. Update `vite.config.ts` for Docker:
   - Set `server.host: '0.0.0.0'` for container access
   - Enable HMR with proper WebSocket config

## Deliverables
- `Dockerfile.dev`
- `docker-compose.yml`
- `.dockerignore`
- Updated `vite.config.ts`

## Verification
```bash
docker compose up --build
# App accessible at http://localhost:5173
# Hot reload works when editing src files
```

## Story Points: 2
## Jira: TBD (sub-task under PCC-329)
