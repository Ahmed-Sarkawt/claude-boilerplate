# CLAUDE.md

> Read on every session start.
> **Disoriented?** Read `.claude/OVERVIEW.md` — not imported here, read it explicitly when you need navigation help.
> Domain rules and UX standards live in `.claude/rules/` and `.claude/skills/` — loaded on demand, not here.
> Read `REFERENCE.md` before exploring with `find`/`grep` — it indexes every file in the project.

## What this project is

[FILL IN: one paragraph describing the product, the persona you are building for, and the primary success metric.]

## Hard rules (never violate)

1. **TypeScript strict mode.** No `any`. No `@ts-ignore` without an explanatory comment. ESLint clean. Prettier formatted.
2. **Tests everywhere.** Tests live next to code — `Foo.tsx` → `Foo.test.tsx`. No giant `__tests__` dirs.
3. **No unapproved dependencies.** Adding to `package.json` requires a decision file in `docs/decisions/` with justification.
4. **Cross-browser animations only.** `transform`, `opacity`, `transition`, `@keyframes`. No `@scroll-timeline` or experimental CSS. Always include `@media (prefers-reduced-motion: reduce)` fallbacks.
5. **All SQL parameterized.** No string interpolation into queries. Ever.
6. **No secrets in code or logs.**
7. **UI components: shadcn/ui + Lucide icons as the base.** Use these before reaching for anything custom.

## Coding guidelines

### 1. Think before coding

Don't assume. Don't hide confusion. Surface tradeoffs.

- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity first

Minimum code that solves the problem. Nothing speculative.

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: *"Would a senior engineer say this is overcomplicated?"* If yes, simplify.

### 3. Surgical changes

Touch only what you must. Clean up only your own mess.

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that **your** changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: every changed line should trace directly to the user's request.

### 4. Goal-driven execution

Define success criteria. Loop until verified.

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```
Strong success criteria enable independent looping. Weak criteria ("make it work") require constant clarification.

## Working conventions

- **Plan before code.** For anything touching more than one file, record the decision in `docs/decisions/` first. Date-stamped, with rationale.
- **Small commits, conventional messages.** `feat(scope): …`, `fix(scope): …`, `docs: …`. One concern per commit.
- **Multi-worktree by default.** Multiple Claude sessions can work in parallel using `git worktree`. Enable Agent Teams with `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.

## Definition of done

- [ ] `npm run lint && npm run typecheck && npm test` passes
- [ ] New behavior has a test
- [ ] User-facing change has a screenshot in `docs/screenshots/`
- [ ] Decision recorded in `docs/decisions/` with rationale

## Where things live

| Path | What |
|------|------|
| `.claude/OVERVIEW.md` | Agent map, file map, when-stuck flow — read when disoriented |
| `REFERENCE.md` | Codebase file index — read before exploring |
| `docs/decisions/` | One file per decision + `index.md` compact table |
| `docs/research/` | One file per research session + `index.md` compact table |
| `docs/flow/` | One file per user flow + `index.md` overview |
| `.claude/agents/` | Subagent definitions |
| `.claude/rules/` | Path-scoped rules (auto-loaded per file type) |
| `.claude/skills/` | On-demand knowledge (UX laws, React standards, agent team) |
| `.claude/hooks/` | Lifecycle automation |
| `.claude/commands/` | Custom slash commands |
