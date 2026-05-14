#!/usr/bin/env bash
# SubagentStop — logs agent completion and suggests the logical next step.
set -uo pipefail

INPUT=$(cat)
SUBAGENT_NAME=$(echo "$INPUT" | jq -r '.subagent_type // ""' 2>/dev/null || echo "")

# ── Log the agent stop ────────────────────────────────────────────────────────
if [[ -n "$SUBAGENT_NAME" && -f ".claude/.current-session-id" ]] && command -v jq >/dev/null 2>&1; then
  DATA=$(jq -n --arg agent "$SUBAGENT_NAME" '{agent: $agent}' 2>/dev/null) || DATA="{}"
  bash .claude/hooks/session-logger.sh "agent_stop" "$DATA" 2>/dev/null || true
fi

# ── Per-agent follow-up suggestions ──────────────────────────────────────────
case "$SUBAGENT_NAME" in
  code-reviewer)
    echo "🔧 Code review complete. If there are Auto-fixable findings above, invoke bug-fixer to apply them."
    ;;
  bug-fixer)
    echo "✅ Bug-fixer done. Run: npm run lint && npm run typecheck"
    # Prompt decision recording if there were skipped fixes or significant changes
    if [[ -f "docs/decisions" ]] || [[ -d "docs/decisions" ]]; then
      echo "📝 If any architectural decisions were made during this review, record them: bash .claude/scripts/new-decision.sh <slug> \"<title>\""
    fi
    ;;
  test-writer)
    echo "🧪 Test-writer done. Run npm test — expect failures until implementation catches up."
    ;;
  ux-auditor)
    echo "🎨 UX audit complete. Run /audit-ux on another component, or /review to queue fixes."
    ;;
  doc-updater)
    echo "📄 Doc-updater done. Review changes in docs/ — verify code is the source of truth, not the doc."
    ;;
  researcher)
    # Verify docs/research/index.md was updated this session
    if [[ ! -d "docs/research" ]]; then
      echo "⚠️  docs/research/ not found — researcher may not have saved findings." >&2
    else
      NOW=$(date +%s 2>/dev/null || echo "0")
      LAST_MOD=$(stat -f %m "docs/research/index.md" 2>/dev/null \
        || stat -c %Y "docs/research/index.md" 2>/dev/null \
        || echo "0")
      AGE=$(( NOW - LAST_MOD ))
      if [[ "$NOW" -gt 0 && "$AGE" -gt 300 ]]; then
        echo "⚠️  docs/research/index.md wasn't updated in the last 5 minutes — findings may not have been saved." >&2
      else
        LATEST=$(ls -t docs/research/*.md 2>/dev/null | grep -v "index.md" | head -1 || echo "docs/research/")
        echo "🔍 Research complete. Saved to ${LATEST}. Verify sources before using in code."
      fi
    fi
    ;;
esac

exit 0
