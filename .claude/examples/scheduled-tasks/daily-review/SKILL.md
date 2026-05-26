---
name: daily-review
description: Morning maintenance — checks the review queue, runs tests, and summarises recent file activity. Copy to ~/.claude/scheduled-tasks/daily-review/SKILL.md to activate.
---

You are running a scheduled daily review for this project. Work through each step and produce a concise report.

## Step 1 — Review queue

```bash
cat .claude/.review-queue.txt 2>/dev/null | wc -l
cat .claude/.review-queue.txt 2>/dev/null
```

If files are queued: list them and note how long they have been waiting (check `.claude/.review-queue-meta.jsonl` for timestamps).
If empty: note the queue is clear.

## Step 2 — Test suite

```bash
bash .claude/tests/run-tests.sh 2>&1 | tail -6
```

Report pass/fail counts. List any failing tests by name. Do not attempt to fix failures.

## Step 3 — Recent file activity

```bash
git log --oneline --since="24 hours ago" --name-only 2>/dev/null | head -40
```

Summarise: how many commits, which directories were most active, any files modified but not yet queued for review.

## Step 4 — Memory cap check

```bash
wc -l .claude/memory/MEMORY.md 2>/dev/null || echo "0 lines"
```

Flag if over 160 lines (approaching the 200-line session-load cap).

## Report

Produce a brief markdown report:

```
## Daily Review — <date>

**Queue:** N files pending | clear
**Tests:** N passed, N failed — <failing names if any>
**Commits (24h):** N — <most active directory>
**Memory:** N/200 lines — <healthy | approaching cap>

**Action needed:** <one sentence, or "None">
```

Reschedule this task for tomorrow at the same time.
