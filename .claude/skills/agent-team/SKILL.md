---
name: agent-team
description: The full agent graph for this boilerplate — who does what, when to invoke them, and which agents can invoke which others. Load this when planning a multi-step task, deciding whether to chain agents, or explaining the system to a new contributor.
user-invocable: false
---

> **Note on `user-invocable: false`:** This is a documentation convention, not an enforced Claude Code setting. It signals that this skill is for internal reference rather than user-triggered slash commands.

# Agent Team Map

This boilerplate has 8 primary agents + 1 execution sub-agent. Claude is the orchestrator.

## The graph

```
Claude (orchestrator)
│
├─── researcher              Knowledge gaps, unknown APIs, obscure errors
│    └── research-executor   Executes search/fetch plan (haiku — cheap, mechanical)
│
├─── code-reviewer           Post-write quality gate (via /review)
│    └── researcher          Unfamiliar library or version-specific behavior
│
├─── bug-fixer               Auto-fix queue from code-reviewer (/review pipeline)
│    (no sub-agents)         Mechanical only — never invokes others
│
├─── test-writer             Writes tests after bug-fixer in /review pipeline
│    (no sub-agents)         Focused task — never invokes others
│
├─── judge                   Final gate of /review — invoked after test-writer
│    (no sub-agents)         Read-only: verifies fixes applied, lint/typecheck/tests pass
│
├─── ux-auditor              UX + a11y audit — secondary, via /audit-ux
│    └── researcher          Verify UX claims or current accessibility guidance
│
└─── doc-updater             Doc sync — secondary, via /doc or manually
     (no sub-agents)         Read-only on source, write-only on docs/
```

## When to invoke each agent

| Signal                                           | Agent to invoke                                 |
| ------------------------------------------------ | ----------------------------------------------- |
| You hit a knowledge gap or the user doesn't know | `researcher` (auto or `/research`)              |
| File was written or edited                       | `code-reviewer` (via `/review`)                 |
| code-reviewer found auto-fixable issues          | `bug-fixer` (part of `/review` pipeline)        |
| /review pipeline complete (bug-fixer done)       | `test-writer` (automatic — step 5 of `/review`) |
| After test-writer in /review                     | `judge` (automatic — final gate, step 6)        |
| UI feature built or modified                     | `ux-auditor` (`/audit-ux` — secondary)          |
| Route or API contract changed                    | `doc-updater` (manual)                          |

## Recommended chains by task type

### New feature

```
[implement] → /review (code-reviewer → bug-fixer → test-writer → judge)
```

### Bug fix

```
researcher (if cause unclear) → [fix] → /review (code-reviewer → bug-fixer → judge)
```

### UI work

```
[implement] → /review → /audit-ux (optional, secondary)
```

### Unknown library integration

```
researcher → [implement] → /review
```

## Cost guidance

| Task size        | Agents to run                                               |
| ---------------- | ----------------------------------------------------------- |
| One-liner fix    | code-reviewer only                                          |
| Small component  | `/review` (code-reviewer → bug-fixer → test-writer → judge) |
| New feature      | `/review` + researcher if needed                            |
| UI-heavy feature | `/review` + `/audit-ux`                                     |

## Shared state between agents

| File                                              | Written by                 | Read by                           |
| ------------------------------------------------- | -------------------------- | --------------------------------- |
| `docs/research/index.md` + `docs/research/*.md`   | researcher                 | session-start hook, all agents    |
| `docs/decisions/index.md` + `docs/decisions/*.md` | doc-updater, user          | session-start hook, all agents    |
| `docs/flow/index.md` + `docs/flow/*.md`           | doc-updater, user          | test-writer, doc-updater          |
| `.claude/.review-queue.txt`                       | trigger-code-review hook   | code-reviewer, /review command    |
| `.claude/.review-queue-meta.jsonl`                | trigger-code-review hook   | code-reviewer (rich edit context) |
| `.claude/.review-queue-active.txt`                | /review command            | /review, session-start hook       |
| `.claude/findings/<path>.md`                      | code-reviewer              | bug-fixer, test-writer, judge     |
| `.claude/findings/bug-fixer-summary.md`           | bug-fixer                  | judge                             |
| `REFERENCE.md`                                    | user (maintained manually) | researcher, all agents            |
| `.claude/logs/sessions.log`                       | session-end hook           | (audit only)                      |

## Rules for agent authors

1. An agent may only invoke agents explicitly listed as its sub-agents above.
2. Every agent that invokes `researcher` must pass: the specific question, the library/version, and why it needs research.
3. `researcher` saves findings to `docs/research/` using `.claude/scripts/new-research.sh` — not to a flat file.
4. `bug-fixer` never invokes other agents — it's mechanical.
5. The orchestrator (Claude) decides which chain to run. Agents don't self-direct beyond their defined sub-agents.
