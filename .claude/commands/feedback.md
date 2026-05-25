---
description: Record a correction for a specific agent. Use after any agent output you want to change — the agent will apply this rule from its next invocation onwards.
---

Record a correction so the named agent learns from this session's mistake.

## Usage

The user will call this as:
```
/feedback <agent-name> "<what the agent should do differently>"
```

If the agent name is missing, check the session log before asking:

```bash
SESSION_ID=$(cat .claude/.current-session-id 2>/dev/null)
jq -r 'select(.event == "agent_stop") | .data.agent' \
  ".claude/logs/sessions/${SESSION_ID}.jsonl" 2>/dev/null | tail -1
```

If that returns a name, use it and tell the user: "Assuming this is for `<agent-name>` — the last agent this session. Correct me if not."
If the log is empty or the command fails, ask: "Which agent needs the correction? Valid values: `code-reviewer`, `bug-fixer`, `test-writer`, `researcher`, `ux-auditor`, `doc-updater`"

If the correction text is missing, ask: "What should it do differently? Be specific — this becomes a permanent rule."

## Writing the correction

Open `.claude/memory/agent-corrections.md`.

Find the `## <agent-name>` section. If it does not exist, create it.

Append this line under the matching section:
```
- [YYYY-MM-DD] <correction text>
```

Use today's date. Keep the correction text exactly as the user provided — do not paraphrase.

## Confirm

Reply with exactly:
```
Saved. <agent-name> will apply this correction from its next invocation.

Entry written:
- [<date>] <correction text>

Run /feedback again to add more, or edit .claude/memory/agent-corrections.md directly to remove entries.
```

## What makes a good correction

Good — specific and actionable:
> "Don't flag missing aria-label on elements that already have aria-hidden='true'"
> "Don't reorder imports in src/polyfills/ — the load order is intentional"
> "Prefer zod over manual validation in route handlers"

Bad — vague, won't help the agent:
> "Be more careful"
> "That was wrong"

If the user gives a vague correction, ask: "Can you be more specific about what the agent should do differently next time?"
