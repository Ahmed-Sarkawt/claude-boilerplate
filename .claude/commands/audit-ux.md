---
description: Run a UX audit on a component, page, or flow. Checks against 10 Laws of UX and WCAG AA accessibility. Returns severity-tagged findings with specific fixes.
---

Invoke the `ux-auditor` agent.

If the user specified a file, component, or flow: pass that target to the agent.

If no target was specified: ask the user which component or flow to audit before invoking.

The agent will return findings tagged 🔴 CRITICAL / 🟡 RECOMMEND / 🟢 NOTE.

After the audit completes:
1. Show the full findings report
2. Ask: "Queue critical and recommend findings for /review? (yes/no)"
3. On yes: append the files with findings to `.claude/.review-queue.txt`
