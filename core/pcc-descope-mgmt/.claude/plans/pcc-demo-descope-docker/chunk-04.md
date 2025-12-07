# Chunk 4: Login Page with Descope Flow

## Objective
Create login page using Descope's embedded flow component.

## Tasks
1. Create `src/pages/LoginPage.tsx`:
   - Use `<Descope>` component from SDK
   - Configure with `pcc-password-mfa` flow
   - Handle `onSuccess` callback for redirect
   - Handle `onError` callback for error display
   - Style container for centered login form

2. Create `src/hooks/useAuth.ts`:
   - Export `useSession` and `useUser` from Descope SDK
   - Add helper functions: `isAuthenticated`, `logout`
   - Type the user object properly

3. Create basic routing structure:
   - Install react-router-dom via Docker
   - Create `src/routes/index.tsx` with route definitions
   - Public route: `/login`
   - Protected route: `/dashboard` (placeholder)

4. Update `src/App.tsx`:
   - Add `BrowserRouter` wrapper
   - Render routes

## Deliverables
- `src/pages/LoginPage.tsx`
- `src/hooks/useAuth.ts`
- `src/routes/index.tsx`
- Updated `src/App.tsx`
- Updated `package.json` (react-router-dom)

## Verification
```bash
docker compose up
# Navigate to http://localhost:5173/login
# Descope login flow renders
# Can enter credentials (don't need to complete login yet)
```

## Story Points: 2
## Jira: TBD (sub-task under PCC-330)
