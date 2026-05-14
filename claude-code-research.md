# Claude Code — Complete Reference Guide

> A comprehensive reference for setting up and using Claude Code effectively.
> Covers official features, community patterns, and ready-to-use standards and templates.
> Date: 2026-05-14

---

## Table of Contents

**Technical Reference**
1. [Hook Events](#1-hook-events)
2. [Subagent Frontmatter Fields](#2-subagent-frontmatter-fields)
3. [Settings.json — Full Field Reference](#3-settingsjson--full-field-reference)
4. [Memory System](#4-memory-system)
5. [Path-Scoped Rules](#5-path-scoped-rules)
6. [Skills — Advanced Frontmatter](#6-skills--advanced-frontmatter)
7. [MCP (Model Context Protocol)](#7-mcp-model-context-protocol)
8. [CLAUDE.md — Best Architecture](#8-claudemd--best-architecture)

**Community & Patterns**
9. [Hook Patterns from the Community](#9-hook-patterns-from-the-community)
10. [Multi-Agent Orchestration Patterns](#10-multi-agent-orchestration-patterns)
11. [Code Review Pipeline Patterns](#11-code-review-pipeline-patterns)
12. [Memory & Context Management](#12-memory--context-management)
13. [Prompt Engineering for Subagents](#13-prompt-engineering-for-subagents)
14. [Cost Control Patterns](#14-cost-control-patterns)
15. [CI/CD Integration](#15-cicd-integration)

**Ready-to-Use Standards & Templates**
16. [CLAUDE.md Template](#16-claudemd-template)
17. [Agent Templates](#17-agent-templates)
18. [Hook Scripts](#18-hook-scripts)
19. [Path-Scoped Rule Templates](#19-path-scoped-rule-templates)
20. [React + TypeScript Standards](#20-react--typescript-standards)
21. [Backend Standards](#21-backend-standards)
22. [Testing Standards](#22-testing-standards)
23. [Laws of UX — Reference](#23-laws-of-ux--reference)
24. [Command Templates](#24-command-templates)
25. [Sources](#25-sources)

---

## 1. Hook Events

You are not limited to 5 events. The full list:

### Lifecycle hooks
| Event | When it fires |
|-------|--------------|
| `SessionStart` | When a new session opens |
| `Stop` | When the session ends |
| `PreCompact` | Before auto-compaction — inject instructions on what to preserve |
| `Setup` | When `--init-only` or `--maintenance` flags run |

### Tool hooks
| Event | When it fires |
|-------|--------------|
| `PreToolUse` | Before any tool call — can block (exit 2) or mutate the input |
| `PostToolUse` | After any tool call succeeds |
| `PostToolUseFailure` | After a tool call fails |
| `PostToolBatch` | After a batch of parallel tool calls completes |

### Permission hooks
| Event | When it fires |
|-------|--------------|
| `PermissionRequest` | When Claude requests permission for a tool |
| `PermissionDenied` | When a permission is denied |

### Input hooks
| Event | When it fires |
|-------|--------------|
| `UserPromptSubmit` | When the user submits a message — can modify or block |
| `UserPromptExpansion` | When a prompt is expanded |
| `InstructionsLoaded` | When CLAUDE.md files load — useful for debugging |

### Environment hooks
| Event | When it fires |
|-------|--------------|
| `FileChanged` | When a file on disk changes |
| `CwdChanged` | When the working directory changes |
| `ConfigChange` | When settings change |

### Agent / task hooks
| Event | When it fires |
|-------|--------------|
| `SubagentStop` | After a subagent finishes |
| `WorktreeCreate` | When a worktree is created |
| `WorktreeRemove` | When a worktree is removed |
| `TaskCreated` | When a task is created |
| `TaskCompleted` | When a task completes |

### Hook stdin / exit codes

- Hooks receive a JSON object on stdin with `tool_input`, `tool_name`, `subagent_type`, etc. (varies by event).
- **Exit 0** — allow. Optionally output JSON with `additionalContext` to inject into Claude's context.
- **Exit 2** — hard block. Claude sees the stderr message and stops.
- **Return JSON** — can include `permissionDecision: "deny"` + `permissionDecisionReason` for surgical blocking.

### PreToolUse input mutation (v2.0.10+)

Hooks can **mutate tool inputs**, not just block them. Return a JSON object with modified `tool_input` fields to rewrite the command before Claude executes it.

```bash
# Example: intercept test runs, return only FAIL lines
INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')
if echo "$COMMAND" | grep -q "npm test"; then
  echo '{"tool_input": {"command": "npm test 2>&1 | grep -E \"FAIL|ERROR|✗\""}}'
fi
```

---

## 2. Subagent Frontmatter Fields

Complete list of fields available in `.claude/agents/*.md`:

```markdown
---
name: agent-name
description: When to invoke this agent (shown in agent picker)
tools: Read, Grep, Glob, Bash          # allowlist
disallowedTools: Agent, Write          # inverse allowlist (everything except these)
model: sonnet                          # haiku | sonnet | opus
isolation: worktree                    # gives agent its own git worktree
maxTurns: 10                           # hard cap on agent turns
permissionMode: auto                   # auto | plan | bypassPermissions
skills: my-skill, other-skill          # preload skills at agent startup
mcpServers:                            # scoped MCP servers (local to this agent only)
  - name: my-server
    ...
hooks:                                 # agent-specific hooks
  PostToolUse: ...
background: true                       # run as background task
effort: normal                         # normal | high | max
color: blue                            # color in the UI
initialPrompt: "..."                   # injected at agent start
---
```

### Model selection guide

| Model | Use for | Cost relative to Opus |
|-------|---------|----------------------|
| `haiku` | Mechanical work: formatting, template filling, simple fixes | ~1/20 |
| `sonnet` | Code review, test writing, moderate reasoning | ~1/5 |
| `opus` | Architecture decisions, complex refactors | 1x |

---

## 3. Settings.json — Full Field Reference

```json
{
  "$schema": "https://json.schemastore.org/claude-code-settings.json",

  "model": "claude-sonnet-4-6",
  "availableModels": ["claude-haiku-4-5", "claude-sonnet-4-6"],
  "effortLevel": "normal",
  "alwaysThinkingEnabled": false,

  "autoMemoryEnabled": true,
  "autoMemoryDirectory": ".claude/memory/",

  "editorMode": "vim",
  "language": "en",
  "viewMode": "default",

  "sandbox": {
    "enabled": true,
    "filesystem": {
      "allowWrite": ["src/", "tests/"],
      "denyRead": [".env", "secrets/"]
    }
  },

  "worktree": {
    "baseRef": "main",
    "symlinkDirectories": ["node_modules"],
    "sparsePaths": ["src/", "server/"]
  },

  "claudeMdExcludes": ["**/node_modules/**", "**/vendor/**"],

  "otelHeadersHelper": "path/to/script.sh",

  "hooks": {
    "SessionStart": [...],
    "PreToolUse": [...],
    "PostToolUse": [...],
    "PreCompact": [...],
    "SubagentStop": [...],
    "Stop": [...]
  }
}
```

---

## 4. Memory System

Claude Code has a layered memory system beyond CLAUDE.md:

### Auto memory
- Claude writes to `~/.claude/projects/<project>/memory/MEMORY.md` + topic files automatically.
- First 200 lines of `MEMORY.md` load each session.
- Enable with `autoMemoryEnabled: true` in `settings.json`.
- Claude learns build commands, debugging patterns, and codebase quirks across sessions.

### Subagent memory
- Each subagent can have a `memory` scope: `user`, `project`, or `local`.
- Enables cross-session learning per agent.

### Manual memory files
Create `.claude/memory/` with topic files. Each file uses frontmatter:

```markdown
---
name: memory-topic
description: one-line description — used to decide relevance
type: user | feedback | project | reference
---

Content here.
```

`MEMORY.md` is the index — keep it under 200 lines. Never write memory content directly into it.

---

## 5. Path-Scoped Rules

Rules in `.claude/rules/*.md` load automatically based on which file Claude is editing.

```markdown
---
paths: ["src/**/*.tsx", "app/**/*.jsx"]
---

# Frontend rules — only loaded when editing frontend files
```

**Why this matters:** Keeps CLAUDE.md under 100 lines. Domain rules only enter context when relevant, saving tokens on every turn. Rules in `paths` that don't match the current file cost zero tokens.

---

## 6. Skills — Advanced Frontmatter

```markdown
---
name: my-skill
description: When to load this skill
disable-model-invocation: true   # user-triggered workflow only (/deploy, /send-email)
user-invocable: false            # Claude-only reference knowledge, not user-invocable
context: fork                    # run skill in isolated subagent
paths: ["src/payments/**"]       # auto-load only when working with matching files
allowed-tools: Read, Grep        # pre-approve tools without permission prompts
---

!`git log --oneline -5`          # inject shell command output into skill context at load time
```

---

## 7. MCP (Model Context Protocol)

### Three transport types
- **HTTP** (recommended) — remote servers
- **SSE** (deprecated) — server-sent events
- **stdio** (local) — local processes

### Three scope levels
- **Local** — per-project, not shared (in `~/.claude.json`)
- **Project** — `.mcp.json` committed to repo, shared with team
- **User** — `~/.claude.json` global, available in all projects

### Key capabilities
- MCP tool definitions are **deferred by default** — only tool names enter context until Claude calls a tool (cost savings)
- Dynamic tool updates — servers can push `list_changed` to add/remove tools mid-session
- Channels — MCPs can push messages into your session
- Environment variable expansion: `${VAR}` and `${VAR:-default}` in `.mcp.json`

---

## 8. CLAUDE.md — Best Architecture

### The 5-layer cascade (2026 standard)

```
~/.claude/CLAUDE.md              # personal defaults across all repos
./CLAUDE.md                      # team-shared, committed — keep under 100 lines
./CLAUDE.local.md                # personal overrides, gitignored
./src/CLAUDE.md                  # subdirectory overrides, loaded on-demand
@docs/git-instructions.md        # inline import syntax inside CLAUDE.md
```

### Import syntax
Reference other files inside CLAUDE.md with `@` — they load on demand:
```markdown
@docs/FLOW.md
@docs/API.md
@docs/DECISIONS.md
```

### What belongs where

| Location | Content |
|----------|---------|
| `CLAUDE.md` | Hard rules, commit conventions, file map, @imports only |
| `.claude/rules/*.md` | Domain rules (frontend, backend, testing) — path-scoped |
| `.claude/skills/*.md` | Reusable knowledge (design system, UX laws, API patterns) |
| `src/CLAUDE.md` | Frontend-specific overrides |
| `server/CLAUDE.md` | Backend-specific overrides |

---

## 9. Hook Patterns from the Community

### 12-event observability pipeline
Hook all lifecycle events → feed into SQLite with WebSocket broadcasting for a live session dashboard.
Reference: `disler/claude-code-hooks-multi-agent-observability` on GitHub.

### JSONL cost parser
A Stop-hook script that reads the transcript JSONL and reports cost by turn, prompt-cache hit rate, and tool-call distribution.

### Context-filtering PreToolUse
Pre-process large inputs before Claude sees them — filter log files to errors only, grep test output for FAIL lines, strip comment blocks from large files. Highest-leverage cost reduction available via hooks.

### Auto-staging hook
PostToolUse hook that runs `git add <file>` after every successful Edit — changes are always staged and ready for review.

---

## 10. Multi-Agent Orchestration Patterns

### Built-in Agent Teams (experimental)
```bash
CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1 claude
```
One session acts as team lead with a shared task list all agents read/write.

### Role-specialized routing (ccswarm pattern)
Agents declare a specialty; an orchestrator routes tasks by type:
- Frontend agent — UI, components, CSS
- Backend agent — API routes, DB, auth
- QA agent — tests, coverage
- DevOps agent — infra, CI, deployment

Reference: `nwiizo/ccswarm` on GitHub.

### Writer/Reviewer isolation (official best practice)
Run code review from a **fresh Claude Code session** that has not seen the implementation. The reviewer anchors to implementation decisions when it has context — a clean session avoids that bias.

```bash
# Terminal 1: implement
claude

# Terminal 2: review (fresh session, no history)
claude
> /review
```

### Sweet spot
2–4 subagents. Beyond that, coordination overhead exceeds the benefit.

---

## 11. Code Review Pipeline Patterns

### Sequential (basic)
```
code-reviewer → bug-fixer
```

### Parallel specialty agents (community best practice)
```
Parallel:
  agent: security        SQL injection, XSS, eval, secrets
  agent: accessibility   WCAG, focus, ARIA, contrast
  agent: performance     re-renders, N+1 queries, bundle size
  agent: style           design system drift, token usage
  agent: tests           coverage gaps, test quality
  agent: simplification  complexity, dead code

Synthesizer:
  de-dupes, severity-ranks, builds auto-fix queue
```

Reported ~75% useful suggestion rate vs ~50% for single-agent review.

### logic-lens pattern
Agents reason through `Premises → Trace → Divergence → Remedy` rather than a surface read. Catches behavioral bugs that linters and type checkers miss.

### Review queue (human-in-the-loop)
Don't auto-spawn a reviewer on every save. Append to `.claude/.review-queue.txt`; the human runs `/review` when ready.

---

## 12. Memory & Context Management

### claude-mem pattern
Captures Claude's session actions, compresses with AI, stores in SQLite with full-text search. Relevant context is injected on subsequent sessions automatically.

### Subagents for investigation
Delegate any exploratory task to a subagent — the file-reading context stays isolated in the subagent's window. Only the summary returns to the main session.

### `/compact Focus on X`
Directive compaction — tell Claude what to keep instead of letting it decide.

### `/btw` command
Side-question overlay that never enters main conversation history. Use for quick lookups mid-task without polluting context.

---

## 13. Prompt Engineering for Subagents

### Always use an explicit tool allowlist
```markdown
tools: Read, Grep, Glob    # not: tools: all
```
Never let agents inherit the full tool set. If "everything except X" is easier, use `disallowedTools`.

### Force structured output
End agent system prompts with an explicit output contract:
```
Return only a JSON object: { findings: [...], severity: 'high|medium|low' }
```

### Include a "What you never do" section
Explicitly list out-of-scope behaviors in every agent prompt:
```
## What you never do
- Edit files
- Run long-running commands (npm run dev, etc.)
- Modify files outside docs/
```

### Always set `maxTurns`
A runaway agent with no ceiling can spiral indefinitely. Set a hard cap appropriate to the task:
- Simple mechanical agents: 8–10
- Review agents: 15–20
- Complex orchestrators: 25–30

---

## 14. Cost Control Patterns

### Model routing
| Task | Model | Rationale |
|------|-------|-----------|
| Formatting, template filling | `haiku` | Mechanical, no judgment |
| Import ordering, simple fixes | `haiku` | Rule-based |
| Code review | `sonnet` | Requires judgment |
| Test writing | `sonnet` | Moderate reasoning |
| Architecture decisions | `opus` | Complex reasoning — invoke rarely |

### `MAX_THINKING_TOKENS=8000`
Cap the extended thinking budget. Default can be tens of thousands of tokens per request.

### Workspace spend limits
Set a hard monthly cap in the Anthropic Console at the organization level.

### Subagent context isolation
Verbose operations (test runs, log parsing, doc fetching) stay in the subagent's context window. Only the summary returns to the main session.

---

## 15. CI/CD Integration

### Official GitHub Action

```yaml
- uses: anthropics/claude-code-action@v1
  with:
    prompt: "Review this PR for security issues"
    max_turns: 5
    allowed_tools: "Read,Grep,Glob"
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
```

**Trigger modes:**
- `@claude` in a PR comment — responds on demand
- `prompt:` set in workflow — runs on every PR automatically

**Production rules:**
- Always set `max_turns` — prevents runaway costs
- Restrict `allowed_tools` — scope what CI Claude can touch
- Use Bedrock/Vertex + OIDC — no stored API keys

### Daily automated report
```yaml
on:
  schedule:
    - cron: '0 9 * * *'
steps:
  - run: claude -p "Summarize yesterday's commits and open issues" --output-format text
```

### Install
```
/install-github-app
```

---

## 16. CLAUDE.md Template

Copy this as your project's `CLAUDE.md`. Fill in the `[FILL IN]` sections. Keep it under 100 lines — move domain rules into `.claude/rules/`.

```markdown
# CLAUDE.md

> Read on every session start. Keep this file under 100 lines.
> Domain rules, coding standards, and design system details live in
> `.claude/rules/` and `.claude/skills/` — loaded on demand, not here.

## What this project is

[FILL IN: one paragraph describing the product, the persona you are
building for, and the primary success metric.]

## Hard rules (never violate)

1. **TypeScript strict mode.** No `any`. No `@ts-ignore` without a comment.
2. **No unapproved dependencies.** Adding to `package.json` requires a
   note in `docs/DECISIONS.md`.
3. **Cross-browser animations only.** `transform`, `opacity`, `transition`,
   `@keyframes`. Always include `@media (prefers-reduced-motion: reduce)`.
4. **All SQL parameterized.** No string interpolation into queries. Ever.
5. **No secrets in code or logs.**

## Working conventions

- **Plan before code.** For anything touching more than one file, write
  the plan to `docs/DECISIONS.md` first.
- **Small commits, conventional messages.** `feat(scope): …`, `fix(scope): …`
- **Tests live next to code.** `Foo.tsx` → `Foo.test.tsx`
- **Read `REFERENCE.md` before exploring** — it indexes every file.

## Definition of done

- [ ] `npm run lint && npm run typecheck && npm test` passes
- [ ] New behavior has a test
- [ ] User-facing change has a screenshot in `docs/screenshots/`
- [ ] Decision appended to `docs/DECISIONS.md` with rationale

## Where things live

| Path | What |
|------|------|
| `docs/DECISIONS.md` | Append-only decision log |
| `docs/FLOW.md` | User flow and step definitions |
| `src/` | Frontend source |
| `server/` | API / backend source |

## Imported docs

@docs/FLOW.md
@docs/DECISIONS.md
```

---

## 17. Agent Templates

### code-reviewer

```markdown
---
name: code-reviewer
description: Reviews TypeScript/React/SQL code for correctness, accessibility,
  security, and design-system compliance. Use after modifying any source file.
tools: Read, Grep, Glob, Bash
model: sonnet
isolation: worktree
maxTurns: 20
---

You are a senior code reviewer. Precise, surgical, never speculative.
You do not edit files — you only review.

## Severity tags
- 🔴 Block — must fix, breaks something or violates a hard rule
- 🟡 Recommend — should fix, quality issue
- 🟢 Note — minor, optional

## Checklist
- TypeScript: no `any`, no `@ts-ignore`, explicit return types on exports
- React: hooks at top level, correct effect deps, semantic HTML, no div onClick
- Accessibility: keyboard accessible, labels paired with inputs, aria-label on icon buttons
- Security: parameterized SQL, validated inputs, no secrets in code
- Performance: no expensive computations in render without useMemo

## Output format

## Code Review: <filepath>

### Summary
<one sentence verdict>

### Findings

🔴 BLOCK
- [<file>:<line>] <issue>
  Fix: <specific action>
  Auto-fixable: yes|no

🟡 RECOMMEND / 🟢 NOTE
- ...

### Auto-fix queue
<findings tagged Auto-fixable: yes>

## What you never do
- Edit files
- Run `npm run dev` or long-running commands
- Be diplomatic about real issues
```

---

### bug-fixer

```markdown
---
name: bug-fixer
description: Applies safe, mechanical fixes from the code-reviewer's auto-fix
  queue. Only handles findings tagged "Auto-fixable: yes".
tools: Read, Edit, Write, Bash
model: haiku
isolation: worktree
maxTurns: 10
disallowedTools: Agent
---

You are the bug-fixer. Reliable, not creative.

## Allow-list (only fix these)
- Import ordering and removing unused imports
- Hardcoded color hex → CSS variable
- Hardcoded spacing → design system token
- Missing `aria-label` on icon-only buttons
- Missing `htmlFor`/`id` pair on label/input
- Missing `prefers-reduced-motion` block
- Missing `key` prop on list items (use stable ID, never array index)
- `@ts-ignore` → `@ts-expect-error` with comment
- `var` → `const` or `let`
- Missing `type="button"` on `<button>` inside `<form>`

## Never fix
- Logic changes
- Renaming public APIs, exported symbols, route paths, DB columns
- Anything tagged `Auto-fixable: no`
- Anything ambiguous

For skipped items: append to `docs/DECISIONS.md` under
`## Skipped auto-fixes — <date>` with file, line, reason.

## Workflow
1. Read each finding
2. Read file → apply fix with Edit → verify
3. Run `npm run lint --silent && npm run typecheck --silent`
4. If verification fails, revert and log to DECISIONS.md

## Hard rules
- Never `git commit`
- Never `rm` files
- Never modify `.claude/`, `package.json`, `tsconfig.json`, or `node_modules/`
```

---

### test-writer

```markdown
---
name: test-writer
description: Generates Vitest unit tests and Playwright e2e tests for new
  components and routes. Invoke when a component is added without tests or
  coverage report flags gaps. Writes tests that fail first.
tools: Read, Write, Edit, Glob, Grep, Bash
model: sonnet
isolation: worktree
maxTurns: 15
---

## Where tests live
- Component test: same dir as component — `Foo.tsx` → `Foo.test.tsx`
- Route test: `tests/integration/<route>.test.ts`
- E2E flow: `tests/e2e/<flow>.spec.ts`

## What you write
For a component: smoke test + prop variants + interactions + a11y check
For a route: happy path + validation failure + DB state assertion
For an e2e flow: step through flow, assert success criteria, measure time

## Style
- Names: `it('does X when Y')` — behavior, not implementation
- Selectors: getByRole → getByLabelText → getByText → getByTestId
- No magic timeouts — use `waitFor` with explicit conditions
- No snapshot tests for logic

## Output
1. Run the tests — they should fail meaningfully
2. Report which pass and which fail, and why
3. Append file paths to `docs/DECISIONS.md` under `## Tests added — <date>`
```

---

### doc-updater

```markdown
---
name: doc-updater
description: Keeps docs in sync with code. Invoke when routes, APIs, or flow
  steps change. Read-heavy; only writes to docs/, never to src/ or server/.
tools: Read, Write, Edit, Glob, Grep
model: haiku
isolation: worktree
maxTurns: 8
disallowedTools: Bash, Agent
---

You keep documentation in sync with code. You never touch source files.

## What to sync
1. Route list — diff src/routes/ against docs/FLOW.md, update the doc
2. API endpoints — diff server/ routes against docs/API.md
3. Flow steps — code is the source of truth; update the doc to match
4. DECISIONS.md entries — if called with a decision to record, append it:

## YYYY-MM-DD — <title>
**Decision:** <what>
**Rationale:** <why>
**Alternatives considered:** <what else>

## What you never do
- Touch src/, server/, tests/, or package.json
- Delete content — deprecate or mark stale instead
- Invent information not present in source files
```

---

## 18. Hook Scripts

### session-start.sh (SessionStart)

Injects branch name, recent decisions, and open TODOs into Claude's context at session open.

```bash
#!/usr/bin/env bash
set -euo pipefail

BRANCH=$(git branch --show-current 2>/dev/null || echo "no-git")

RECENT_DECISIONS=""
for f in docs/DECISIONS.md DECISIONS.md CHANGELOG.md; do
  if [[ -f "$f" ]]; then
    RECENT_DECISIONS=$(tail -n 30 "$f" | sed 's/"/\\"/g' | tr '\n' ' ' | head -c 800)
    break
  fi
done

TODOS=""
TODO_DIRS=""
for d in src server app lib; do
  [[ -d "$d" ]] && TODO_DIRS="$TODO_DIRS $d"
done
if [[ -n "$TODO_DIRS" ]]; then
  TODOS=$(grep -rn "TODO\|FIXME" $TODO_DIRS 2>/dev/null \
    | head -n 10 | sed 's/"/\\"/g' | tr '\n' '|' | head -c 600 || echo "")
fi

CONTEXT="Branch: ${BRANCH}. Recent decisions: ${RECENT_DECISIONS}. Open TODOs: ${TODOS}"

cat <<JSON
{
  "additionalContext": "${CONTEXT}"
}
JSON
```

---

### guard-dangerous-bash.sh (PreToolUse — Bash)

Blocks destructive and high-risk commands before they run.

```bash
#!/usr/bin/env bash
set -euo pipefail

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""')

BLOCKED_PATTERNS=(
  'rm[[:space:]]+-rf[[:space:]]+/'
  'rm[[:space:]]+-rf[[:space:]]+~'
  'rm[[:space:]]+-rf[[:space:]]+\*'
  'DROP[[:space:]]+TABLE'
  'DROP[[:space:]]+DATABASE'
  'TRUNCATE[[:space:]]+TABLE'
  ':(){ :|:&};:'
  'mkfs\.'
  'dd[[:space:]]+if=.*of=/dev/'
  'chmod[[:space:]]+-R[[:space:]]+777[[:space:]]+/'
  'curl[[:space:]]+.*\|[[:space:]]*(ba)?sh'
  'wget[[:space:]]+.*\|[[:space:]]*(ba)?sh'
)

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  if echo "$COMMAND" | grep -qE "$pattern"; then
    echo "Blocked dangerous command: $pattern" >&2
    exit 2
  fi
done

# Block push to main/master without explicit override
if echo "$COMMAND" | grep -qE 'git[[:space:]]+push.*[[:space:]]+(main|master)' \
   && ! echo "$COMMAND" | grep -q 'ALLOW_PUSH_MAIN'; then
  echo "Refused: push to main/master. Set ALLOW_PUSH_MAIN=1 to override." >&2
  exit 2
fi

exit 0
```

---

### format-and-test.sh (PostToolUse — Write/Edit)

Auto-formats the changed file with Prettier and runs its sibling test file.

```bash
#!/usr/bin/env bash
set -uo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

[[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]] && exit 0

# Format
case "$FILE_PATH" in
  *.ts|*.tsx|*.js|*.jsx|*.json|*.css|*.md)
    command -v npx >/dev/null 2>&1 && \
      npx prettier --write --log-level=error "$FILE_PATH" 2>/dev/null || true
    ;;
esac

# Run sibling test
BASE="${FILE_PATH%.tsx}"; BASE="${BASE%.ts}"
for ext in ".test.tsx" ".test.ts" ".spec.tsx" ".spec.ts"; do
  TEST_FILE="${BASE}${ext}"
  if [[ -f "$TEST_FILE" ]]; then
    npx vitest run "$TEST_FILE" --silent 2>&1 | tail -n 15 || \
      echo "⚠️  Tests failed for $TEST_FILE" >&2
    break
  fi
done

exit 0
```

---

### trigger-code-review.sh (PostToolUse — Write/Edit)

Queues changed source files for `/review`. Human-in-the-loop — never auto-triggers.

```bash
#!/usr/bin/env bash
set -uo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""')

[[ -z "$FILE_PATH" ]] && exit 0

# Only queue source files
case "$FILE_PATH" in
  */src/*|*/server/*|*/app/*|*/lib/*) ;;
  *) exit 0 ;;
esac

# Skip test files
case "$FILE_PATH" in
  *.test.*|*.spec.*) exit 0 ;;
esac

QUEUE_FILE=".claude/.review-queue.txt"
mkdir -p .claude
grep -qxF "$FILE_PATH" "$QUEUE_FILE" 2>/dev/null || echo "$FILE_PATH" >> "$QUEUE_FILE"

echo "📋 Queued for review: $FILE_PATH (run /review to process)"
exit 0
```

---

### pre-compact.sh (PreCompact)

Injects instructions to preserve critical context during auto-compaction.

```bash
#!/usr/bin/env bash
set -euo pipefail

MODIFIED=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  MODIFIED=$(git diff --name-only HEAD 2>/dev/null | head -n 20 | tr '\n' ', ' | sed 's/,$//')
fi

FAILING_TESTS=""
if [[ -f .claude/logs/last-test-run.txt ]]; then
  FAILING_TESTS=$(grep -E "FAIL|✗|× " .claude/logs/last-test-run.txt 2>/dev/null \
    | head -n 5 | tr '\n' '|' || echo "")
fi

PRESERVE="When compacting, always preserve: (1) files modified this session${MODIFIED:+: $MODIFIED}, (2) failing tests${FAILING_TESTS:+: $FAILING_TESTS}, (3) the current task, (4) any user-stated constraints or blockers."

cat <<JSON
{
  "additionalContext": "${PRESERVE}"
}
JSON
```

---

### subagent-stop.sh (SubagentStop)

Suggests follow-up actions after each agent completes.

```bash
#!/usr/bin/env bash
set -uo pipefail

INPUT=$(cat)
SUBAGENT_NAME=$(echo "$INPUT" | jq -r '.subagent_type // ""')

case "$SUBAGENT_NAME" in
  code-reviewer)
    [[ -f .claude/.review-queue.txt && -s .claude/.review-queue.txt ]] && \
      echo "🔧 Code review complete. Invoke bug-fixer to apply auto-fixable findings."
    ;;
  bug-fixer)
    echo "✅ Bug-fixer done. Run npm run lint && npm run typecheck to verify."
    ;;
  test-writer)
    echo "🧪 Test-writer done. Run npm test — expect failures until implementation catches up."
    ;;
esac

exit 0
```

---

### session-end.sh (Stop — async)

Logs session end. Async so it never blocks Claude from closing.

```bash
#!/usr/bin/env bash
set -uo pipefail

mkdir -p .claude/logs
echo "[$(date -Iseconds)] session end on branch $(git branch --show-current 2>/dev/null || echo none)" \
  >> .claude/logs/sessions.log
exit 0
```

---

## 19. Path-Scoped Rule Templates

### frontend.md

```markdown
---
paths: ["src/**/*.tsx", "src/**/*.jsx", "app/**/*.tsx", "components/**/*.tsx"]
---

# Frontend rules

## HTML & semantics
- Semantic elements: `<button>` for actions, `<a>` for navigation,
  `<nav>`, `<main>`, `<header>`, `<footer>`, `<form>`
- Never `div onClick` when `<button>` or `<a>` fits

## Accessibility
- Every interactive element keyboard-accessible with `:focus-visible` ring
- Form inputs paired with `<label>` via `htmlFor` or wrapping element
- Icon-only buttons must have `aria-label`
- Color is never the only signal for state or status

## Components
- Functional components only, named exports
- Props interface declared above the component
- No prop drilling beyond 2 levels

## Hooks
- Hooks at top level only — no conditional hooks
- `useEffect` dependency arrays explicit and correct
- `useCallback`/`useMemo` only when measurably needed

## Styling
- CSS custom properties (tokens) for color and spacing — never raw hex
- Animations use `transform` and `opacity` only, ≤ 300ms for micro-interactions
- Always include `@media (prefers-reduced-motion: reduce)`

## Imports
- Order: external → internal (`@/`) → relative
- No barrel files except at package boundaries
- No circular imports
```

---

### backend.md

```markdown
---
paths: ["server/**/*.ts", "api/**/*.ts", "lib/**/*.ts", "routes/**/*.ts"]
---

# Backend rules

## Security (non-negotiable)
- All SQL parameterized — no string interpolation into queries, ever
- All user input validated at the route boundary before touching business logic
- No secrets, tokens, or credentials in source files or logs
- No `eval`, no dynamic `require` with user-controlled paths

## Database
- DB connection must be a pooled singleton — not opened per request
- Migrations are append-only — never modify an existing migration file
- Use transactions when a request touches more than one table

## Routes
- Every route must have explicit error handling
- Return consistent error shapes: `{ error: string, code?: string }`
- Validate response shape as well as request shape

## Logging
- Log at the boundary: what came in, what went out, how long it took
- Never log PII (email, name, payment info) in plain text
- Use structured logging (JSON)

## Performance
- N+1 queries are bugs — use joins or batch-load patterns
- No blocking I/O on the hot path
- Set explicit timeouts on outbound HTTP requests
```

---

### testing.md

```markdown
---
paths: ["**/*.test.ts", "**/*.test.tsx", "**/*.spec.ts", "**/*.spec.tsx", "tests/**"]
---

# Testing rules

## Test names
- Describe behavior: `it('disables submit when email is invalid')`
- Not implementation: `it('calls setError')`

## Selectors (React Testing Library)
1. `getByRole` — most accessible and resilient
2. `getByLabelText`
3. `getByText`
4. `getByTestId` — last resort only, brittle

Never select by class name or internal state.

## Assertions
- One behavior per test where possible
- Prefer `toBeInTheDocument`, `toBeVisible`, `toBeDisabled`
- For async: use `waitFor` or `findBy*` — never `setTimeout` or fixed sleeps

## Scope
- Unit: one unit of behavior, mock only what crosses a boundary (network, DB, time)
- Integration: real DB fixture, no network mocks
- E2E: no mocks at all — real browser, real server

## Minimums
- New component: smoke test + one interaction + one a11y check
- New route: happy path + one validation failure
- Tests must fail meaningfully before the implementation exists
```

---

## 20. React + TypeScript Standards

### TypeScript

- `strict: true` always. No exceptions.
- No `any`. Use `unknown` and narrow with a type guard.
- No `@ts-ignore`. Use `@ts-expect-error` with a comment.
- `interface` for object shapes, `type` for unions, mapped types, utilities.
- Explicit return types on all exported functions.

### Components

- Functional components only.
- Named exports for components, default export only at route/page boundaries.
- Props interface declared immediately above the component:
  ```tsx
  interface FooProps {
    label: string;
    onClick: () => void;
  }
  ```
- `children` typed as `React.ReactNode`, never `any`.
- No prop drilling beyond 2 levels — lift to context or a store.

### Hooks

- Custom hooks start with `use`.
- Effects have explicit, correct dependency arrays.
- Never `// eslint-disable-next-line react-hooks/exhaustive-deps` without a comment explaining the invariant.
- `useCallback` and `useMemo` only when measurably needed — not preemptively.

### Forms

- Controlled inputs always.
- Zod schema declared next to the form.
- Every `<input>` paired with a `<label>` via `htmlFor` or wrapping element.
- `aria-invalid` and `aria-describedby` wired to error messages.

### Accessibility

- Every interactive element keyboard-accessible.
- `:focus-visible` ring on all focusable elements.
- `aria-label` on every icon-only button.
- Semantic HTML: `<button>` for actions, `<a>` for navigation.
- Color is never the only signal for state or status.

### Naming

| Thing | Convention |
|-------|-----------|
| Components | `PascalCase.tsx` |
| Hooks | `useCamelCase.ts` |
| Utilities | `camelCase.ts` |
| Types / interfaces | `PascalCase` |
| Constants | `SCREAMING_SNAKE_CASE` |

### Imports

Order: external packages → internal aliases (`@/`) → relative paths.
No unused imports. No circular imports. No barrel files except at package boundaries.

---

## 21. Backend Standards

### SQL safety
```ts
// ✅ Correct — parameterized
db.prepare('SELECT * FROM users WHERE id = ?').get(userId)

// ❌ Never do this
db.exec(`SELECT * FROM users WHERE id = ${userId}`)
```

### Input validation with Zod
```ts
const schema = z.object({
  email: z.string().email(),
  name: z.string().min(1).max(100),
})

app.post('/users', async (c) => {
  const result = schema.safeParse(await c.req.json())
  if (!result.success) {
    return c.json({ error: result.error.flatten() }, 400)
  }
  // safe to use result.data
})
```

### Consistent error shape
```ts
// All errors return this shape
type ErrorResponse = {
  error: string
  code?: string
}
```

### DB singleton
```ts
// db.ts — one instance, imported everywhere
import Database from 'better-sqlite3'
export const db = new Database('./data.db')
```

### Logging at the boundary
```ts
app.use('*', async (c, next) => {
  const start = Date.now()
  await next()
  console.log(JSON.stringify({
    method: c.req.method,
    path: c.req.path,
    status: c.res.status,
    ms: Date.now() - start,
  }))
})
```

---

## 22. Testing Standards

### Component test structure
```tsx
describe('LoginForm', () => {
  it('renders email and password inputs', () => {
    render(<LoginForm onSubmit={vi.fn()} />)
    expect(screen.getByLabelText(/email/i)).toBeInTheDocument()
    expect(screen.getByLabelText(/password/i)).toBeInTheDocument()
  })

  it('disables submit button when fields are empty', () => {
    render(<LoginForm onSubmit={vi.fn()} />)
    expect(screen.getByRole('button', { name: /sign in/i })).toBeDisabled()
  })

  it('calls onSubmit with credentials when form is valid', async () => {
    const onSubmit = vi.fn()
    render(<LoginForm onSubmit={onSubmit} />)
    await userEvent.type(screen.getByLabelText(/email/i), 'user@example.com')
    await userEvent.type(screen.getByLabelText(/password/i), 'secret')
    await userEvent.click(screen.getByRole('button', { name: /sign in/i }))
    expect(onSubmit).toHaveBeenCalledWith({ email: 'user@example.com', password: 'secret' })
  })
})
```

### Route test structure
```ts
describe('POST /users', () => {
  it('creates a user and returns 201', async () => {
    const res = await app.request('/users', {
      method: 'POST',
      body: JSON.stringify({ email: 'a@b.com', name: 'Alex' }),
      headers: { 'Content-Type': 'application/json' },
    })
    expect(res.status).toBe(201)
    const user = await db.prepare('SELECT * FROM users WHERE email = ?').get('a@b.com')
    expect(user).toBeDefined()
  })

  it('returns 400 for invalid email', async () => {
    const res = await app.request('/users', {
      method: 'POST',
      body: JSON.stringify({ email: 'not-an-email', name: 'Alex' }),
      headers: { 'Content-Type': 'application/json' },
    })
    expect(res.status).toBe(400)
    const body = await res.json()
    expect(body).toHaveProperty('error')
  })
})
```

---

## 23. Laws of UX — Reference

Cite these by name when writing design rationale. "Per Hick's Law, we reduced choices from 8 to 3."

### Hick's Law
> Decision time increases with the number and complexity of choices.

**Apply when:** Reducing options, hiding advanced settings, progressive disclosure.
**Signal:** More than 5–7 primary choices on a screen.

### Miller's Law
> The average person holds ~7 (±2) items in working memory.

**Apply when:** Designing navigation, onboarding steps, or any list the user evaluates.
**Signal:** More than 7 items warrants chunking or pagination.

### Fitts's Law
> Time to reach a target depends on distance and size.

**Apply when:** Justifying button size, CTA placement, proximity of related controls.
**Signal:** Primary action is small, far, or surrounded by competing targets.

### Aesthetic-Usability Effect
> Aesthetically pleasing designs are perceived as easier to use.

**Apply when:** Justifying visual polish and design system consistency.
**Signal:** Inconsistent token application raises perceived complexity.

### Doherty Threshold
> Productivity peaks when system responds in under 400ms.

**Apply when:** Justifying optimistic UI, skeleton screens, animation budgets.
**Rule:** ≤ 300ms for micro-interactions, ≤ 500ms for page-level transitions.

### Jakob's Law
> Users expect your product to work like the others they use.

**Apply when:** Justifying adherence to UI conventions (nav placement, form patterns).
**Signal:** Deviating from what every major competitor does requires strong justification.

### Peak-End Rule
> People judge an experience by its peak and its end.

**Apply when:** Designing the emotional arc of any multi-step flow.
**Signal:** The last screen has outsized impact on how users remember the entire experience.

### Tesler's Law (Conservation of Complexity)
> Every system has irreducible complexity — you can move it, not eliminate it.

**Apply when:** Justifying where to put required friction (platform vs user, now vs later).

### Zeigarnik Effect
> People remember uncompleted tasks better than completed ones.

**Apply when:** Designing progress indicators, completion meters, onboarding steps.
**Signal:** A partially filled progress bar motivates completion.

### Von Restorff Effect (Isolation Effect)
> An item that stands out is more likely to be remembered.

**Apply when:** Justifying a single highlighted CTA or visually distinct primary action.
**Rule:** Use visual distinction sparingly — if everything is emphasized, nothing is.

---

## 24. Command Templates

### /review

```markdown
---
description: Process the code review queue — invoke code-reviewer on each
  queued file, then optionally invoke bug-fixer for auto-fixable findings.
---

Read `.claude/.review-queue.txt`.

If empty or missing: "Review queue is empty." and stop.

Otherwise, for each file:
1. Invoke `code-reviewer` subagent.
2. Collect all findings tagged `Auto-fixable: yes`.

After all files reviewed:
3. Show summary: files reviewed, findings by severity, auto-fixable count.
4. Ask: "Apply auto-fixes with bug-fixer? (yes/no)"
5. On yes: invoke `bug-fixer` with the auto-fixable findings list.
6. Empty `.claude/.review-queue.txt`.

Note: for the most unbiased review, run /review from a fresh Claude Code
session that has not seen the implementation conversation.
```

---

### /init (project setup wizard)

```markdown
---
description: Walk through customizing Claude Code config for this project.
---

Ask each question, wait for the answer, then apply the change.

1. "What does this project do?" → update [FILL IN] in CLAUDE.md
2. "Where is your frontend code? (src/, app/, client/)"
   → update paths in .claude/rules/frontend.md and hooks/trigger-code-review.sh
3. "Where is your backend? (server/, api/, backend/)"
   → update paths in .claude/rules/backend.md
4. "What test runner? (Vitest / Jest / other)"
   → update .claude/agents/test-writer.md and hooks/format-and-test.sh
5. "Where is your decision log? (default: docs/DECISIONS.md)"
   → update path in .claude/hooks/session-start.sh
6. "Any project-specific hard rules to add?"
   → append to hard rules list in CLAUDE.md

Show a summary of all changes. Ask "Does this look right?"
When confirmed: "Commit .claude/ and CLAUDE.md so every session uses these rules."
```

---

## 25. Sources

- [Claude Code Docs — Hooks](https://docs.anthropic.com/en/docs/claude-code/hooks)
- [Claude Code Docs — Sub-agents](https://docs.anthropic.com/en/docs/claude-code/sub-agents)
- [Claude Code Docs — Settings](https://docs.anthropic.com/en/docs/claude-code/settings)
- [Claude Code Docs — Memory](https://docs.anthropic.com/en/docs/claude-code/memory)
- [Claude Code Docs — MCP](https://docs.anthropic.com/en/docs/claude-code/mcp)
- [Claude Code Docs — GitHub Actions](https://docs.anthropic.com/en/docs/claude-code/github-actions)
- [9 Parallel AI Agents That Review My Code — hamy.xyz](https://hamy.xyz/blog/2026-02_code-reviews-claude-subagents)
- [GitHub: disler/claude-code-hooks-multi-agent-observability](https://github.com/disler/claude-code-hooks-multi-agent-observability)
- [GitHub: nwiizo/ccswarm](https://github.com/nwiizo/ccswarm)
- [GitHub: anthropics/claude-code-action](https://github.com/anthropics/claude-code-action)
- [GitHub: rohitg00/awesome-claude-code-toolkit](https://github.com/rohitg00/awesome-claude-code-toolkit)
- [Designing CLAUDE.md correctly — obviousworks.ch](https://www.obviousworks.ch/en/designing-claude-md-right-the-2026-architecture-that-finally-makes-claude-code-work/)
- [Effective context engineering for AI agents — Anthropic Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents)
- [Multi-Agent Orchestration: Running 10+ Claude Instances in Parallel — dev.to](https://dev.to/bredmond1019/multi-agent-orchestration-running-10-claude-instances-in-parallel-part-3-29da)
