# Claude Code Content and Harness Engineering Patterns

**Date:** 2026-06-05
**Requested by:** researcher agent
**Confidence:** Medium

## Question

What are the most actionable techniques for (1) content engineering — how you engineer what Claude reads (CLAUDE.md, skills, rules, memory, context window strategy) — and (2) harness engineering — how you design the execution environment around Claude (hooks, agent isolation, quality gates, CI/CD integration) — in the context of a Claude Code developer boilerplate?

## Answer

Content engineering centers on treating the context window as a finite resource with a ~150-instruction budget shared with Claude's own system prompt (~50 slots). The primary levers are: lazy-loading via path-scoped rules and skills, HTML comment stripping for maintainer notes, and treating CLAUDE.md as a dense policy document (not a tutorial). Harness engineering is about using hooks as deterministic enforcement rather than relying on LLM judgment — PreToolUse for prevention, PostToolUse for verification, and quality gates that mirror local and CI environments identically.

## Key findings

### Content Engineering

**1. Treat CLAUDE.md as a 150-slot instruction budget**

- Claude's own system prompt consumes ~50 of the ~200 reliably-followable instruction slots
- Effective budget: 100-150 slots for project CLAUDE.md
- A 400-line file with 30 useful rules buried in filler performs dramatically worse than a 60-line file where every line is load-bearing
- Audit rule: if CI/lint already enforces it, remove it from CLAUDE.md

**2. Use the lazy-load hierarchy to keep baseline context minimal**

- Path-scoped rules (`.claude/rules/` with `paths:` frontmatter): zero tokens until matching file is read
- Skills (`.claude/skills/`): body loads only on invocation; use `disable-model-invocation: true` to hide from skill index entirely at startup
- Subdirectory CLAUDE.md: loads on-demand when Claude reads a file in that dir
- Only put in project-root CLAUDE.md what must be true on every turn

**3. Context placement follows a U-shaped performance curve**

- Accuracy highest at start and end of context; >30% drop for content buried in the middle
- Put hard constraints (never-do-X rules) at the top; put task-specific reminders at the bottom
- Exploit recency bias: put the most critical reminder last in agent prompts

**4. Skills as the DRY mechanism across agents**

- Shared procedures (e.g., "how to run tests", "output contract format") belong in skills, not duplicated in every agent `.md` file
- Skills are the correct abstraction for "long reference material that multiple agents need" -- they cost zero tokens until invoked
- Custom commands (`.claude/commands/`) have been merged into skills -- one canonical location

**5. Prompt compression: signal-to-noise discipline**

- HTML comments `<!-- -->` in CLAUDE.md are stripped before injection -- zero token cost, use for maintainer notes
- Remove rules already captured in auto memory (MEMORY.md) -- duplication wastes slots
- Anthropic's own guidance: calibrate instruction "altitude" -- give principles and output contracts, not brittle if-else procedures
- Sub-agent summaries should target 1,000-2,000 tokens returned to parent (community rule of thumb, not an official figure); never return full file contents

**Anti-patterns:**

- ALL-CAPS / "YOU MUST" / "NEVER EVER" language overtriggers Claude and degrades output quality -- just state the rule
- `@file` imports in CLAUDE.md expand at launch and count against startup tokens even if never needed -- prefer lazy-load patterns

---

### Harness Engineering

**1. Three-tier hook architecture: command -> prompt -> agent**

- Command hooks: deterministic shell scripts for pattern matching, linting, formatting -- fast, use for all repeatable checks
- Prompt hooks: single LLM call for semantic decisions (e.g., "does this edit touch auth?") -- non-deterministic but context-aware
- Agent hooks: spawn a subagent for complex multi-step verification -- reserve for critical security decisions only; set a hard timeout (these run for seconds-to-minutes, unlike command hooks -- budget accordingly)

**2. PreToolUse for prevention, PostToolUse for correction (not the reverse)**

- PostToolUse cannot undo a tool that has already run -- use it for formatting/linting fixes, not for blocking destructive ops
- Critical gate pattern: PreToolUse -> check blocklist -> exit 2 to block; provide clear override path
- Externalize blocklists to JSON files so the team updates them without touching hook definitions

**3. Quality gate design: progressive strictness**

- Layer 0 (PostToolUse, zero risk): auto-format and lint on every Write/Edit
- Layer 1 (PreToolUse, command): file blocklist -- deny writes to `.env`, `secrets.*`, migration files
- Layer 2 (PreToolUse, prompt): semantic security check for auth/payment/query files
- Layer 3 (TaskCompleted, agent): independent judge verifies output contract before task closes
- Goal: hooks catch the majority of errors before CI/CD (the ">=80%" figure circulating in blog posts is anecdotal, not a benchmark)

**4. Identical hooks in local and CI prevent drift**

- Store hooks in `.claude/settings.json` (version-controlled); same config runs locally and in GitHub Actions
- GitHub Actions flow: PR opens -> Claude Code CI mode -> PostToolUse hooks (lint/typecheck) -> agent hooks (arch patterns) -> results post as PR comment -> merge blocked until gates pass
- If a hook passes locally but fails in CI, the hook is environment-dependent -- fix the environment assumption, not the threshold

**5. Agent isolation: scoped tools, disjoint file ownership, hard turn limits**

- Verification/judge agents: Read, Grep, Glob only -- never Write, Edit, Execute
- Each agent in a pipeline should own a disjoint file set; use PreToolUse to check a lock registry before allowing writes
- Set `maxTurns` in agent frontmatter -- prevent runaway agents from exhausting token budget
- `isolation: worktree` for agents that modify files -- edits land in a throw-away copy until verified

**Anti-patterns:**

- Overly broad matchers (e.g., `matcher: "*"` on PreToolUse) -- creates performance bottleneck on every tool call
- Stacking redundant hooks (three linters checking the same rule) -- consolidate into one command chain
- Synchronous agent hooks on frequent events (every Write) -- reserve agent invocations for critical checkpoints only
- Silent hook failures -- always return a message explaining why the action was blocked and what the override path is

## Sources

- [Effective Context Engineering for AI Agents -- Anthropic Engineering](https://www.anthropic.com/engineering/effective-context-engineering-for-ai-agents) -- official Anthropic engineering blog, primary source on context curation strategy
- [How Claude Code Builds a System Prompt -- dbreunig.com](https://www.dbreunig.com/2026/04/04/how-claude-code-builds-a-system-prompt.html) -- detailed reverse-engineering of Claude Code's prompt assembly, conditional sections
- [Extend Claude with Skills -- Claude Code Docs](https://code.claude.com/docs/en/skills) -- official skills documentation, lazy-load behavior, DRY patterns
- [Claude Code Hooks: 6 Production Patterns -- Pixelmojo](https://www.pixelmojo.io/blogs/claude-code-hooks-production-quality-ci-cd-patterns) -- production hook wiring patterns, anti-patterns, CI/CD integration
- [Claude Code Hooks as Automated Quality Gates -- Understanding Data](https://understandingdata.com/posts/claude-code-hooks-quality-gates/) -- quality gate design and measurement
- Prior research: 2026-05-17_claude-code-memory-context-mechanisms.md -- hook event reference, token cost table, lazy-load confirmation
- Prior research: 2026-05-25_claude-code-agent-team-improvements.md -- agent isolation patterns, failure modes, quality gate via TaskCompleted

## Gaps

- No authoritative source on whether HTML comment stripping applies to skills/rules files or only CLAUDE.md -- prior research confirms it for CLAUDE.md only
- The "150 instruction slot" figure is derived from community analysis, not official Anthropic documentation -- treat as a heuristic, not a hard spec
- CI/CD integration details (GitHub Actions config, specific env vars for headless Claude Code) not fully documented in official sources
- Whether prompt hooks (LLM-call hooks) participate in prompt caching is undocumented -- could affect cost of frequently-triggered semantic gates
- Most harness-engineering specifics (the three-tier hook taxonomy, layer numbering, quantitative targets) trace to two low-authority blog posts (Pixelmojo, Understanding Data) -- treat as practitioner patterns, not official guidance
