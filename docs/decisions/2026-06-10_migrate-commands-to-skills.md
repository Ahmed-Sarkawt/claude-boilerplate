# Migrate Slash Commands into Skills

**Date:** 2026-06-10
**Status:** Active

## Decision

Move all seven custom slash commands from `.claude/commands/<name>.md` to `.claude/skills/<name>/SKILL.md` and remove the `.claude/commands/` directory. Slash-command names are unchanged (`/review`, `/research`, `/audit-ux`, `/feedback`, `/init`, `/session-log`, `/workflow`).

Per-skill invocation policy:

- `research`, `review` — model-invocable (Claude may trigger them on its own judgment; the researcher docs already instruct "invoke automatically when you hit a knowledge gap")
- `audit-ux`, `feedback`, `init`, `session-log`, `workflow` — `disable-model-invocation: true` (user-triggered only, preserving their previous command behavior)

## Rationale

Claude Code merged commands and skills — both load through the same skill index, so the split between `.claude/commands/` and `.claude/skills/` taught two locations for one concept. As a boilerplate meant to model current best practice, having a single canonical location matters more than the migration cost. Skills also support bundled supporting files (scripts, reference docs) in their directory, which suits multi-step pipelines like `/review` and `/workflow` as they grow. Confirmed in research: `docs/research/2026-06-05_content-harness-engineering.md` ("custom commands have been merged into skills — one canonical location").

## Alternatives considered

- **Keep `.claude/commands/` as-is** — still fully supported by the harness, zero migration cost. Rejected because the boilerplate would keep teaching a split-brain layout that contradicts its own research docs.
- **Migrate only the pipeline commands (`review`, `workflow`)** — minimizes churn but leaves two locations, which is the actual problem.

## Consequences

- `git mv` preserved file history for all seven files.
- CLAUDE.md "Where things live", `REFERENCE.md`, and `.claude/OVERVIEW.md` updated to point at `.claude/skills/`.
- Anyone copying this boilerplate adds new slash commands as `.claude/skills/<name>/SKILL.md` with `disable-model-invocation: true` when the command should be user-triggered only.
- The pre-existing skills (`agent-team`, `laws-of-ux`, `react-ts-standards`) use a non-enforced `user-invocable: false` documentation convention; the migrated skills use the enforced `disable-model-invocation` setting. Aligning the old three is left for a future cleanup.
