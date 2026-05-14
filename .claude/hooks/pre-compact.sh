#!/usr/bin/env bash
# PreCompact — injects preservation instructions before auto-compaction.
# Fix: guards against fresh repos (no commits). Uses jq to build JSON safely.
set -uo pipefail

# ── Modified files (only if repo has commits) ─────────────────────────────────
MODIFIED=""
if git rev-parse --git-dir >/dev/null 2>&1; then
  if git log --oneline -1 >/dev/null 2>&1; then
    # Has at least one commit — safe to run diff
    MODIFIED=$(git diff --name-only HEAD 2>/dev/null \
      | head -n 20 | tr '\n' ', ' | sed 's/,$//' || echo "")
  fi
  # No commits → MODIFIED stays empty (fresh repo)
fi

# ── Failing tests from last test run ─────────────────────────────────────────
FAILING_TESTS=""
if [[ -f ".claude/logs/last-test-run.txt" ]]; then
  FAILING_TESTS=$(grep -E "FAIL|✗|×|FAILED" ".claude/logs/last-test-run.txt" 2>/dev/null \
    | head -n 5 | tr '\n' ' | ' | head -c 300 || echo "")
fi

PRESERVE="When compacting, always preserve: (1) files modified this session${MODIFIED:+: $MODIFIED}; (2) failing tests${FAILING_TESTS:+: $FAILING_TESTS}; (3) the current task being worked on; (4) any constraints or blockers the user mentioned."

# ── Output JSON safely via jq (prevents injection from filenames/content) ─────
if command -v jq >/dev/null 2>&1; then
  jq -n --arg ctx "$PRESERVE" '{"additionalContext": $ctx}'
else
  # Fallback — strip characters that would break JSON
  SAFE=$(echo "$PRESERVE" | tr -d '"\\' | head -c 800)
  printf '{"additionalContext": "%s"}\n' "$SAFE"
fi
