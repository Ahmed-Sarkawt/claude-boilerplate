# Workflows

Workflows are deterministic JavaScript scripts that orchestrate multiple agents with explicit parallelism. They differ from slash commands in three ways:

1. **Parallel fan-out.** `parallel()` runs multiple agent calls simultaneously. A slash command runs one agent at a time.
2. **Intermediate results outside Claude's context window.** Workflow scripts hold findings in JS variables between phases — Claude never holds all of them in context simultaneously.
3. **Deterministic control flow.** Branching, looping, and grouping logic lives in JS — not in a natural-language prompt that may be interpreted differently each run.

Every `.js` file in this directory auto-registers by name.

---

## Invocation

```js
// From Claude or another workflow:
Workflow({ name: "parallel-review" });
Workflow({ name: "full-audit", args: { target: "src/components" } });
Workflow({
  name: "research-sweep",
  args: "How does React Server Components handle caching?",
});
```

```
// As a slash command:
/workflow parallel-review
/workflow full-audit
/workflow research-sweep How does React Server Components handle caching?
```

---

## Runtime primitive quick-ref

| Primitive                    | Signature                                                      | What it does                                                                                                                             |
| ---------------------------- | -------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- |
| `agent(prompt, opts?)`       | `(string, { label?, agentType?, schema? }) → string \| object` | Spawn an agent. Returns string by default; returns typed object if `schema` provided. Never pass `model` — it inherits from the session. |
| `parallel(thunks)`           | `(Array<() => Promise>) → Promise<Array>`                      | Fan out tasks simultaneously. Returns results in input order. Failed tasks resolve to `null` — always `.filter(Boolean)`.                |
| `pipeline(items, ...stages)` | `(Array, ...fns) → Promise<Array>`                             | Stream items through stages independently (no barrier between stages). Default choice for multi-stage work.                              |
| `phase(title, fn?)`          | `(string, async fn?) → result`                                 | Named execution phase — logged with a progress indicator. Pass an async fn; its return value is the phase result.                        |
| `log(message)`               | `(string) → void`                                              | Emit a progress line visible in the workflow run output.                                                                                 |
| `args`                       | any                                                            | Value passed at invocation. Shape varies per workflow — see each script's `meta.description`.                                            |
| `budget`                     | `{ total, spent(), remaining() }`                              | Token budget from a `+Nk` directive. `total` is null if no target set. Use to guard loops.                                               |

### Constraints

- **No non-determinism.** `Date.now()`, `Math.random()`, and argless `new Date()` throw at runtime. Pass timestamps in via `args`.
- **No imports.** Scripts are sandboxed — `require()` and `import` are not available beyond the meta export.
- **Plain JavaScript only.** No TypeScript type annotations — they fail to parse.
- **`schema` unlocks structured output.** Pass a JSON Schema to `agent()` to get a typed JS object back instead of a string.

---

## Shipped workflows

| Workflow          | Trigger                               | Phases                                  | When to use                                                                    |
| ----------------- | ------------------------------------- | --------------------------------------- | ------------------------------------------------------------------------------ |
| `parallel-review` | `/workflow parallel-review`           | Load queue → Review → Fix → Test → Gate | Queue depth > 3 files — fans out one `code-reviewer` per file simultaneously   |
| `full-audit`      | `/workflow full-audit`                | Scope → Audit → Synthesize              | Before a release — runs code review, UX audit, and dependency scan in parallel |
| `research-sweep`  | `/workflow research-sweep <question>` | Search → Synthesize                     | Deep multi-angle research — 4 parallel strategies, saved to `docs/research/`   |

---

## Copy-paste template

```js
export const meta = {
  name: "my-workflow",
  description: "One sentence: what this does and when to use it.",
  phases: [
    { title: "Discover", detail: "find items to process" },
    { title: "Process", detail: "fan out per item" },
  ],
};

phase("Discover");
const items = await agent(
  "Find all items to process. Return a newline-separated list.",
  { label: "discover" },
);
const itemList = items
  .split("\n")
  .map((l) => l.trim())
  .filter(Boolean);

if (itemList.length === 0) {
  log("Nothing to do.");
  return { status: "empty" };
}

log(`Processing ${itemList.length} items in parallel...`);

phase("Process");
const results = await parallel(
  itemList.map(
    (item) => () =>
      agent(`Process this item: ${item}`, { label: `process:${item}` }),
  ),
);

return { processed: results.filter(Boolean).length };
```

---

## When to add a workflow vs. extend a slash command

**Add a workflow** when any of these are true:

- You need two or more agents running **in parallel** (independent concerns, no data dependency between them).
- There is a **barrier** — a discovery phase whose output determines what the next phase fans out over.
- Intermediate results are large enough to **crowd Claude's context window** between phases.
- The orchestration logic needs **deterministic branching** that a natural-language prompt would handle inconsistently.

**Extend a slash command** when:

- A single sequential agent chain is enough.
- There is only one agent involved.
- The prompt fits cleanly in one slash command file.
