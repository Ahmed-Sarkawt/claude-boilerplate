# claude-boilerplate

A production-grade Claude Code configuration layer. Drop it into any project and get a structured agent team, automated quality gates, persistent memory across sessions, and enforced coding standards — without writing any of it yourself.

**Stack-agnostic.** Works with any language or framework. Optimized for TypeScript/Node projects out of the box, adaptable to anything via `setup.sh`.

---

## Requirements

> **⚠ Install these before running setup.sh or starting any Claude session:**

| Dependency          | Why                                                                                                       | Install                                        |
| ------------------- | --------------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| **jq**              | Required by all hooks for JSON parsing. Without it, safety guards and context injection silently disable. | `brew install jq` · `apt install jq`           |
| **python3**         | Required by setup.sh for safe file replacement.                                                           | `brew install python3` · `apt install python3` |
| **Claude Code CLI** | The tool this config runs inside.                                                                         | [claude.ai/code](https://claude.ai/code)       |

---

## Quick start (5 minutes)

**1. Copy into your project**

```bash
cp -r claude-boilerplate/.claude       your-project/
cp    claude-boilerplate/CLAUDE.md     your-project/
cp    claude-boilerplate/REFERENCE.md  your-project/
cp    claude-boilerplate/setup.sh      your-project/
cp    claude-boilerplate/.gitignore    your-project/
cp    claude-boilerplate/claude-code-research.md your-project/
cp -r claude-boilerplate/docs          your-project/
```

**2. Run setup**

```bash
cd your-project
bash setup.sh
```

Asks 4 questions (project name, source dirs, test runner, Agent Teams). Takes under 2 minutes.

**3. Verify hooks work**

```bash
bash .claude/tests/run-tests.sh
```

All tests should pass before your first session.

**4. Commit**

```bash
git add .claude/ CLAUDE.md REFERENCE.md docs/ .gitignore
git commit -m "chore: add Claude Code configuration"
```

**5. Open Claude Code**

```bash
claude
```

Run `/init` if you want to make further customizations interactively.

---

## What's inside

```
.claude/
├── agents/
│   ├── code-reviewer.md        # Reviews code for quality, security, a11y — sonnet
│   ├── bug-fixer.md            # Applies auto-fixable findings from code-reviewer — haiku
│   ├── researcher.md           # Plans research (sonnet) then delegates fetching to executor
│   ├── research-executor.md    # Executes web searches and page fetches — haiku (cheap)
│   ├── test-writer.md          # Writes failing tests after /review completes — sonnet
│   ├── ux-auditor.md           # Audits against 10 UX laws + WCAG AA — secondary
│   └── doc-updater.md          # Keeps docs/flow/ and docs/decisions/ in sync — secondary
├── hooks/
│   ├── session-start.sh        # Injects agent map, branch, decisions, research on session open
│   ├── session-end.sh          # Writes session summary to .claude/logs/
│   ├── session-logger.sh       # Core JSONL event logger (called by other hooks)
│   ├── prompt-logger.sh        # Logs every user prompt for session analysis
│   ├── guard-dangerous-bash.sh # Blocks rm -rf, DROP TABLE, curl|sh, push to main
│   ├── format-and-test.sh      # Prettier + sibling test on every file save
│   ├── trigger-code-review.sh  # Queues changed source files for /review
│   ├── prompt-reference-update.sh  # Prompts Claude to update REFERENCE.md on new file
│   ├── suggest-doc-update.sh   # Suggests doc-updater when routes/API/schema change
│   ├── pre-compact.sh          # Preserves critical context during auto-compaction
│   └── subagent-stop.sh        # Suggests next step after each agent completes
├── commands/
│   ├── review.md               # /review — full pipeline: code-reviewer → bug-fixer → test-writer
│   ├── research.md             # /research — manual research trigger
│   ├── audit-ux.md             # /audit-ux — UX + accessibility audit
│   ├── session-log.md          # /session-log — analyze session cost, tokens, patterns
│   └── init.md                 # /init — interactive customization wizard
├── rules/
│   ├── frontend.md             # Auto-loaded for *.tsx/*.jsx — a11y, hooks, semantics
│   ├── backend.md              # Auto-loaded for server/*.ts — SQL safety, validation
│   └── testing.md              # Auto-loaded for *.test.* — selectors, naming, scope
├── skills/
│   ├── laws-of-ux/             # 10 UX laws with application guidance
│   ├── react-ts-standards/     # TypeScript strict, component patterns, testing
│   └── agent-team/             # Full agent graph, chains, cost guidance
├── scripts/
│   ├── new-research.sh         # Creates a research file with correct naming + updates index
│   └── new-decision.sh         # Creates a decision file with correct naming + updates index
├── tests/
│   └── run-tests.sh            # Hook test suite — run before first session
├── memory/
│   └── MEMORY.md               # Auto-memory index (managed by Claude Code)
├── OVERVIEW.md                 # Full agent map + file map — read when disoriented
└── settings.json               # All hook wiring
CLAUDE.md                       # Master instructions + coding guidelines (read every session)
REFERENCE.md                    # File index — fill in as you build
docs/
├── decisions/
│   └── index.md                # Compact table of all decisions
├── research/
│   └── index.md                # Compact table of all research sessions
└── flow/
    ├── index.md                # Flow overview table
    └── main.md                 # Your primary user flow — fill in after setup
setup.sh                        # Interactive setup script (run once)
.gitignore                      # Excludes session logs, queue state, .env files
claude-code-research.md         # 1400-line reference: hooks, agents, patterns, UX laws
```

---

## How it works

### The review pipeline (`/review`)

The main quality loop. Run it after writing code:

```
/review
  → code-reviewer    scans for bugs, a11y issues, security, TS errors
  → bug-fixer        applies all Auto-fixable findings automatically
  → test-writer      writes failing tests for every reviewed file
```

Files are queued automatically by `trigger-code-review.sh` every time you save. **Crash-safe:** if Claude closes mid-review, the next session detects the interrupted state and warns you immediately so nothing slips through.

### Research (`/research` or automatic)

When Claude hits a knowledge gap, the researcher fires automatically. It:

1. **Plans** what to search (sonnet — judgment)
2. Delegates actual fetching to `research-executor` **(haiku — cheap)**
3. **Synthesizes** findings and saves them to `docs/research/` using consistent naming

Findings persist across sessions via the index file.

### Context injection (every session start)

```
Agent map + branch + last 8 decisions + last 8 research entries
+ FILL IN warning if CLAUDE.md uncustomized
+ interrupted review warning if /review was crashed
```

Claude always has the right context without you repeating yourself.

### Safety guards

`guard-dangerous-bash.sh` blocks **before** execution (hard block — exit 2):

- `rm -r`, `rm -rf`, `rm -Rf`, `rm --recursive`
- `DROP TABLE` / `drop table` (case-insensitive)
- `DROP DATABASE`, `TRUNCATE TABLE`
- `curl … | sh`, `wget … | sh`, `npx … | sh`
- Push to `main` or `master` without `ALLOW_PUSH_MAIN=1`
- Fork bombs, `mkfs`, `dd if=…of=/dev/`

### Docs structure

Three folders replace flat files. Each has a compact index Claude reads on startup, and individual detail files it reads on demand:

| Folder            | What goes in it                      | Who writes                                 |
| ----------------- | ------------------------------------ | ------------------------------------------ |
| `docs/decisions/` | One `.md` per architectural decision | You or `doc-updater` via `new-decision.sh` |
| `docs/research/`  | One `.md` per research session       | `researcher` agent via `new-research.sh`   |
| `docs/flow/`      | One `.md` per user flow              | You or `doc-updater`                       |

### Session logging

Every session produces `.claude/logs/sessions/<id>.jsonl` with events: prompts, file saves, agent completions, blocked commands. At session end, a summary appends to `.claude/logs/session-summary.md`. Run `/session-log` to analyze patterns.

---

## Agents

| Agent               | When invoked                    | Model  | Cost   |
| ------------------- | ------------------------------- | ------ | ------ |
| `code-reviewer`     | `/review` — after writing code  | sonnet | medium |
| `bug-fixer`         | Auto — part of `/review`        | haiku  | low    |
| `researcher`        | Auto when stuck, or `/research` | sonnet | medium |
| `research-executor` | Auto — invoked by researcher    | haiku  | low    |
| `test-writer`       | Auto — end of `/review`         | sonnet | medium |
| `ux-auditor`        | `/audit-ux` — secondary         | sonnet | medium |
| `doc-updater`       | Manual — secondary              | haiku  | low    |

**Secondary agents** (ux-auditor, doc-updater) are not in the default pipeline. Invoke them when you specifically need them.

---

## Hooks at a glance

| Event                    | Hook                         | Effect                                       |
| ------------------------ | ---------------------------- | -------------------------------------------- |
| Session opens            | `session-start.sh`           | Context injection + interrupted review check |
| User submits any prompt  | `prompt-logger.sh`           | Logs prompt to session JSONL                 |
| Any Bash command         | `guard-dangerous-bash.sh`    | Hard-blocks dangerous patterns               |
| File saved               | `format-and-test.sh`         | Prettier + sibling test run                  |
| File saved               | `trigger-code-review.sh`     | Queues file for `/review`                    |
| New file created         | `prompt-reference-update.sh` | Prompts Claude to update REFERENCE.md        |
| Route/API/schema changed | `suggest-doc-update.sh`      | Suggests invoking doc-updater                |
| Context fills up         | `pre-compact.sh`             | Preserves modified files + failing tests     |
| Agent finishes           | `subagent-stop.sh`           | Next-step suggestion per agent type          |
| Session closes           | `session-end.sh`             | Writes session summary                       |

---

## Customization

### Add a project-specific rule

```text
<!-- .claude/rules/payments.md -->
---
paths: ["src/payments/**/*.ts"]
---

# Payment module rules
- Never log card numbers or CVVs
- All Stripe calls go through src/lib/stripe.ts
```

### Add a new agent

```text
<!-- .claude/agents/my-agent.md -->
---
name: my-agent
description: One sentence on when to invoke this agent.
tools: Read, Grep, Glob
model: haiku
maxTurns: 8
---

Your instructions here.
```

### Record a decision manually

```bash
FILE=$(bash .claude/scripts/new-decision.sh "auth-strategy" "Authentication Strategy")
# Write content into $FILE
```

### Enable multi-worktree Agent Teams

```bash
# setup.sh handles this, or manually:
echo "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1" >> .env.claude
source .env.claude && claude
```

---

## Troubleshooting

| Problem                                      | Fix                                                                                |
| -------------------------------------------- | ---------------------------------------------------------------------------------- |
| `/review` says queue is empty                | Check your source files match patterns in `trigger-code-review.sh`                 |
| Session start warns about interrupted review | Run `/review` to resume, or `rm .claude/.review-queue-active.txt`                  |
| Tests failing in `run-tests.sh`              | Run from project root; run `bash .claude/hooks/session-start.sh > /dev/null` first |

---

## Token and cost tracking

Session logs capture prompt character counts and agent invocations. Accurate token counts and USD cost require Claude Code to expose session metadata in the Stop hook — availability depends on your Claude Code version. Run `/session-log` to see what's available.

---

## What this doesn't include (by design)

- **GitHub Actions CI** — add `anthropics/claude-code-action@v1` when ready. See `claude-code-research.md` §15.
- **Design system skill** — create `.claude/skills/design-system/SKILL.md` with your tokens and patterns.
- **MCP servers** — project-specific. Add to `.claude/settings.json` under `mcpServers`.
