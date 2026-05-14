# REFERENCE.md

> Read this before using `find`, `grep`, or `ls` to explore the codebase.
> One-line description per file. Update when adding or removing files.
> Claude Code reads this to orient itself without burning context on filesystem traversal.

## Config

| File | What |
|------|------|
| `CLAUDE.md` | Master instructions — read on every session |
| `.claude/OVERVIEW.md` | Agent map, file map, when-stuck flow — injected each session |
| `REFERENCE.md` | This file — codebase index |
| `docs/decisions/index.md` | Compact decisions table — one row per decision, links to detail files |
| `docs/decisions/*.md` | One file per decision — full rationale, alternatives, consequences |
| `docs/research/index.md` | Compact research table — one row per session, links to detail files |
| `docs/research/*.md` | One file per research session — question, answer, sources, confidence |
| `docs/flow/index.md` | Flow overview table — lists all flows with status |
| `docs/flow/*.md` | One file per user flow — steps, success criteria, out-of-scope |
| `.claude/settings.json` | Hook wiring and Claude Code config |
| `.claude/.current-session-id` | Active session ID — written by session-start, read by all loggers |
| `.claude/.review-queue.txt` | Files queued for /review — cleared at start of each review run |
| `.claude/logs/sessions/<id>.jsonl` | Structured event log for one session (JSONL, one event per line) |
| `.claude/logs/session-summary.md` | Human-readable summary of every past session |
| `.claude/logs/last-test-run.txt` | Output of most recent sibling test run (read by pre-compact) |
| `.claude/logs/sessions.log` | One-line session end entries |

## Source

<!-- Add one row per file as you build. Claude reads this instead of running find/ls. -->

| File | What |
|------|------|
| `[your file]` | [one-line description] |

## Tests

| File | What |
|------|------|
| `[your test file]` | [one-line description] |
