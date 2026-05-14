#!/usr/bin/env bash
# SessionStart — generates session ID, injects context, starts session log.
set -uo pipefail

# ── Session ID ───────────────────────────────────────────────────────────────
SESSION_ID="$(date +%Y%m%d_%H%M%S)_$$"
mkdir -p .claude/logs/sessions
echo "$SESSION_ID" > .claude/.current-session-id

BRANCH=$(git branch --show-current 2>/dev/null || echo "no-git")

AGENT_MAP="AGENT MAP: review→/review(code-reviewer→bug-fixer→test-writer)|stuck/unknown→researcher(auto or /research)|ux→/audit-ux|docs→doc-updater. Full map: .claude/OVERVIEW.md"

# ── Interrupted review detector ───────────────────────────────────────────────
INTERRUPTED_REVIEW=""
if [[ -f ".claude/.review-queue-active.txt" ]] && [[ -s ".claude/.review-queue-active.txt" ]]; then
  ACTIVE_FILES=$(tr '\n' ',' < ".claude/.review-queue-active.txt" | sed 's/,$//')
  INTERRUPTED_REVIEW=" | ⚠ INTERRUPTED REVIEW: A previous /review session did not complete. Files that may not have had bug-fixer or test-writer run: ${ACTIVE_FILES}. Run /review to resume or delete .claude/.review-queue-active.txt to dismiss."
fi

# ── Recent decisions ──────────────────────────────────────────────────────────
RECENT_DECISIONS=""
if [[ -f "docs/decisions/index.md" ]]; then
  RECENT_DECISIONS=$(tail -n 8 "docs/decisions/index.md" 2>/dev/null | head -c 400 || echo "")
fi

# ── Recent research ───────────────────────────────────────────────────────────
RECENT_RESEARCH=""
if [[ -f "docs/research/index.md" ]]; then
  RECENT_RESEARCH=$(tail -n 8 "docs/research/index.md" 2>/dev/null | head -c 400 || echo "")
fi

# ── FILL IN detector ──────────────────────────────────────────────────────────
SETUP_WARNING=""
if grep -q "FILL IN:" CLAUDE.md 2>/dev/null; then
  SETUP_WARNING=" | ⚠ CLAUDE.md not customized — run: bash setup.sh"
fi

ORIENTATION="When stuck: (1) docs/research/index.md (2) docs/decisions/index.md (3) REFERENCE.md (4) invoke researcher. Ask user only as last resort."
CONTEXT="${AGENT_MAP} | Branch: ${BRANCH}${SETUP_WARNING}${INTERRUPTED_REVIEW} | ${ORIENTATION} | Recent decisions: ${RECENT_DECISIONS} | Recent research: ${RECENT_RESEARCH}"

# ── Log session start ─────────────────────────────────────────────────────────
if command -v jq >/dev/null 2>&1; then
  DATA=$(jq -n --arg branch "$BRANCH" --arg sid "$SESSION_ID" \
    '{branch: $branch, session_id: $sid}' 2>/dev/null) || DATA="{}"
  bash .claude/hooks/session-logger.sh "session_start" "$DATA" 2>/dev/null || true
fi

# ── Output ────────────────────────────────────────────────────────────────────
if command -v jq >/dev/null 2>&1; then
  jq -n --arg ctx "$CONTEXT" '{"additionalContext": $ctx}'
else
  BRANCH_SAFE=$(printf '%s' "$BRANCH" | tr -d '"\\')
  WARN=""
  grep -q "FILL IN:" CLAUDE.md 2>/dev/null && WARN=" CLAUDE.md not customized — run bash setup.sh"
  printf '{"additionalContext": "Branch: %s.%s Install jq for full context: brew install jq"}\n' \
    "$BRANCH_SAFE" "$WARN"
fi
