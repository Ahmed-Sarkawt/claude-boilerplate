---
description: Research a technical question by searching the web and reading documentation. Use when you or the user don't know the answer, an API is unfamiliar, an error is unexplained, or you need to verify a best practice against current sources.
---

Invoke the `researcher` agent.

Pass it:
- The specific question or topic to research (from the user's message or the current blocker)
- Any relevant context: library name, version, error message, framework being used

The agent will search the web, fetch authoritative sources, and return a structured report with a direct answer, key findings, a code example if applicable, and source URLs.

After the agent returns:
1. Present the findings to the user
2. If the findings unblock an implementation task, proceed with that task using the research as your source
3. If confidence is Low or the question remains partially unanswered, say so explicitly before proceeding
