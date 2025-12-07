# Chunk 6: Dashboard & User Profile

## Objective
Build the protected dashboard showing user info and role-based content.

## Tasks
1. Create `src/pages/DashboardPage.tsx`:
   - Display welcome message with user's name/email
   - Show user's roles from Descope token
   - Show tenant information (pcc-test)
   - Include logout button
   - Clean, simple layout

2. Create `src/components/UserProfile.tsx`:
   - Display user details from Descope session
   - Email, name, user ID
   - List assigned roles
   - Tenant membership

3. Create `src/components/RoleBasedContent.tsx`:
   - Accept `requiredRole` prop
   - Check user roles from session
   - Render children only if user has role
   - Optional fallback content

4. Update dashboard to demonstrate role-based content:
   - Show "Test User Section" only for `test-user` role
   - Show "Admin Section" only for admin role (will be hidden)

## Deliverables
- `src/pages/DashboardPage.tsx`
- `src/components/UserProfile.tsx`
- `src/components/RoleBasedContent.tsx`

## Verification
```bash
docker compose up
# Login with test user
# Dashboard shows:
#   - User email: johnafogarty4+pcctest@gmail.com
#   - Role: test-user
#   - "Test User Section" visible
#   - "Admin Section" hidden
```

## Story Points: 2
## Jira: TBD (sub-task under PCC-331)
