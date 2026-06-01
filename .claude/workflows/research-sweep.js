export const meta = {
  name: "research-sweep",
  description:
    "Multi-angle parallel research: fans out 4 independent agents (official docs, security, performance, recent changes), " +
    "synthesizes findings, and saves to docs/research/. Pass the research question as args (string).",
  phases: [
    { title: "Search", detail: "4 parallel research angles simultaneously" },
    {
      title: "Synthesize",
      detail: "Deduplicate, merge, save to docs/research/",
    },
  ],
};

// ── Validate input ──────────────────────────────────────────────────────────
if (!args || typeof args !== "string" || !args.trim()) {
  log("No research question provided.");
  log(
    'Usage: Workflow({ name: "research-sweep", args: "Your question here" })',
  );
  return { error: "No research question provided", saved_to: null };
}

const topic = args.trim();
log(`Research topic: "${topic}"`);

// ── Phase 1: Search (4 independent angles in parallel) ──────────────────────
phase("Search");

const [docsResult, secResult, perfResult, recentResult] = await parallel([
  () =>
    agent(
      `Research angle: OFFICIAL DOCS\nQuestion: ${topic}\n\n` +
        "Focus on authoritative documentation, official specs, MDN, framework docs, RFCs.\n" +
        "Find the canonical answer. List key findings as bullet points, then cite sources.",
      { label: "angle:official-docs" },
    ),
  () =>
    agent(
      `Research angle: SECURITY\nQuestion: ${topic}\n\n` +
        "Focus on known CVEs, OWASP guidance, security advisories, common attack vectors, secure usage patterns.\n" +
        "List key findings as bullet points, then cite sources.",
      { label: "angle:security" },
    ),
  () =>
    agent(
      `Research angle: PERFORMANCE\nQuestion: ${topic}\n\n` +
        "Focus on performance characteristics, benchmarks, best practices, common bottlenecks, optimization patterns.\n" +
        "List key findings as bullet points, then cite sources.",
      { label: "angle:performance" },
    ),
  () =>
    agent(
      `Research angle: RECENT CHANGES (last 12 months)\nQuestion: ${topic}\n\n` +
        "Focus on deprecations, breaking changes, new APIs, migration guides, changelog entries since 2025.\n" +
        "List key findings as bullet points, then cite sources.",
      { label: "angle:recent-changes" },
    ),
]);

log("All 4 angles complete. Synthesizing...");

// ── Phase 2: Synthesize and save ─────────────────────────────────────────────
phase("Synthesize");

const synthesis = await agent(
  `Synthesize 4 independent research reports on: "${topic}"\n\n` +
    `OFFICIAL DOCS:\n${docsResult}\n\n` +
    `SECURITY:\n${secResult}\n\n` +
    `PERFORMANCE:\n${perfResult}\n\n` +
    `RECENT CHANGES:\n${recentResult}\n\n` +
    "Instructions:\n" +
    "1. Deduplicate findings that appear across multiple angles\n" +
    "2. Elevate security-critical findings to the top\n" +
    "3. Note any conflicts between angles\n" +
    "4. Assign overall confidence: High (multiple authoritative sources agree), Medium (partial), Low (conflicting/thin)\n" +
    "5. List all unique sources\n\n" +
    "Then save using:\n" +
    '  bash .claude/scripts/new-research.sh "<kebab-slug-max-40-chars>" "<question>" "<High|Medium|Low>"\n' +
    "After the script runs, append the full synthesis as the file body.\n" +
    "Return: the file path created (e.g. docs/research/2026-06-01_topic.md) and the confidence level on the last line.",
  { label: "synthesize" },
);

const savedMatch = synthesis.match(/docs\/research\/[^\s"']+\.md/);
const confidenceMatch = synthesis.match(/\b(High|Medium|Low)\b/i);

return {
  topic,
  confidence: confidenceMatch?.[1] ?? "Medium",
  key_findings: synthesis,
  saved_to:
    savedMatch?.[0] ?? "docs/research/ (see output above for exact path)",
};
