#!/usr/bin/env bash
# UserPromptSubmit — logs every user prompt for session analysis.
# Records character count only — no token approximation (char/4 is too inaccurate).
set -uo pipefail

[[ ! -f ".claude/.current-session-id" ]] && exit 0
if ! command -v jq >/dev/null 2>&1; then exit 0; fi

INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // ""' 2>/dev/null || echo "")
[[ -z "$PROMPT" ]] && exit 0

CHAR_COUNT=${#PROMPT}
SNIPPET=$(echo "$PROMPT" | head -c 300 | tr '\n' ' ')

DATA=$(jq -n \
  --arg     snippet "$SNIPPET" \
  --argjson chars   "$CHAR_COUNT" \
  '{prompt_snippet: $snippet, char_count: $chars}' \
  2>/dev/null) || DATA="{\"char_count\":${CHAR_COUNT}}"

bash .claude/hooks/session-logger.sh "user_prompt" "$DATA" 2>/dev/null || true
exit 0
