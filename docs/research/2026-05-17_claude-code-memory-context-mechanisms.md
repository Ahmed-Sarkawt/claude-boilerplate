# Claude Code Native Memory and Context Mechanisms

**Date:** 2026-05-17
**Requested by:** researcher agent
**Confidence:** High

## Question

What are every native feature Claude Code provides for persisting context between sessions, between subagents, and during compaction — with specific focus on what is FREE (no extra token cost) vs what burns tokens? Covers MEMORY.md, hooks (SessionStart, Stop, PreCompact, SubagentStop), autoMemoryEnabled, subagent context inheritance, RAG/indexing, isolation:worktree, subdirectory CLAUDE.md, and symlinkDirectories.

## Answer

Claude Code has two core memory systems (CLAUDE.md files and auto memory / MEMORY.md), 29 hook events for lifecycle automation, and a subagent isolation model where subagents start fresh with only the project CLAUDE.md and their own system prompt. There is no native RAG, semantic search, or file-indexing. Everything that enters the context window burns tokens; the only zero-cost mechanisms are shell-side hooks that run outside the LLM loop and produce no additionalContext output, HTML comments in CLAUDE.md, path-scoped rules not yet triggered, and skills with disable-model-invocation:true.

## Key findings

### 1. CLAUDE.md — load behavior and token cost

- Loaded as a user-turn message (NOT system prompt) injected after the system prompt. Claude reads and tries to follow it; no hard enforcement.
- TOKEN COST: YES, always. Every byte in context on every turn.
- Load locations in order (broadest to narrowest scope):
  1. `/Library/Application Support/ClaudeCode/CLAUDE.md` — org-wide managed, macOS
  2. `~/.claude/CLAUDE.md` — user-wide
  3. `./CLAUDE.md` or `./.claude/CLAUDE.md` — project-root
  4. `./CLAUDE.local.md` — personal, gitignored
- Directory walking: Claude walks UP from the working directory, loading all CLAUDE.md/CLAUDE.local.md in ancestor directories at launch.
- Subdirectory CLAUDE.md files (below the working directory): NOT loaded at launch. Loaded ON DEMAND when Claude reads a file in that subdirectory. After compaction, they are LOST until Claude reads a matching file again.
- HTML block comments (`<!-- comment -->`) are stripped before injection — zero token cost. Use for human-maintainer notes. Comments inside code blocks are preserved. When you open CLAUDE.md with the Read tool directly, comments remain visible.
- `@path/to/file` imports expand at launch; imported files count as full context tokens at startup.
- Path-scoped rules in `.claude/rules/` with `paths:` YAML frontmatter load ONLY when Claude reads a matching file — primary mechanism for keeping instructions out of context until needed.
- `claudeMdExcludes` setting: array of glob patterns to skip specific CLAUDE.md files by absolute path. Useful in monorepos with irrelevant team CLAUDE.md files.
- Target under 200 lines per CLAUDE.md. Longer files consume more context and reduce adherence.

### 2. Auto memory (MEMORY.md) — what it is and what it costs

- What it is: Claude writes its own notes to `~/.claude/projects/<git-repo>/memory/MEMORY.md`. Claude decides what to save — build commands, debugging insights, patterns, preferences.
- Requires Claude Code v2.1.59+.
- TOKEN COST: YES. The first 200 lines OR 25KB of MEMORY.md (whichever comes first) load into every session at startup. Content beyond that threshold is NOT loaded at startup.
- Storage: `~/.claude/projects/<project>/memory/` derived from git repo root. All worktrees and subdirectories within the same repo SHARE one auto memory directory.
- Topic files (e.g., `debugging.md`, `api-conventions.md`) are created by Claude to hold detailed notes. They are NOT loaded at startup — only MEMORY.md (the index) loads. Claude reads them on demand.
- `autoMemoryEnabled` setting: `true` by default. Setting `false` disables both reading and writing.
  Also disabled by env var: `CLAUDE_CODE_DISABLE_AUTO_MEMORY=1`.
- `autoMemoryDirectory` setting: custom path (absolute or ~/). Only accepted from managed/user settings and `--settings` flag. NOT accepted from project or local settings (security: a cloned repo could redirect writes to sensitive locations).
- Subagents do NOT inherit the parent session's auto memory. If a subagent has `memory: user/project/local` in its frontmatter, it gets its own separate MEMORY.md in `~/.claude/agent-memory/<agent-name>/` loaded into its system prompt.
- Toggle per-session: `/memory` command shows all loaded instruction files and lets you toggle auto memory on/off.

### 3. Compaction — exact survival table

After `/compact` or auto-compaction:

| Mechanism                                     | After compaction                                                                        |
| --------------------------------------------- | --------------------------------------------------------------------------------------- |
| System prompt + output style                  | Unchanged (not in message history)                                                      |
| Project-root CLAUDE.md + unscoped rules       | Re-injected from disk                                                                   |
| Auto memory (MEMORY.md, first 200 lines/25KB) | Re-injected from disk                                                                   |
| Path-scoped rules (paths: frontmatter)        | LOST until matching file is read again                                                  |
| Nested CLAUDE.md in subdirectories            | LOST until a file in that dir is read again                                             |
| Invoked skill bodies                          | Re-injected, capped at 5,000 tokens/skill and 25,000 tokens total; oldest dropped first |
| Skill descriptions listing                    | NOT re-injected; only skills actually invoked are preserved                             |
| Hooks                                         | Not applicable — run as code, not context                                               |
| Subagent transcripts                          | Unaffected; stored separately in their own JSONL files                                  |

Compaction summary content (~12% of original token count): keeps requests and intent, key technical concepts, files examined/modified with key snippets, errors and fixes, pending tasks.

`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE`: env var to set the auto-compaction threshold as a percentage (default ~95% context capacity).

### 4. Hook events — all 29 events, payloads, and token cost

All 29 hook events:
SessionStart, Setup, UserPromptSubmit, UserPromptExpansion, PreToolUse, PermissionRequest, PermissionDenied, PostToolUse, PostToolUseFailure, PostToolBatch, Notification, SubagentStart, SubagentStop, TaskCreated, TaskCompleted, Stop, StopFailure, TeammateIdle, InstructionsLoaded, ConfigChange, CwdChanged, FileChanged, WorktreeCreate, WorktreeRemove, PreCompact, PostCompact, Elicitation, ElicitationResult, SessionEnd

Common stdin payload for all hooks:

```json
{
  "session_id": "abc123",
  "transcript_path": "/path/to/transcript.jsonl",
  "cwd": "/current/working/directory",
  "permission_mode": "default|plan|acceptEdits|auto|dontAsk|bypassPermissions",
  "hook_event_name": "EventName",
  "effort": { "level": "low|medium|high|xhigh|max" }
}
```

When running with --agent or in a subagent:

```json
{ "agent_id": "unique-id", "agent_type": "Explore|Plan|custom-name" }
```

Environment variables available to ALL hooks:

- `CLAUDE_PROJECT_DIR` — project root
- `CLAUDE_EFFORT` — current effort level
- `CLAUDE_CODE_REMOTE` — "true" in web, unset locally

`CLAUDE_ENV_FILE`: ONLY available to SessionStart, Setup, CwdChanged, FileChanged. Write `export VAR=value` lines here to persist env vars across Bash calls in the session. This is the only zero-cost way to inject persistent state into the Bash environment.

**SessionStart payload:**

```json
{
  "source": "startup|resume|clear|compact",
  "model": "claude-sonnet-4-6"
}
```

- Can inject `additionalContext` via hookSpecificOutput (BURNS TOKENS — permanent in conversation)
- Can write to `CLAUDE_ENV_FILE` (FREE — no LLM tokens)
- matcher values: `startup`, `resume`, `clear`, `compact`

**Stop payload:**

```json
{ "effort": { "level": "high" } }
```

- `decision: "block"` + `reason` prevents Claude from stopping and continues the turn
- Exit code 2 blocks

**PreCompact payload:**

```json
{ "trigger": "manual|auto" }
```

- `decision: "block"` + `reason` prevents compaction entirely
- CANNOT influence what survives or inject a custom summary — can only prevent or allow
- matcher values: `manual`, `auto`

**PostCompact:** Observability only. No decision control. No additional fields.

**SubagentStop payload:**

```json
{
  "agent_type": "general-purpose|Explore|Plan|custom-name",
  "agent_id": "unique-id",
  "effort": { "level": "high" }
}
```

- `decision: "block"` + `reason` prevents subagent from stopping
- Exit code 2 blocks

**InstructionsLoaded payload:**

```json
{
  "file_path": "/path/my-project/CLAUDE.md",
  "memory_type": "User|Project|Local|Managed",
  "load_reason": "session_start|nested_traversal|path_glob_match|include|compact",
  "globs": ["path/glob/patterns"],
  "trigger_file_path": "/path/that/triggered/load",
  "parent_file_path": "/path/to/parent/that/included/this"
}
```

- Observability/audit logging only. No decision control.
- Use this hook to debug why CLAUDE.md files or rules are or are not loading.

**Token cost analysis:**

FREE (run outside LLM loop, no token impact):

- SessionEnd, PostCompact, Notification, InstructionsLoaded, CwdChanged, FileChanged, WorktreeRemove, StopFailure
- ANY hook that exits 0 with plain stdout — plain stdout on exit 0 goes to DEBUG LOG ONLY, not Claude's context

TOKEN-BURNING (adding additionalContext injects permanent context):

- SessionStart with additionalContext
- UserPromptSubmit with additionalContext
- PreToolUse with additionalContext or updatedInput
- PostToolUse with additionalContext
- SubagentStart with additionalContext

Hook output: to send data to Claude you MUST use `hookSpecificOutput.additionalContext` in JSON. Plain stdout is never seen by Claude.

Full output schema:

```json
{
  "continue": true,
  "stopReason": "message for user",
  "suppressOutput": false,
  "systemMessage": "warning shown in transcript",
  "terminalSequence": "\033]777;notify;...",
  "decision": "block",
  "reason": "why blocked",
  "hookSpecificOutput": {
    "hookEventName": "EventName",
    "additionalContext": "context for Claude",
    "permissionDecision": "allow|deny|ask|defer",
    "permissionDecisionReason": "why",
    "updatedInput": {},
    "worktreePath": "/path",
    "retry": true
  }
}
```

### 5. Subagent context inheritance

What a subagent gets by default (NO parent conversation history):

- Its own system prompt (shorter than main session's; for general-purpose agents it is a brief prompt plus environment details)
- Project CLAUDE.md (same file, counted against subagent's context — NOT the parent's)
- MCP tools and skill descriptions (same servers; separate prompt cache)
- The task prompt written by the parent Claude
- Its own MEMORY.md if `memory:` frontmatter is configured

What is NOT passed to subagents:

- Parent conversation history
- Parent auto memory (main session MEMORY.md)
- File reads the parent has already done
- Path-scoped rules already loaded in parent
- Any context from the parent's working context window

Built-in Explore and Plan subagents skip loading CLAUDE.md entirely for a smaller context footprint.

Zero-cost state sharing between parent and subagent:

- Write a file from the parent, read it from the subagent — only costs normal file-tool tokens, no extra API calls
- Use PreToolUse hooks on the parent to intercept writes and accumulate state in a sidecar file
- There is no zero-cost "send state to subagent" mechanism that bypasses token counting entirely

Fork subagents (CLAUDE_CODE_FORK_SUBAGENT=1, experimental, requires v2.1.117+):

- A fork inherits the ENTIRE parent conversation history, same system prompt, same tools
- First request reuses parent's prompt cache (cheaper than fresh subagent for same-context tasks)
- Fork's tool calls still stay out of parent's context; only final summary returns

Subagent transcripts:

- Stored at `~/.claude/projects/{project}/{sessionId}/subagents/agent-{agentId}.jsonl`
- Persist independently of main session compaction
- Survive for 30 days (configurable via `cleanupPeriodDays` setting)
- Subagent can be resumed by Claude using the SendMessage tool (requires CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1)

### 6. No native RAG or semantic search

Claude Code has no built-in RAG, embedding-based semantic search, or file indexing mechanism. File suggestion in the UI uses fast filesystem traversal. For semantic search you would need to implement it via an MCP server. The Anthropic API separately offers embeddings but they are not wired into Claude Code natively.

### 7. isolation: worktree — effect on memory and context

`isolation: worktree` in a subagent frontmatter gives the subagent a temporary git worktree so file edits are written to an isolated copy rather than your main checkout. It has NO effect on memory or context inheritance — the subagent still gets its own fresh context, still loads project CLAUDE.md, still has no access to parent conversation history.

The worktree is auto-cleaned if the subagent makes no changes.

`worktree.symlinkDirectories` (settings.json):

- Symlinks specified directories (e.g., `["node_modules", ".cache"]`) from the main repo into new worktrees to avoid duplicating large directories on disk
- Purely a disk-space optimization
- NO effect on context, memory, or what any agent can see

### 8. Subdirectory CLAUDE.md — auto-loading behavior and token cost

- YES, auto-loaded, but NOT at launch
- Loaded on demand when Claude reads a file in that subdirectory
- YES, they burn tokens when loaded
- After compaction: LOST until Claude reads a file in that subdirectory again
- The InstructionsLoaded hook fires with `load_reason: "nested_traversal"` when a subdirectory CLAUDE.md loads — use for auditing/debugging

### 9. Zero-cost and low-cost context patterns (confirmed)

1. HTML comments in CLAUDE.md: `<!-- notes -->` stripped before injection. Zero token cost.
2. Path-scoped rules: only load when a matching file is read. If never triggered, zero tokens.
3. Skills with `disable-model-invocation: true`: NOT listed in skill descriptions index at startup. Zero tokens until explicitly invoked with `/skill-name`.
4. Shell-side hooks with no additionalContext: exit 0 with plain stdout goes to debug log only. Zero LLM cost.
5. `CLAUDE_ENV_FILE` in SessionStart: write `export VAR=value`; the env var persists to subsequent Bash calls in the session. Zero tokens consumed.
6. Subagent isolation (non-fork): file reads inside a subagent stay in subagent's context; only final summary returns to parent.
7. `/btw` command: asks a quick question using current context but the answer is discarded, not added to history. Zero persistent token cost.
8. MCP tool deferral (default): only tool names listed (~120 tokens); full schemas load on demand. `ENABLE_TOOL_SEARCH=false` loads everything upfront (more tokens).

### 10. Startup context cost breakdown (approximate)

From the official context window visualization:

| Component                        | Approximate tokens |
| -------------------------------- | ------------------ |
| System prompt                    | ~4,200             |
| Auto memory (MEMORY.md)          | ~680               |
| Environment info                 | ~280               |
| MCP tools (deferred, names only) | ~120               |
| Skill descriptions               | ~450               |
| User CLAUDE.md                   | ~320               |
| Project CLAUDE.md                | ~1,800 (varies)    |
| Total before first prompt        | ~7,850             |

These are illustrative — actual values depend on file sizes, MCP server count, and skill count.

## Sources

- [How Claude remembers your project — Claude Code Docs](https://code.claude.com/docs/en/memory) — official memory documentation, primary authoritative source
- [Hooks reference — Claude Code Docs](https://code.claude.com/docs/en/hooks) — official hooks documentation with full event payloads and schemas
- [Settings reference — Claude Code Docs](https://code.claude.com/docs/en/settings) — official settings documentation including autoMemoryEnabled, autoMemoryDirectory, claudeMdExcludes, worktree settings
- [Create custom subagents — Claude Code Docs](https://code.claude.com/docs/en/sub-agents) — official subagent documentation including memory frontmatter, isolation, fork behavior
- [Explore the context window — Claude Code Docs](https://code.claude.com/docs/en/context-window) — context window visualization with compaction survival table and token cost breakdown

## Gaps

- PreCompact cannot inject a custom summary: confirmed you can only block or allow compaction, not influence what the summary contains. There is no documented way to inject custom content into the compaction summary without it costing tokens in the prior conversation.
- PostCompact provides no additional payload fields beyond the common ones.
- Exact Claude Code version when newer hook events (InstructionsLoaded, PostCompact, ElicitationResult, WorktreeCreate/Remove) were introduced is not pinned in the docs.
- Whether SessionStart additionalContext participates in prompt cache (reducing cost on repeated sessions) is not documented.
- The `CLAUDE_CODE_FORK_SUBAGENT` feature is marked experimental and behavior may change.
