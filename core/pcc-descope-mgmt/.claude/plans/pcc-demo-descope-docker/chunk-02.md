# Chunk 2: Docker Scripts & Makefile

## Objective
Create convenience scripts for Docker-based development workflow.

## Tasks
1. Create `Makefile` with targets:
   - `make dev` - Start development server
   - `make build` - Build production image
   - `make test` - Run tests in container
   - `make lint` - Run linting in container
   - `make shell` - Open shell in running container
   - `make clean` - Remove containers and volumes
   - `make install` - Install/update dependencies

2. Create `scripts/docker-dev.sh`:
   - Wrapper for common docker compose commands
   - Handle first-run npm install

3. Update `package.json` scripts for container context

4. Add README section for Docker development workflow

## Deliverables
- `Makefile`
- `scripts/docker-dev.sh`
- Updated `package.json`
- Updated `README.md`

## Verification
```bash
make dev      # Starts dev server
make shell    # Opens container shell
make lint     # Runs ESLint in container
```

## Story Points: 1
## Jira: TBD (sub-task under PCC-329)
