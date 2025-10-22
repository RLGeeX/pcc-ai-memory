# AI CLI Commands for External Consultation

Commands for calling external AI CLIs directly (gemini, codex, claude) for specialized tasks like planning, code review, and architectural decisions.

## Gemini CLI

**Installation:**
```bash
npm install -g @google/gemini-cli
# Authenticate with OAuth
gemini
# Follow OAuth prompts to authorize with Google account
```

**Basic Usage:**
```bash
# Interactive mode (maintains conversation history)
gemini

# One-shot mode (single question)
gemini -p "What is 2+2?"
echo "question text" | gemini -p "question text"

# With file context
gemini -p "Explain this code" /path/to/file.py

# Multi-line prompts with heredoc
gemini -p "$(cat <<'EOF'
You are an expert architect.
Task: Design a scalable system...
Context: ...
EOF
)"
```

**Key Flags:**
- `-p, --prompt`: Prompt text (one-shot mode)
- `-i, --prompt-interactive`: Execute prompt then continue interactively
- `-m, --model`: Specify model (defaults to gemini-2.5-pro)
- `-s, --sandbox`: Run in sandbox environment
- `-y, --yolo`: Auto-approve all tool calls (use with caution)
- `--telemetry false`: Disable telemetry

**🚨 IMPORTANT - Timeout for Long-Running Prompts:**
When calling Gemini via Bash tool, ALWAYS use a 10-minute timeout (600000ms) to prevent background process issues:
```bash
# Bash tool with 10-minute timeout
Bash(command: 'gemini -p "..."', timeout: 600000)
```

**Configuration:**
- Settings: `~/.gemini/settings.json`
- OAuth credentials: `~/.gemini/oauth_creds.json`
- Current account: `~/.gemini/google_accounts.json`

**Example - Architecture Planning:**
```bash
gemini -p "$(cat <<'EOF'
You are a GCP cloud architect for PortCo Connect.

Task: Design Terraform module structure for Apigee API Gateway integration.

Requirements:
- 7 microservices (auth, client, user, metric-builder, metric-tracker, task-builder, task-tracker)
- GKE backend with Workload Identity
- Multi-environment (dev/staging/prod)
- Shared infrastructure in pcc-app-shared-infra
- Reusable modules in pcc-tf-library

Output: Terraform module hierarchy and configuration examples.
EOF
)"
```

## Codex CLI

**Installation:**
```bash
# Install via mise or package manager (see Sourcegraph docs)
# Authenticate via oauth or API token
codex login
```

**Basic Usage:**
```bash
# Interactive mode
codex

# One-shot execution (non-interactive)
codex exec "What is 2+2?"
echo "question" | codex exec --skip-git-repo-check "question"

# Resume previous session
codex resume
codex resume --last  # Continue most recent session

# With file context
codex exec "Review this code" --files src/auth/login.cs
```

**Key Flags:**
- `exec`: Run non-interactively (required for one-shot)
- `--skip-git-repo-check`: Skip git repository trust check (needed in WSL/multi-repo)
- `--json`: Output in JSON format
- `--dangerously-bypass-approvals-and-sandbox`: Auto-approve tool calls (use with caution)
- `-c, --config`: Override config values

**🚨 IMPORTANT - Timeout for Long-Running Prompts:**
When calling Codex via Bash tool, ALWAYS use a 10-minute timeout (600000ms) to prevent background process issues:
```bash
# Bash tool with 10-minute timeout
Bash(command: 'codex exec --skip-git-repo-check "..."', timeout: 600000)
```

**Configuration:**
- Config: `~/.codex/config.toml`
- Trusted directories configured in config under `[projects]`

**Example - Code Review:**
```bash
codex exec --skip-git-repo-check "$(cat <<'EOF'
You are a senior .NET code reviewer.

Task: Review the authentication API for security vulnerabilities.

Files to review:
- src/pcc-auth-api/Controllers/AuthController.cs
- src/pcc-auth-api/Services/DescopeAuthService.cs

Focus on:
- JWT validation
- Descope token handling
- Error handling and logging
- OWASP Top 10 vulnerabilities

Output: Security findings with severity levels.
EOF
)"
```

## Claude CLI

**Installation:**
```bash
# Install Claude Code CLI (if available separately)
# Authenticate via API key
export ANTHROPIC_API_KEY="sk-ant-..."
```

**Basic Usage:**
```bash
# One-shot mode
claude --print --output-format json --model sonnet "question"

# With file context
claude --print --files src/file.cs "review this code"
```

**Key Flags:**
- `--print`: Print output to stdout
- `--output-format json`: JSON output
- `--model`: Specify model (sonnet, opus, haiku)
- `--permission-mode acceptEdits`: Auto-approve edits

## Integration with Subagents

Subagents can call these CLIs directly via Bash to leverage specialized capabilities:

**Example - deployment-engineer calls gemini:**
```bash
# Inside deployment-engineer subagent task
PROMPT="Create Terraform provisioning guide for GCP resources..."
OUTPUT=$(gemini -p "$PROMPT")
# Process and synthesize output
```

**Example - cloud-architect calls codex:**
```bash
# Inside cloud-architect subagent task
codex exec --skip-git-repo-check "$(cat <<'EOF'
Analyze infrastructure dependencies...
EOF
)" > /tmp/codex-analysis.txt
```

## Best Practices

1. **🚨 ALWAYS use 10-minute timeout** - Set `timeout: 600000` in Bash tool to prevent background processes
2. **Use heredoc for multi-line prompts** - Cleaner than string concatenation
3. **Provide context** - Include file paths, architecture, requirements
4. **Specify role** - "You are a [role]" at the start of prompts
5. **Define output format** - Request structured output (markdown, sections, bullet points)
6. **Capture output** - Redirect to files for further processing
7. **Gemini for research** - Has web search, 1M context window
8. **Codex for code** - Deep code understanding, repo analysis
9. **Claude for reasoning** - Complex problem solving, architectural decisions

## Common Workflows

**Parallel consultation:**
```bash
# Launch multiple consultations simultaneously
gemini -p "Question 1..." > /tmp/gemini-output.txt &
codex exec --skip-git-repo-check "Question 2..." > /tmp/codex-output.txt &
wait
# Synthesize results
```

**Sequential refinement:**
```bash
# Gemini: Initial research
RESEARCH=$(gemini -p "Research latest Terraform best practices for GCP...")
# Codex: Apply to codebase
codex exec --skip-git-repo-check "Given research: $RESEARCH, apply to pcc-tf-library..."
```

## Troubleshooting

**Gemini:**
- OAuth issues: Check `~/.gemini/oauth_creds.json` timestamp
- "API key not valid": Ensure using OAuth, not API key mode
- MCP connection errors: Ignore if calling directly via Bash

**Codex:**
- "Not inside trusted directory": Add `--skip-git-repo-check` flag
- MCP timeout: Ignore if calling directly via Bash
- Session resume: Use `codex resume` or `codex resume --last`

**General:**
- Long outputs: Redirect to files instead of capturing in variables
- Token limits: Break large prompts into smaller focused questions
- Context: Provide file references rather than pasting entire files

## Related Documentation

- `.claude/quick-reference/commands.md` - General project commands
- `.claude/plans/apigee-pipeline-implementation-plan.md` - Master plan
- `docs/ai-subagent-usage.md` - Subagent delegation patterns (if exists)
