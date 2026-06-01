export const meta = {
  name: "parallel-review",
  description:
    "Fan-out code-reviewer agents across all queued files in parallel, then run bug-fixer → test-writer → judge sequentially. Use instead of /review when queue depth > 3 files.",
  phases: [
    { title: "Load queue", detail: "Read .review-queue.txt or use args" },
    { title: "Review", detail: "Parallel code-reviewer per file" },
    { title: "Fix", detail: "bug-fixer on merged auto-fixable findings" },
    { title: "Test", detail: "test-writer for all reviewed files" },
    { title: "Gate", detail: "judge cross-checks claimed fixes" },
  ],
};

// ── Phase 1: Load queue ─────────────────────────────────────────────────────
phase("Load queue");

// Accept an explicit file list via args, or drain .review-queue.txt
let files = Array.isArray(args) && args.length > 0 ? args : null;

if (!files) {
  const queueContent = await agent(
    "Read .claude/.review-queue.txt. Return its contents exactly — one file path per line. " +
      "If the file is empty or missing, return the single word EMPTY.",
    { label: "read-queue" },
  );
  if (queueContent.trim() === "EMPTY") {
    log("Review queue is empty — nothing to do.");
    return { status: "empty", files_reviewed: 0 };
  }
  files = queueContent
    .split("\n")
    .map((l) => l.trim())
    .filter(Boolean);
}

log(`Queue: ${files.length} file(s)`);
files.forEach((f) => log(`  ${f}`));

// Write active sentinel (distinct from .review-queue-active.txt used by /review)
await agent(
  'Write the text "active" to .claude/.review-workflow-active.txt, creating the file if needed.',
  { label: "sentinel-write" },
);

// ── Phase 2: Review (parallel fan-out) ──────────────────────────────────────
phase("Review");

// One code-reviewer agent per file — all run simultaneously
const reviewResults = await parallel(
  files.map(
    (filePath) => () =>
      agent(
        `You are acting as the code-reviewer agent. Review the file: ${filePath}\n` +
          "Follow all instructions in .claude/agents/code-reviewer.md exactly.\n" +
          `Write findings to .claude/findings/${filePath.replace(/\//g, "__")}.json\n` +
          "Return a one-sentence verdict for this file.",
        { label: `review:${filePath}`, agentType: "code-reviewer" },
      ),
  ),
);

log(
  `Review complete: ${reviewResults.filter(Boolean).length}/${files.length} files processed`,
);

// ── Phase 3: Fix ────────────────────────────────────────────────────────────
phase("Fix");

await agent(
  `You are the bug-fixer. Apply auto-fixable issues for these files: ${JSON.stringify(files)}\n` +
    "Read each file's findings JSON from .claude/findings/ for the authoritative fix queue.\n" +
    "Follow all instructions in .claude/agents/bug-fixer.md exactly.",
  { label: "bug-fixer", agentType: "bug-fixer" },
);

// ── Phase 4: Test ───────────────────────────────────────────────────────────
phase("Test");

await agent(
  `You are the test-writer. Write tests for these reviewed files: ${JSON.stringify(files)}\n` +
    "Read each file's findings JSON for context on what to cover.\n" +
    "Follow all instructions in .claude/agents/test-writer.md exactly.",
  { label: "test-writer", agentType: "test-writer" },
);

// ── Phase 5: Gate ───────────────────────────────────────────────────────────
phase("Gate");

const verdict = await agent(
  `You are the judge. Verify the review pipeline output for these files: ${JSON.stringify(files)}\n` +
    "Follow all instructions in .claude/agents/judge.md exactly.\n" +
    'Return your verdict: "## Judge Verdict: PASS" or "## Judge Verdict: FAIL"',
  { label: "judge", agentType: "judge" },
);

const passed = verdict.includes("PASS");

// Clear sentinel on clean completion
if (passed) {
  await agent(
    "Delete .claude/.review-workflow-active.txt and clear .claude/.review-queue.txt.",
    { label: "sentinel-clear" },
  );
}

return {
  files_reviewed: files.length,
  verdict: passed ? "PASS" : "FAIL",
  detail: verdict,
};
