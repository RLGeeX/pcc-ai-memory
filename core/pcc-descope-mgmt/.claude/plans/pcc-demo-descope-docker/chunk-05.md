# Chunk 5: Authentication Flow & Session Management

## Objective
Complete the authentication flow with proper session handling and redirects.

## Tasks
1. Update `src/hooks/useAuth.ts`:
   - Add `login` function (redirect to login page)
   - Add `logout` function with session cleanup
   - Add `getAccessToken` for API calls
   - Handle token refresh automatically (SDK handles this)

2. Create `src/components/ProtectedRoute.tsx`:
   - Check authentication status via `useSession`
   - Redirect to `/login` if not authenticated
   - Show loading spinner while checking auth
   - Render children if authenticated

3. Update `src/pages/LoginPage.tsx`:
   - Redirect to `/dashboard` on successful login
   - Store tenant context if needed
   - Handle "already logged in" state

4. Create `src/components/LogoutButton.tsx`:
   - Simple button that calls logout
   - Redirects to login after logout

5. Update routes to use `ProtectedRoute`:
   - Wrap `/dashboard` with protection

## Deliverables
- Updated `src/hooks/useAuth.ts`
- `src/components/ProtectedRoute.tsx`
- Updated `src/pages/LoginPage.tsx`
- `src/components/LogoutButton.tsx`
- Updated `src/routes/index.tsx`

## Verification
```bash
docker compose up
# 1. Navigate to /dashboard -> redirected to /login
# 2. Complete Descope login flow
# 3. Redirected to /dashboard
# 4. Refresh page -> still authenticated
# 5. Click logout -> redirected to /login
```

## Story Points: 2
## Jira: TBD (sub-task under PCC-330)
