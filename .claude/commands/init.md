---
description: Initialize or update project-specific Claude configuration — walks through customizing CLAUDE.md, rules, and agents for this specific project.
---

Guide the user through customizing this boilerplate for their project. Ask each question, wait for the answer, then make the change.

## Step 1 — Project identity
Ask: "What does this project do? (one sentence for CLAUDE.md)"
Update the `[FILL IN]` section in `CLAUDE.md` with the answer.

## Step 2 — Source layout
Ask: "Where does your frontend code live? (e.g. src/, app/, client/) And your backend? (e.g. server/, api/, backend/)"
Update the `paths` frontmatter in `.claude/rules/frontend.md` and `.claude/rules/backend.md` to match.
Update the source path patterns in `.claude/hooks/trigger-code-review.sh`.
Update the source path patterns in `.claude/hooks/format-and-test.sh`.

## Step 3 — Test runner
Ask: "What test runner do you use? (Vitest / Jest / other)"
Update `.claude/agents/test-writer.md` stack section and the test run command in `.claude/hooks/format-and-test.sh`.

## Step 4 — Docs location
Ask: "Are you keeping docs in the default location? (docs/decisions/, docs/research/, docs/flow/)"
If they use a different root, update the paths in `.claude/hooks/session-start.sh` and both `.claude/scripts/`.

## Step 5 — Hard rules
Ask: "Any project-specific hard rules to add to CLAUDE.md? (e.g. 'never use class components', 'all API calls go through src/lib/api.ts')"
Append each rule to the hard rules list in `CLAUDE.md`.

## Step 6 — Review
Show a summary of all changes made. Ask: "Does this look right?"

When confirmed, say: "Setup complete. Commit `.claude/` and `CLAUDE.md` to your repo so every Claude Code session in this project uses these rules."
