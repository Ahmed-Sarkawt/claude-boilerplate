# Claude Code Experimental Agent Team Architecture and Improvement Patterns

**Date:** 2026-05-25
**Requested by:** researcher agent
**Confidence:** High

## Question

What are the documented behaviors of `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`, and what concrete improvements can be made to a 7-agent code-quality pipeline (researcher, code-reviewer, bug-fixer, test-writer, ux-auditor, doc-updater, research-executor) that communicates via files and fires hooks on session open, file save, context fill, agent stop, and session close?

## Answer

`CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1` enables a native, coordinated multi-session mode distinct from normal subagent calls: teammates share a task list, send messages to each other directly, can be talked to individually without going through the lead, and use file-locked task claiming to prevent race conditions. The feature requires Claude Code v2.1.32+ and has seven documented limitations (no nested teams, no session resumption for in-process teammates, one team at a time, etc.). The current 7-agent pipeline already follows sound architecture, but has five concrete improvement opportunities: (1) add missing roles (planner, security-auditor, dependency-auditor, judge/evaluator), (2) sharpen agent system prompts with explicit output contracts, (3) use hooks for quality gates (`TeammateIdle`, `TaskCompleted`, `TaskCreated`), (4) route cheaper tasks to Haiku (Haiku: $1/$5 per MTok, Sonnet: $3/$15, Opus: $5/$25), and (5) add an independent judge agent whose prompt is never shown to the producing agents.

## Key findings

### 1. What CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS actually enables

Enabling the env var (`"CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"` in `settings.json` or shell) activates a mode that is architecturally different from subagents:

| Dimension     | Subagents (normal)                  | Agent teams (experimental)                    |
| ------------- | ----------------------------------- | --------------------------------------------- |
| Communication | Report results to main agent only   | Teammates message each other directly         |
| Coordination  | Main agent manages all work         | Shared task list with self-claim              |
| Context       | Own window, results summarized back | Own window, fully independent                 |
| Best for      | Focused tasks, result matters       | Work requiring inter-agent discussion         |
| Token cost    | Lower                               | Higher (each teammate = full Claude instance) |

**Architecture internals (from official docs):**

- **Task list** stored at `~/.claude/tasks/{team-name}/` — teammates claim tasks using file locking to prevent races
- **Mailbox** system delivers messages between agents automatically; lead does not need to poll
- **Team config** at `~/.claude/teams/{team-name}/config.json` holds session IDs and pane IDs; do not edit by hand
- Teammates load `CLAUDE.md`, MCP servers, and skills, but **not the lead's conversation history**
- Subagent definitions in `.claude/agents/` can be used as teammate types — the definition body is appended to the teammate's system prompt, not replacing it
- `skills` and `mcpServers` frontmatter fields are **not applied** when a definition runs as a teammate (they come from project/user settings instead)

**Documented limitations to design around:**

1. No session resumption for in-process teammates (`/resume` and `/rewind` do not restore them)
2. Task status can lag — teammates sometimes fail to mark tasks complete, blocking dependent tasks
3. Shutdown can be slow (finishes current request first)
4. One team at a time per lead
5. No nested teams — teammates cannot spawn their own teams
6. Lead is fixed for team lifetime — cannot promote a teammate to lead
7. Permissions set at spawn time from lead's mode

### 2. Agent architecture best practices for code-quality pipelines

Anthropic's own multi-agent Research system (Claude Opus 4 lead + Claude Sonnet 4 subagents) outperformed single-agent Opus 4 by **90.2%** on internal evaluations. Key findings:

**Orchestrator/worker pattern:** The lead agent decomposes queries into subtasks at runtime (not pre-defined), delegates with detailed specs, and synthesizes results. Each subtask description must include: objective, output format, tools/sources to use, and clear task boundaries. Without this, agents duplicate work or leave gaps.

**Parallelism yields massive gains:** The research team reduced completion time by up to 90% by (a) having the lead spawn 3–5 subagents simultaneously rather than serially, and (b) having each subagent use 3+ tools concurrently. The current project's file-based handoff is correct but adds latency; direct agent messaging (available only with `AGENT_TEAMS`) removes that round-trip.

**Token economics reality:** Agentic tasks use ~4× more tokens than chat; multi-agent systems use ~15× more. Token count alone explains 80% of performance variance. Prompt phrasing, style, and instruction format did not show as primary drivers — raw token budget matters most.

**Effort scaling in prompts:** Embed explicit scaling rules in the orchestrator prompt (e.g., "if the task touches fewer than 3 files, skip the security-auditor agent"). Without this, agents struggle to judge appropriate effort.

**Blackboard/shared-state pattern:** File-based communication (the current approach) implements the blackboard pattern — agents write results to shared files that other agents read. This is correct for async pipelines. The enhancement with agent teams is that the shared task list is managed natively rather than manually.

### 3. Strong vs. weak agent system prompts

Based on official subagent docs and Anthropic's engineering blog:

**The body of a `.claude/agents/*.md` file becomes the entire system prompt.** Subagents receive only this prompt plus basic environment details (working directory, date) — not the full Claude Code system prompt. This means every agent file must be self-contained.

**Weak prompt (current risk):**

```markdown
You are a code reviewer. Review the code and provide feedback.
```

**Strong prompt structure (concrete, contract-based):**

````markdown
You are a code reviewer for this project. You are invoked after every
code change. Your exclusive job is to find defects — not to praise, not
to suggest refactors unless they fix a correctness issue.

**Output contract (REQUIRED — always return exactly this structure):**

```json
{
  "verdict": "pass" | "fail" | "warn",
  "issues": [
    {
      "file": "<path>",
      "line": <n>,
      "severity": "error" | "warning",
      "rule": "<what was violated>",
      "fix": "<concrete corrected code>"
    }
  ],
  "summary": "<one sentence>"
}
```
````

**Rules:**

- Flag any TypeScript `any` type as severity:error
- Flag SQL string interpolation as severity:error
- Flag missing test file (Foo.tsx without Foo.test.tsx) as severity:warning
- Do NOT comment on style, formatting, or naming unless it is a correctness issue
- Do NOT suggest adding features beyond the diff

````

Key principles from Anthropic's prompt engineering docs:
- **Give principles, not procedures** — tell the agent what good output looks like, not step-by-step how to get there
- **Use recency bias** — put reminders at the bottom of the prompt to exploit the model's tendency to weight recent tokens more heavily
- **Embed output contracts** — require structured JSON output so downstream agents can parse results without ambiguity
- **Scope description precisely** — the `description` frontmatter field is what Claude uses to decide when to delegate; a vague description causes misfiring

### 4. Missing agent roles that mature pipelines include

The current 7 agents cover execution (bug-fixer), research (researcher, research-executor), review (code-reviewer), testing (test-writer), UX (ux-auditor), and documentation (doc-updater). Four roles commonly added in mature pipelines:

**Planner agent** (high value for complex tasks)
- Role: Decomposes a multi-file task into a dependency-ordered task list before any code is written
- Model: Sonnet (planning requires reasoning but not Opus-level capability)
- Tools: Read-only (`Read`, `Glob`, `Grep`, `Bash` for reading)
- Trigger: On task start, before code-writer or bug-fixer is invoked
- Output: JSON task list with file targets, dependency order, and success criteria per step

**Security auditor agent** (critical for auth, SQL, API routes)
- Role: Scans diffs for OWASP Top 10 vulnerabilities, secret leakage, and injection vectors
- Model: Opus (security judgment requires highest accuracy)
- Tools: Read-only
- Trigger: After bug-fixer or any agent that modifies `src/auth/`, `src/api/`, or query-handling code
- Key checks: SQL parameterization, JWT handling, httpOnly cookies, input validation, secrets in code

**Dependency auditor agent**
- Role: Reviews any `package.json` change for license compatibility, known CVEs, and bundle size impact
- Model: Haiku (primarily lookup-based, pattern matching)
- Tools: `Read`, `Bash` (for `npm audit`)
- Trigger: On any `package.json` or `package-lock.json` change (use `PostToolUse` hook on Write targeting those files)

**Judge/evaluator agent** (most underused reliability mechanism per MAST research)
- Role: Independently evaluates output quality from other agents without seeing their prompts
- Critical design rule: **Its prompt must never be shown to the producing agents** — isolation prevents gaming
- Model: Sonnet
- Tools: Read-only
- Output: Pass/fail verdict with confidence score; exit code 2 from a `TaskCompleted` hook to block completion

### 5. Parallel agent coordination strategies and handoff patterns

**Parallel execution patterns for this pipeline:**
- Research phase: `researcher` + `research-executor` can run in parallel (no dependency)
- Review phase: `code-reviewer` + `ux-auditor` can run in parallel on the same diff (different lenses)
- After code change: `bug-fixer` → then `code-reviewer` + `test-writer` in parallel → then `doc-updater`

**Handoff via files (current approach) — strengths and gaps:**
Strengths: persistent, debuggable, works across tool boundaries, survives agent restarts.
Gaps: polling latency, no built-in conflict prevention for simultaneous writes.
Fix: use distinct output files per agent (`.claude/findings/<agent-name>-<timestamp>.json`) to avoid write collisions, and use `PostToolUse` hooks on `Write` to trigger downstream agents.

**With agent teams enabled:**
- Use the shared task list instead of polling files for "is task X done?"
- Use `TaskCompleted` hook to trigger the next agent rather than a timer/poller
- Each teammate can message the lead when it hits a blocker — no need for the file-based "status" files

**Dependency management in task lists:**
The agent-teams system manages task dependencies natively: a pending task with unresolved dependencies cannot be claimed until those dependencies complete. Map the pipeline dependency graph into task dependencies rather than encoding them in file-polling logic.

### 6. Cost optimization — model selection

Current May 2026 pricing per million tokens:

| Model | Input | Output | Best for |
|-------|-------|--------|----------|
| Haiku 4.5 | $1.00 | $5.00 | High-volume, latency-sensitive, classification, routing, extraction |
| Sonnet 4.6 | $3.00 | $15.00 | Default for most tasks, coding, analysis, RAG pipelines |
| Opus 4.7 | $5.00 | $25.00 | Multi-step reasoning, nuanced judgment, security audits, tasks where errors are costly |

**Recommended routing for this pipeline:**

| Agent | Recommended model | Rationale |
|-------|------------------|-----------|
| researcher | Sonnet | Synthesis requires reasoning, but not Opus |
| research-executor | Haiku | Mechanical search and fetch — no judgment required |
| code-reviewer | Sonnet | Pattern matching + judgment; Opus only if security-critical diff |
| bug-fixer | Sonnet | Fix complexity varies; use `effort: high` frontmatter not a model upgrade |
| test-writer | Sonnet | Requires understanding of edge cases |
| ux-auditor | Sonnet | Perceptual judgment; WCAG lookups are rote but analysis is not |
| doc-updater | Haiku | Templated writing against a diff — lowest reasoning requirement |
| planner (add) | Sonnet | Planning needs reasoning but not top-of-line |
| security-auditor (add) | Opus | False negatives are costly; this is exactly the Opus use case |
| judge/evaluator (add) | Sonnet | Evaluation requires consistency, not peak capability |
| dependency-auditor (add) | Haiku | Primarily `npm audit` + license lookup pattern matching |

**The advisor pattern for this pipeline:** Use Opus only as a "senior advisor" for the security-auditor and final synthesis in the researcher. Route everything else to Sonnet or Haiku. Teams report 10–15% cost reduction switching from all-Sonnet to routed Haiku/Sonnet, and 40–60% reduction vs. all-Opus.

**Additional cost levers:** Prompt caching saves up to 90% on repeated context (e.g., the full codebase context loaded per agent). Combine with batch API (50% off) for non-interactive runs.

### 7. Claude Code hooks — all available types and most impactful patterns

The SDK provides 19 hook event types. Hook names are case-sensitive.

**Full hook table (as of May 2026):**

| Hook | Python | TypeScript | Trigger |
|------|--------|-----------|---------|
| `PreToolUse` | Yes | Yes | Before tool call (can block or modify input) |
| `PostToolUse` | Yes | Yes | After tool result |
| `PostToolUseFailure` | Yes | Yes | After tool execution failure |
| `PostToolBatch` | No | Yes | Full batch of tool calls resolves |
| `UserPromptSubmit` | Yes | Yes | User prompt submission (can inject context) |
| `Stop` | Yes | Yes | Agent execution stop |
| `SubagentStart` | Yes | Yes | Subagent initialization |
| `SubagentStop` | Yes | Yes | Subagent completion |
| `PreCompact` | Yes | Yes | Before conversation compaction |
| `PermissionRequest` | Yes | Yes | Before permission dialog |
| `SessionStart` | No | Yes | Session initialization (TS only; use settings file for Python) |
| `SessionEnd` | No | Yes | Session termination (TS only) |
| `Notification` | Yes | Yes | Agent status messages (permission_prompt, idle_prompt, auth_success, etc.) |
| `Setup` | No | Yes | Session setup/maintenance |
| `TeammateIdle` | No | Yes | Teammate goes idle (exit code 2 = keep working) |
| `TaskCompleted` | No | Yes | Task marked complete (exit code 2 = block completion, send feedback) |
| `TaskCreated` | No | Yes | Task being created (exit code 2 = block creation) |
| `ConfigChange` | No | Yes | Config file changes |
| `WorktreeCreate` / `WorktreeRemove` | No | Yes | Git worktree lifecycle |

**Most impactful patterns for this pipeline:**

**Quality gate via `TaskCompleted`:**
Register a hook that runs the judge/evaluator agent before any task can be marked done. Exit with code 2 and a reason string to send feedback to the teammate and keep them working.

**Auto-trigger security-auditor via `PostToolUse` on Write:**
```typescript
PreToolUse: [{ matcher: "Write|Edit", hooks: [checkIfSecurityRelevant] }]
````

Inside the callback, check `tool_input.file_path` for paths matching `src/auth/`, `src/api/`, or query files — if matched, queue a security-auditor run.

**Aggregate subagent results via `SubagentStop`:**
Each `SubagentStop` fires with `agent_id` and `agent_transcript_path`. Use this to merge findings files from parallel agents rather than polling.

**Prevent dangerous operations via `PreToolUse`:**
Block writes to `.env`, `secrets.*`, and `credentials.*` files. Block `Bash` commands matching `rm -rf`, `git push --force`, `DROP TABLE`.

**Inject context via `UserPromptSubmit`:**
Inject the current diff, test results, and last lint output into every agent's first prompt to avoid agents working from stale state.

**Multiple hooks run in parallel; deny wins:**
When multiple `PreToolUse` hooks apply to the same call, they all execute in parallel. A single `deny` blocks regardless of what others return.

**Permission decision precedence:** deny > defer > ask > allow.

### 8. Common failure modes and recovery strategies

From the MAST taxonomy (March 2025, arXiv 2503.13657) and Anthropic's engineering blog:

**Failure mode 1 — Error compounding in sequential chains**
Sequential agents treat upstream output as ground truth. A subtly wrong intermediate result propagates as fact. Recovery: add an independent validation step between any two sequential agents that modifies state. Never let a downstream agent receive unvalidated output from an upstream agent.

**Failure mode 2 — Effort miscalibration**
Agents spawn excessive subagents (50+ observed in Anthropic's research system) for trivial queries, or apply full pipeline to single-file changes. Recovery: embed explicit scaling rules in the orchestrator prompt. Example: "If the change touches only one file and no tests fail, skip the planner and security-auditor; invoke only code-reviewer."

**Failure mode 3 — Task status lag (specific to agent teams)**
Teammates sometimes fail to mark tasks complete, blocking dependent tasks. Recovery: use the `TaskCompleted` hook to programmatically verify completion criteria are met before the task is marked done. Provide a manual override instruction in CLAUDE.md: "If a task appears stuck, verify the work is done, then tell the lead to mark it complete."

**Failure mode 4 — Context degradation across long tasks**
Agents lose track of original requirements as conversation grows. Recovery: use `PreCompact` hook to archive the full transcript before compaction. Use `UserPromptSubmit` hook to re-inject key constraints (output contract, file scope, success criteria) at the start of each agent invocation rather than relying on them surviving context compression.

**Failure mode 5 — Ambiguous task boundaries causing overlap**
Two agents edit the same file, leading to overwrites. Recovery: design task assignments so each agent owns a disjoint set of files. In the task list, record file ownership explicitly. Use `PreToolUse` hook to check a lock registry before allowing writes.

**Failure mode 6 — Silent success claims**
Agents declare tasks complete despite obvious failures (overexcitement failure mode from arXiv 2601.03315). Recovery: require agents to include a `tests_pass: true/false` and `lint_clean: true/false` field in their output JSON. The judge/evaluator agent verifies these claims by actually running the commands before the `TaskCompleted` hook allows completion.

**Recovery infrastructure:**

- Structured logging with correlation IDs on every agent invocation, tool call, and message
- Circuit breakers: hard `maxTurns` limits per agent per task (set in frontmatter)
- Persist state to files at meaningful checkpoints so pipelines can resume without restarting from zero
- Use `SubagentStop` hook to log transcripts for post-mortem analysis

### 9. In-context feedback and cross-invocation learning without retraining

**Persistent memory (built-in to subagent definitions):**
The `memory` frontmatter field enables cross-session learning:

- `memory: project` — agent maintains a memory directory at `.claude/agent-memory/<agent-name>/`
- `memory: user` — stored at `~/.claude/agent-memory/<agent-name>/`
- `memory: local` — session-local only

Agents with memory accumulate insights across conversations — codebase patterns, recurring issues, false positive patterns from previous reviews. This is the recommended mechanism for in-context feedback without retraining.

**The self-correction loop pattern (Anthropic prompt engineering docs):**
The most common cross-agent learning pattern is: generate draft → have a separate agent review it against explicit criteria → have the generator refine based on review feedback. This loop is more effective than a single-pass review because the generator can incorporate structured feedback.

Implementation for this pipeline:

1. `bug-fixer` produces a patch
2. `code-reviewer` evaluates it against the output contract
3. If verdict is `fail`, feed the `issues` array back to `bug-fixer` as a structured correction prompt
4. Repeat until verdict is `pass` or `maxTurns` is reached
5. `judge/evaluator` makes the final call independently

**File-based feedback accumulation:**
Since agents communicate via files, create a `.claude/findings/feedback-log.jsonl` where each agent appends its verdict and issues per task. The orchestrator (or the next invocation of the same agent) reads recent feedback entries to calibrate its approach. This is a lightweight form of retrieval-augmented self-improvement without any model training.

**`TeammateIdle` hook for active feedback:**
When a teammate finishes and goes idle, the `TeammateIdle` hook can run validation and exit with code 2 to send structured feedback back to the teammate with remaining issues, keeping them working rather than returning prematurely.

## Sources

- [Orchestrate teams of Claude Code sessions](https://code.claude.com/docs/en/agent-teams) — official Claude Code documentation, primary source for all agent-teams architecture details
- [Create custom subagents](https://code.claude.com/docs/en/sub-agents) — official Claude Code documentation, subagent frontmatter fields and model routing
- [Intercept and control agent behavior with hooks](https://code.claude.com/docs/en/agent-sdk/hooks) — official Claude Agent SDK documentation, complete hook table and callback API
- [How we built our multi-agent research system](https://www.anthropic.com/engineering/multi-agent-research-system) — Anthropic engineering blog, production multi-agent system with measured performance data
- [Building Effective AI Agents](https://anthropic.com/research/building-effective-agents) — Anthropic research, orchestrator/worker patterns, evaluator-optimizer, parallelization
- [Why Do Multi-Agent LLM Systems Fail?](https://arxiv.org/abs/2503.13657) — arXiv March 2025, MAST taxonomy, 14 failure modes across 3 categories
- [Claude Opus 4.7, Sonnet 4.6, and Haiku 4.5: Model Selection Guide](https://knightli.com/en/2026/05/08/anthropic-claude-model-lineup/) — current May 2026 pricing and capability breakdown
- [Best AI Model for Coding Agents 2026: A Routing Guide](https://www.augmentcode.com/guides/ai-model-routing-guide) — model routing strategy, 40–60% cost reduction data
- [Anthropic Advisor Strategy: Cut AI Agent Costs](https://www.mindstudio.ai/blog/anthropic-advisor-strategy-cost-optimization) — Opus-as-advisor pattern, 10–15% cost reduction data
- [Claude Code Hooks: Complete Guide](https://claudefa.st/blog/tools/hooks/hooks-guide) — comprehensive hook reference with all 19 event types

## Gaps

- The `TeammateIdle`, `TaskCompleted`, and `TaskCreated` hooks are TypeScript-only (Python SDK does not expose them). If this project's hook scripts are in Python, these three quality-gate hooks are unavailable via the SDK callback API and must be implemented as shell command hooks in `.claude/settings.json` instead.
- Agent teams are experimental with documented instability around session resumption. The 7-agent pipeline should implement the file-based handoff as a fallback when agent teams are unavailable or a teammate fails to appear.
- Persistent agent `memory` accumulates without pruning by default. Add a periodic cleanup step or the memory files will grow unbounded and degrade signal quality.
- The MAST taxonomy (arXiv 2503.13657) analyzed general multi-agent systems, not specifically Claude Code agent teams — some failure modes may be mitigated by native task-list coordination.
