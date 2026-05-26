# /loop Maintenance Prompt

> This file customizes the task Claude runs on each /loop iteration.
> Max 25,000 bytes. Loaded automatically when bare `/loop` is invoked.
> Requires Claude Code v2.1.72+.

---

You are running a maintenance iteration for this project. Work through these checks in order. Stop and report after completing all four.

## 1. Review queue

Check whether any files are waiting for review:

```bash
cat .claude/.review-queue.txt 2>/dev/null || echo "(empty)"
```

If the queue has entries: list the files and their count. Do not run `/review` automatically — flag it for the user.
If empty: note it is clear.

## 2. Test suite

Run the hook test suite:

```bash
bash .claude/tests/run-tests.sh 2>&1 | tail -8
```

Report pass/fail counts. If any tests fail, list the failing test names. Do not attempt to fix failures automatically.

## 3. Memory cap

Check whether `.claude/memory/MEMORY.md` is approaching its session-load limit (200 lines / 25 KB):

```bash
wc -l .claude/memory/MEMORY.md 2>/dev/null || echo "0"
wc -c .claude/memory/MEMORY.md 2>/dev/null || echo "0"
```

- Under 160 lines and under 20 KB: ✅ healthy
- 160–180 lines or 20–24 KB: ⚠️ approaching cap — flag for pruning
- Over 180 lines or over 24 KB: 🔴 prune now — content beyond line 200 or 25 KB is silently dropped at session start

## 4. Session summary

```bash
tail -20 .claude/logs/session-summary.md 2>/dev/null || echo "(no sessions logged yet)"
```

Report: last session date, files modified, agents invoked, cost if available. Flag any agent invoked 3+ times (candidate for a new rule or automation).

---

## Report format

```
## /loop Maintenance — <timestamp>

### Review queue
<count> files pending | empty

### Tests
Passed: N | Failed: N
<failing test names if any>

### Memory
Lines: N/200 | Size: NKB/25KB — <healthy | approaching cap | PRUNE>

### Last session
<one line summary>
<any flags>
```
