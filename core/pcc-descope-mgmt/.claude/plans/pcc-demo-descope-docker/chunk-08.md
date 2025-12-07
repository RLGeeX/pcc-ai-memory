# Chunk 8: Production Dockerfile

## Objective
Create multi-stage Dockerfile for production builds.

## Tasks
1. Create `Dockerfile` (production):
   ```dockerfile
   # Stage 1: Build
   FROM node:20-alpine AS builder
   WORKDIR /app
   COPY package*.json ./
   RUN npm ci
   COPY . .
   RUN npm run build

   # Stage 2: Production
   FROM nginx:alpine
   COPY --from=builder /app/dist /usr/share/nginx/html
   COPY nginx.conf /etc/nginx/conf.d/default.conf
   EXPOSE 80
   CMD ["nginx", "-g", "daemon off;"]
   ```

2. Create `nginx.conf`:
   - SPA routing (fallback to index.html)
   - Gzip compression
   - Cache headers for static assets
   - Security headers

3. Update `docker-compose.yml`:
   - Add `prod` profile for production build
   - Different port mapping (80:80)

4. Create `docker-compose.prod.yml`:
   - Production-specific overrides
   - Environment variables for production

5. Update `Makefile`:
   - `make build-prod` - Build production image
   - `make run-prod` - Run production container
   - `make push` - Push to registry (placeholder)

## Deliverables
- `Dockerfile`
- `nginx.conf`
- `docker-compose.prod.yml`
- Updated `Makefile`

## Verification
```bash
make build-prod
make run-prod
# App accessible at http://localhost:80
# Static files served efficiently
# SPA routing works (refresh on /dashboard works)
```

## Story Points: 2
## Jira: TBD (sub-task under PCC-332)
