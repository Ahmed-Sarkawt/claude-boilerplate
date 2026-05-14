---
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
- Collect all findings tagged `Auto-fixable: yes` into a running list.

**Step 3 — Report**
Show a summary: files reviewed, findings by severity (🔴/🟡/🟢), count of auto-fixable.

**Step 4 — Apply fixes**
Ask: "Apply auto-fixes with bug-fixer? (yes/no)"
- On `yes`: invoke `bug-fixer` with the full auto-fixable findings list.
- On `no`: show the list of manual fixes needed and stop.

**Step 5 — Write tests (automatic after bug-fixer)**
After bug-fixer completes, invoke `test-writer` with the list of reviewed files.
The test-writer writes failing tests for each reviewed file, then reports results.
This step is not optional — tests are part of the definition of done.

**Step 6 — Mark complete**
Delete the active file to signal clean completion:
```bash
rm -f .claude/.review-queue-active.txt
```

---

**If the session crashes between Step 1 and Step 6:** the next session's `session-start.sh` will detect `.review-queue-active.txt`, warn about the interrupted review, and list the unprocessed files. Run `/review` again to resume.

**Note on isolation:** For the most unbiased review, run `/review` from a **fresh** Claude Code session that has not seen the implementation.
