---
name: weekly-research
description: Weekly research hygiene — scans docs/research/ for stale findings and surfaces new topics worth investigating. Copy to ~/.claude/scheduled-tasks/weekly-research/SKILL.md to activate.
---

You are running a scheduled weekly research review for this project. Work through each step and produce a brief report.

## Step 1 — Stale research

List all research files and their age:

```bash
ls -lt docs/research/*.md 2>/dev/null | grep -v index.md
```

Flag any research file older than 90 days — findings that old may reference outdated APIs, deprecated patterns, or superseded versions.

## Step 2 — Research index scan

```bash
cat docs/research/index.md 2>/dev/null
```

Look for:

- Topics marked with confidence "Low" or "Medium" — candidates for follow-up research
- Topics that were researched before a major library release (check file dates vs. known version timelines)
- Any topic in the index that has no corresponding detail file

## Step 3 — Decision freshness

```bash
cat docs/decisions/index.md 2>/dev/null
```

Flag any decision older than 6 months that referenced an external dependency or API — these may have been superseded by new versions.

## Step 4 — Suggest new research

Based on the above, suggest up to 3 specific research questions worth investigating this week. Each question should be:

- Answerable by the `researcher` agent (not open-ended)
- Directly relevant to a file or decision in the codebase
- Not already covered by a recent research file

Format each as: `researcher: "<specific question>" — why: <one sentence>`

## Report

```
## Weekly Research Review — <date>

**Stale findings (>90 days):** <list or "none">
**Low-confidence topics:** <list or "none">
**Stale decisions (>6 months):** <list or "none">

**Suggested research this week:**
1. researcher: "<question>" — why: <reason>
2. ...
```

Reschedule this task for next week at the same time.
