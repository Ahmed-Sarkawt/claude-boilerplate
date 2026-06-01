---
description: Run a named workflow — deterministic multi-agent orchestration with parallel fan-out. Usage: /workflow <name> [args]
---

Read the workflow name from `$ARGUMENTS` (the first word). Everything after the name is the args value.

If no argument is provided, list available workflows:

```
Available workflows (.claude/workflows/):

  parallel-review    Fan-out code-reviewer per queued file, then fix → test → judge
  full-audit         Parallel code + UX + dependency scan with synthesized report
  research-sweep     4-angle parallel research, synthesized and saved to docs/research/

Usage: /workflow <name> [args]

Examples:
  /workflow parallel-review
  /workflow full-audit
  /workflow research-sweep How does React 19 handle server-side caching?
```

Otherwise invoke the named workflow:

```js
Workflow({ name: "<name>", args: <args or undefined> })
```

Wait for the workflow to complete and display its return value.

If the name does not match any file in `.claude/workflows/`, say:

```
No workflow named "<name>" found in .claude/workflows/.
Run /workflow with no arguments to list available workflows.
```
