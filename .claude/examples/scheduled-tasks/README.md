# Scheduled Task Templates

These are copy-paste starting points for Claude Desktop Scheduled Tasks.

## How Desktop Scheduled Tasks work

Desktop Scheduled Tasks are **not** project files — they live in your home directory and are managed by the Claude Desktop app. Templates in this folder are inert until you copy them to the correct location.

**To use a template:**

```bash
# 1. Pick a template (e.g. daily-review)
# 2. Copy it to ~/.claude/scheduled-tasks/<your-task-name>/SKILL.md
#    The task name is how it appears in Claude Desktop.

cp .claude/examples/scheduled-tasks/daily-review/SKILL.md \
   ~/.claude/scheduled-tasks/daily-review/SKILL.md

# 3. Open Claude Desktop → Scheduled Tasks → configure the schedule
# 4. The Desktop app must be running for the task to fire
```

> **Common mistake:** adding these files to the repo and expecting them to run.
> They will not. They must live under `~/.claude/scheduled-tasks/`.

## Templates included

| Template           | Purpose                                                               | Suggested schedule |
| ------------------ | --------------------------------------------------------------------- | ------------------ |
| `daily-review/`    | Checks review queue, runs tests, summarises overnight file changes    | Daily — morning    |
| `weekly-research/` | Scans docs/research/ for stale findings, suggests new research topics | Weekly             |

## Customising a template

Each SKILL.md contains a `description` frontmatter field (shown in the Desktop UI) and the task prompt body. Edit both before copying. The task prompt runs in the context of your project's working directory.

## Managing tasks from the CLI

```bash
# List scheduled tasks
claude mcp run scheduled-tasks list

# The task prompt is stored at:
# ~/.claude/scheduled-tasks/<name>/SKILL.md
# Edit it directly to update the task behaviour.
```
