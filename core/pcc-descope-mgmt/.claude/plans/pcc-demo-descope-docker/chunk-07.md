# Chunk 7: Styling & UI Polish

## Objective
Add basic styling for a professional appearance.

## Tasks
1. Install Tailwind CSS via Docker:
   ```bash
   docker compose run --rm app npm install -D tailwindcss postcss autoprefixer
   docker compose run --rm app npx tailwindcss init -p
   ```

2. Configure Tailwind:
   - Create/update `tailwind.config.js`
   - Update `src/index.css` with Tailwind directives
   - Configure content paths

3. Style components:
   - `LoginPage`: Centered card, clean form container
   - `DashboardPage`: Header, main content area, sidebar
   - `UserProfile`: Card with user info
   - `LogoutButton`: Styled button
   - `RoleBasedContent`: Visual distinction for role sections

4. Add responsive design:
   - Mobile-friendly layout
   - Breakpoints for tablet/desktop

5. Create `src/components/Layout.tsx`:
   - Common layout wrapper
   - Header with navigation
   - Footer (optional)

## Deliverables
- Tailwind CSS configuration
- Updated `src/index.css`
- `src/components/Layout.tsx`
- Styled versions of all components

## Verification
```bash
docker compose up
# App has professional appearance
# Responsive on mobile/desktop
# Consistent styling throughout
```

## Story Points: 1
## Jira: TBD (sub-task under PCC-331)
