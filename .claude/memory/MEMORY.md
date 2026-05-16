# Memory Index

> **Cap:** First 200 lines / 25 KB load on every session start. Content beyond that is silently dropped.
> **Rule:** Keep every entry under 120 characters. Prune stale entries aggressively.
> **Topic files:** Create `.claude/memory/<topic>.md` for detail. Link it here with one line.
> **Never write implementation code here** — reference file paths instead.

<!-- ================================================================
  HOW TO MAINTAIN THIS FILE
  - Claude Code auto-writes here. You can also edit manually.
  - One line per fact. Link to a topic file when you need more space.
  - Delete entries when they become stale.
  - Keep "## Project" and "## Current work" within the first 30 lines
    so they always survive the 200-line cap.
  ================================================================ -->

## Project

<!-- Claude fills this in after /init or first session with project context -->

## Current work

<!-- What is actively being built or fixed right now -->

## Patterns learned

<!-- Project-specific conventions Claude has discovered, e.g.:
- [AUTH] All auth checks go through src/lib/auth.ts — never inline
- [API] Error responses always use { error: string, code: number }
-->

## Watch list

<!-- Recurring issues, footguns, or constraints to flag on every review, e.g.:
- [PERF] DB queries in render loops have appeared 3x — always check
- [SEC] User-controlled redirects: always validate against allowlist
-->

## Decisions (recent)

<!-- Mirror of the last 3 entries from docs/decisions/index.md — Claude refreshes this -->

## Research (recent)

<!-- Mirror of the last 3 entries from docs/research/index.md — Claude refreshes this -->
