# Chunk 3: Descope SDK Installation & Configuration

## Objective
Install Descope React SDK and configure authentication provider.

## Tasks
1. Install Descope SDK via Docker:
   ```bash
   docker compose run --rm app npm install @descope/react-sdk
   ```

2. Create `src/config/descope.ts`:
   - Export Descope project ID from environment
   - Define flow ID constant (`pcc-password-mfa`)
   - Type definitions for Descope config

3. Create `src/providers/AuthProvider.tsx`:
   - Wrap app with `AuthProvider` from Descope SDK
   - Configure project ID and base URL
   - Handle loading states

4. Update `src/main.tsx`:
   - Wrap `<App />` with `<AuthProvider>`

5. Create `.env.example`:
   - `VITE_DESCOPE_PROJECT_ID=P36Fmk0aqpNEvw8cOxcgvmLMmy2c`
   - `VITE_DESCOPE_FLOW_ID=pcc-password-mfa`

6. Update `docker-compose.yml`:
   - Add environment variables from `.env` file

## Deliverables
- Updated `package.json` with Descope SDK
- `src/config/descope.ts`
- `src/providers/AuthProvider.tsx`
- Updated `src/main.tsx`
- `.env.example`
- Updated `docker-compose.yml`

## Verification
```bash
docker compose up --build
# App starts without errors
# AuthProvider wraps the app
```

## Story Points: 1
## Jira: TBD (sub-task under PCC-330)
