# Handoff Guide

## Handoff Documentation
Handoff documents are stored in `.claude/handoffs/` to ensure continuity when resuming work after a break. Use the naming convention `$TOOL-$DATE-$TIMERANGE.md`, where:
- `$TOOL` is the name of the terminal-based AI development application running the handoff (e.g., `ClaudeCode`, `OpenCode`, or `Warp`).
- `$DATE` is the current date in the format `YYYY-MM-DD` (e.g., `2025-08-30`).
- `$TIMERANGE` corresponds to the time period of the handoff, based on the following recommended ranges:
  - Morning: 06:00 - 12:00
  - Afternoon: 12:01 - 18:00
  - Evening: 18:01 - 23:00
  - Night: 23:01 - 05:59

## Example
For a handoff at 09:15 PM EDT on August 30, 2025, using ClaudeCode, the file would be named `ClaudeCode-2025-08-30-Evening.md`. If using Warp, it would be `Warp-2025-08-30-Evening.md`.

## Purpose
Handoff documents summarize the current project state, key decisions, and next steps to enable seamless resumption of work by the next team or individual.

## Structure of a Handoff Document
To ensure consistency and clarity, each handoff document should include the following sections:
1. **Project Overview**: Briefly describe the project, its objectives, and its current phase.
2. **Current State**: Detail the progress made during the session, including completed tasks, milestones reached, or issues encountered.
3. **Key Decisions**: Document any critical decisions made, including rationale and impact on the project.
4. **Pending Tasks**: List specific tasks that remain incomplete or are planned for the next session, with clear priorities.
5. **Blockers or Challenges**: Highlight any obstacles, unresolved issues, or dependencies that need attention.
6. **Next Steps**: Outline recommended actions for the next team or individual, including any urgent priorities.
7. **Contact Information**: Provide contact details for the person creating the handoff and any relevant stakeholders for questions or clarification.

## Best Practices
- **Be Concise**: Keep the document clear and to the point, avoiding unnecessary details.
- **Use Bullet Points**: Organize information in lists for easy scanning.
- **Highlight Priorities**: Clearly mark high-priority tasks or urgent issues.
- **Include References**: Link to relevant project files, repositories, or external resources to provide context.

## Additional Notes
- Ensure the handoff document is saved in the `.claude/handoffs/` directory and follows the appropriate naming convention based on the tool used (e.g., `ClaudeCode`, `OpenCode`, or `Warp`) to maintain organization.
- Review the document for completeness before sharing to avoid ambiguity.
- If using a tool other than ClaudeCode, OpenCode, or Warp, adapt the `$TOOL` prefix to match the tool’s name for consistency.