# Commit Message Template

🚨 **CRITICAL RULE**: NEVER mention co-authored-by or tools used in commits/PRs

## Format

```
<type>: <description>

<optional body>

<optional footer>
```

## Examples

### ✅ CORRECT Examples:

```
feat: implement user authentication system

- Add JWT token generation and validation
- Create login/logout API endpoints
- Implement password hashing with bcrypt
- Add user session management

Resolves #123: User authentication requirements
```

```
fix: resolve memory leak in data processing pipeline

- Fix unclosed file handles in batch processor
- Add proper cleanup for temporary resources
- Implement garbage collection optimization

Fixes #456: Memory usage grows continuously
```

### ❌ INCORRECT Examples (DO NOT USE):

```
feat: add new feature

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

```
fix: resolve issue with AI assistance

Implemented with Claude AI pair programming
```

## Types

- **feat**: New features
- **fix**: Bug fixes
- **refactor**: Code changes that neither fix bugs nor add features
- **test**: Adding or updating tests
- **docs**: Documentation changes
- **style**: Code style changes (formatting, etc.)
- **chore**: Maintenance tasks

## Guidelines

1. Use imperative mood ("add" not "added" or "adds")
2. Don't capitalize first letter of description
3. No period at end of description
4. Reference tickets/issues when applicable
5. Include correlation IDs for evidence when relevant
6. Keep description under 50 characters
7. Use body for detailed explanations
8. **NEVER mention AI tools, Claude Code, co-authored-by, or similar**