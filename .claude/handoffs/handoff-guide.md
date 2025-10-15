# Handoff Guide for PortCo Connect

**Important**: This guide is for local reference only. `.claude/` files, including handoffs, are NEVER committed to Git. Use this to create timestamped handoff files for personal continuity between Claude Code sessions (e.g., end of day to next morning) so Claude can resume work seamlessly.

## Purpose
Handoff files in `@.claude/handoffs/` (e.g., `Claude-2025-10-15-19-09.md`) capture project details, tasks, and context for uninterrupted Claude Code sessions. They ensure the next session picks up exactly where the last left off, avoiding ambiguity. Files are local-only, stored in `.claude/handoffs/`, and never shared or committed.

## Creating a Handoff File
At session end (e.g., end of day), create a handoff file to document progress for your next session:

1. **Check Current Time**: Use the current date and time (e.g., 2025-10-15 19:09 EDT) to name the file.
   - Format: `Claude-%Y-%m-%d-%H-%M.md` (e.g., `Claude-2025-10-15-19-09.md`)
   - Command: `date +%Y-%m-%d-%H-%M` (e.g., in bash to generate timestamp)

2. **Check Handoffs Folder**: Before creating, verify `@.claude/handoffs/` to ensure a unique filename.
   - List files: `ls -1 @.claude/handoffs/Claude-*.md`
   - If a file exists for the current timestamp (e.g., `Claude-2025-10-15-19-09.md`), append `-v2` (e.g., `Claude-2025-10-15-19-09-v2.md`). Increment further if needed (e.g., `-v3`).

3. **Create Handoff File**:
   - Use Claude Code with the prompt:  
     ```
     Please create a handoff file that clearly and concisely outlines the project details, tasks, and any relevant context for a seamless transition to the next team or individual. Ensure the file is well-structured and follows best practices as outlined in the guide at @.claude/handoffs/handoff-guide.md. Include all necessary information to avoid ambiguity and facilitate efficient continuation of the work. Make sure to check the time, when it comes to naming the file, as well as checking the handoffs folder before creating the file to make sure you have a unique file name.
     ```
   - Save as `@.claude/handoffs/Claude-$(date +%Y-%m-%d-%H-%M).md` (or with `-v2` if needed)
   - Content should include:
     - **Project Context**: Brief overview of the task/repo (e.g., "Working on Descope auth in src/pcc-auth-api")
     - **Completed Tasks**: Specific work done (e.g., "Added JWT middleware in AuthController.cs, 95% test coverage")
     - **Pending Tasks**: Open issues or blockers (e.g., "RBAC validation incomplete; token refresh bug")
     - **Next Steps**: Clear actions for resumption (e.g., "Run mise run test in src/pcc-auth-api, then update infra/pcc-auth-api-infra")
     - **References**: Key files/paths (e.g., "src/pcc-auth-api/Controllers/AuthController.cs", "@repomix-output.xml")
     - **Metadata**: Session duration, timestamp (e.g., "2 hours, 2025-10-15 19:09 EDT")
   - Keep concise: 100-200 words, use bullet points

4. **Update Status Files**:
   - Summarize in local `@.claude/status/brief.md` (overwrite from `@.claude/status/brief-template.md`)
   - Append to local `@.claude/status/current-progress.md` for personal history
   - These files remain local, never committed

## Resuming a Session
At session start (e.g., next morning):

1. **Locate Latest Handoff**:
   - Check `@.claude/handoffs/` for the most recent file: `ls -1tr @.claude/handoffs/Claude-*.md | tail -n 1`
   - Example: `@.claude/handoffs/Claude-2025-10-15-19-09.md` or `@.claude/handoffs/Claude-2025-10-15-19-09-v2.md`

2. **Review Context**:
   - Read the latest handoff file for completed tasks, pending issues, and next steps
   - Cross-reference with `@.claude/status/brief.md` and `@.claude/status/current-progress.md`

3. **Use in Claude Code**:
   - Reference the handoff in prompts:  
     ```
     Review handoff @.claude/handoffs/Claude-2025-10-15-19-09.md and continue from next steps
     ```
   - Init new `@.claude/status/brief.md` from `@.claude/status/brief-template.md` if starting fresh

## Handoff File Template
Create each handoff file (e.g., `@.claude/handoffs/Claude-2025-10-15-19-09.md`) with this structure:

```
# Session Handoff: [Brief Description, e.g., Descope Auth Implementation]

## Project Context
- [Repo/task overview, e.g., Adding authentication endpoints in src/pcc-auth-api for PortCo Connect]

## Completed Tasks
- [e.g., Implemented JWT middleware in AuthController.cs, added unit tests with 95% coverage]
- [e.g., Updated .mise.toml in src/pcc-auth-api for .NET 10]

## Pending Tasks
- [e.g., RBAC validation incomplete, token refresh fails on edge case]
- [e.g., Blocked by GCP Secret Manager config approval]

## Next Steps
- [e.g., Run mise run test in src/pcc-auth-api to verify tests]
- [e.g., Update Terraform resources in infra/pcc-auth-api-infra]
- [e.g., Sync with Argo CD in core/pcc-app-argo-config]

## References
- [e.g., src/pcc-auth-api/Controllers/AuthController.cs]
- [e.g., @repomix-output.xml for repo structure]
- [e.g., @notes/pcc-pipeline-library-creation-notes.md for pipeline context]

## Metadata
- **Session Duration**: [e.g., 2 hours]
- **Timestamp**: [e.g., 2025-10-15 19:09 EDT]
```

## Best Practices
- **Unique Filenames**: Check `@.claude/handoffs/` and use `date +%Y-%m-%d-%H-%M`. Append `-v2`, `-v3`, etc., for uniqueness if timestamp conflicts
- **Concise Content**: 100-200 words, bullet points, avoid fluff
- **Specific Details**: Include exact commands (e.g., `mise run test --project src/pcc-user-api`), file paths, errors
- **References**: Point to committed files (README.md, notes/, @repomix-output.xml) for shared context
- **Local Only**: Never commit handoff files - they’re for personal session continuity
- **Session Gaps**: Note expected changes (e.g., "Check for new PR merges before resuming")
- **Multi-Repo Tasks**: List affected repos (e.g., `src/pcc-auth-api`, `infra/pcc-auth-api-infra`) and order of actions

## Notes
- Aligns with ai-new-project template: `@template/.claude/handoffs/handoff-guide.md`
- Use for personal session transitions only (e.g., night to day), not team handoffs
- Archive old handoffs locally if `@.claude/handoffs/` grows large
- For team handoffs, use committed README.md, notes/, or PR descriptions