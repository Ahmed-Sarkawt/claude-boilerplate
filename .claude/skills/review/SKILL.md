---
name: review
description: Process the code review queue — invoke code-reviewer, apply auto-fixes with bug-fixer, then automatically write tests for the reviewed files. Crash-safe — interrupted reviews are detected on next session start.
---

Read `.claude/.review-queue.txt`.

If the file is empty or missing: check if `.claude/.review-queue-active.txt` exists.

- If active file exists: a previous review was interrupted. Ask the user: "A previous /review was interrupted. Resume it? (yes/no)". On yes, use the active file as the queue. On no, delete the active file and stop.
- If neither file exists or both are empty: say "Review queue is empty." and stop.

Otherwise:

**Step 1 — Move queue to active state**
Move (not copy, not clear) the queue file so a crash mid-review leaves a recoverable record:

```bash
mv .claude/.review-queue.txt .claude/.review-queue-active.txt
```

Read the file list from `.claude/.review-queue-active.txt`.

**Step 2 — Review each file**
For each file path:

- Invoke the `code-reviewer` subagent.
- The reviewer will write its findings to `.claude/findings/<path with / replaced by __>.json` automatically.
- Collect all findings where `auto_fixable` is `true` into a running list (from the reviewer's response).

**Step 3 — Report**
Show a summary: files reviewed, findings by severity (🔴/🟡/🟢), count of auto-fixable.
Also show which findings files were written so the user can inspect them directly.

**Step 4 — Apply fixes**
Ask: "Apply auto-fixes with bug-fixer? (yes/no)"

- On `yes`: invoke `bug-fixer` with the list of files. The bug-fixer reads each file's findings file as its primary source — you do not need to pass the full findings list in the prompt.
- On `no`: show the list of manual fixes needed and stop.

**Step 5 — Write tests (automatic after bug-fixer)**
After bug-fixer completes, invoke `test-writer` with the list of reviewed files.
The test-writer reads each findings file for context on what to cover.
This step is not optional — tests are part of the definition of done.

**Step 6 — Verify (judge)**
After test-writer completes, invoke `judge` with the list of reviewed files.
The judge independently runs lint, typecheck, and tests, and cross-checks that all claimed auto-fixes were actually applied.

- If the judge returns **PASS**: proceed to step 7.
- If the judge returns **FAIL**: show the judge's verdict to the user. Do not mark complete. The user must resolve the failures before the review is done.

**Step 7 — Mark complete**
Delete the active file to signal clean completion:

```bash
rm -f .claude/.review-queue-active.txt
```

Do NOT delete the findings files — they persist as history and are used by the next review of the same file to detect recurring issues.

---

**If the session crashes between Step 1 and Step 6:** the next session's `session-start.sh` will detect `.review-queue-active.txt`, warn about the interrupted review, and list the unprocessed files. Run `/review` again to resume.

**Note on isolation:** For the most unbiased review, run `/review` from a **fresh** Claude Code session that has not seen the implementation.
