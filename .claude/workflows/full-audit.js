export const meta = {
  name: "full-audit",
  description:
    "Run code review, UX audit, and OWASP security scan in parallel across changed files, then synthesize a ranked findings report. " +
    "Pass args.target to override the default (git diff). Use before a release or major PR.",
  phases: [
    {
      title: "Scope",
      detail: "Resolve file list from git diff or args.target",
    },
    {
      title: "Audit",
      detail: "code-reviewer + ux-auditor + security scan in parallel",
    },
    {
      title: "Synthesize",
      detail: "Merge and rank all findings into one report",
    },
  ],
};

// ── Phase 1: Scope ──────────────────────────────────────────────────────────
phase("Scope");

const target = args && args.target ? args.target : null;

const scopeResult = await agent(
  target
    ? `List all source files under ${target} recursively. ` +
        "Exclude node_modules, dist, .next, build. " +
        "Return two sections:\nALL_FILES:\n<one path per line>\n\nCOMPONENT_FILES:\n<.tsx and .jsx files only, one per line>"
    : "Run: git diff --name-only HEAD 2>/dev/null || git diff --name-only --cached\n" +
        "If that returns nothing, fall back to listing all files under src/.\n" +
        "Return two sections:\nALL_FILES:\n<one path per line>\n\nCOMPONENT_FILES:\n<.tsx and .jsx files only, one per line>",
  { label: "scope" },
);

const allSection =
  scopeResult.match(/ALL_FILES:\n([\s\S]*?)(?:\n\nCOMPONENT_FILES:|$)/)?.[1] ??
  "";
const compSection =
  scopeResult.match(/COMPONENT_FILES:\n([\s\S]*?)$/)?.[1] ?? "";
const allFiles = allSection
  .split("\n")
  .map((l) => l.trim())
  .filter(Boolean);
const componentFiles = compSection
  .split("\n")
  .map((l) => l.trim())
  .filter(Boolean);

log(
  `Scope: ${allFiles.length} source files, ${componentFiles.length} component files`,
);

if (allFiles.length === 0) {
  log("No files in scope — nothing to audit.");
  return {
    code_issues: "none",
    ux_issues: "none",
    dependency_issues: "none",
    priority_actions: ["No files in scope."],
  };
}

// ── Phase 2: Audit (three independent dimensions in parallel) ───────────────
phase("Audit");

// code review, UX, and dependency scan have zero inter-dependencies — run simultaneously
const [codeFindings, uxFindings, depFindings] = await parallel([
  () =>
    agent(
      `Code review: review these files for TypeScript quality, React correctness, ` +
        `OWASP Top 10, accessibility, and performance.\nFiles: ${allFiles.join(", ")}\n` +
        "Follow .claude/agents/code-reviewer.md. Return findings as a numbered list grouped by severity: BLOCK, RECOMMEND, NOTE.",
      { label: "audit:code", agentType: "code-reviewer" },
    ),
  () =>
    agent(
      componentFiles.length > 0
        ? `UX audit: audit these components against UX laws and WCAG AA.\n` +
            `Files: ${componentFiles.join(", ")}\n` +
            "Follow .claude/agents/ux-auditor.md. Return findings as a numbered list grouped by severity."
        : 'No component files (.tsx/.jsx) in scope. Return: "No component files to audit."',
      { label: "audit:ux", agentType: "ux-auditor" },
    ),
  () =>
    agent(
      "Dependency audit: read package.json, then run: npm audit --json 2>/dev/null | head -150\n" +
        "Identify critical/high CVEs and direct dependencies more than one major version behind latest.\n" +
        "Return findings as a numbered list grouped by severity.",
      { label: "audit:deps" },
    ),
]);

log("All three audit dimensions complete.");

// ── Phase 3: Synthesize ─────────────────────────────────────────────────────
phase("Synthesize");

const synthesis = await agent(
  `Synthesize these three independent audit reports into one ranked action list.\n\n` +
    `CODE REVIEW:\n${codeFindings}\n\n` +
    `UX AUDIT:\n${uxFindings}\n\n` +
    `DEPENDENCY AUDIT:\n${depFindings}\n\n` +
    "Format: group by severity (CRITICAL first), tag each item [CODE], [UX], or [DEP].\n" +
    "End with a one-paragraph overall health assessment.",
  { label: "synthesize" },
);

return {
  code_issues: codeFindings,
  ux_issues: uxFindings,
  dependency_issues: depFindings,
  priority_actions: synthesis,
};
