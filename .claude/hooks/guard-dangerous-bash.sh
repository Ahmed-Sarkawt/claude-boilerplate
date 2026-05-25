#!/usr/bin/env bash
# PreToolUse for Bash — blocks dangerous commands before they run.
# Uses grep -iqE (case-insensitive) so SQL DROP/TRUNCATE blocks lowercase too.
# Each pattern is checked independently — a grep error skips that check, not the whole guard.
# Exit 2 = block. Exit 0 = allow.
set -uo pipefail

INPUT=$(cat)

if ! command -v jq >/dev/null 2>&1; then
  echo "🔴 SECURITY: jq not installed — all safety guards are disabled. Install immediately: brew install jq (macOS) or apt install jq (Linux)" >&2
  exit 2
fi

COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null)
# Block on jq parse failure — an empty COMMAND would silently allow everything through
if [[ $? -ne 0 ]]; then
  echo "Blocked: failed to parse hook input JSON" >&2
  exit 2
fi

# Patterns checked with grep -iqE (case-insensitive extended regex).
# rm: catch all recursive variants (-r, -rf, -fR, -Rf, --recursive) not just -rf.
# SQL: lowercase variants now blocked too.
BLOCKED_PATTERNS=(
  'rm[[:space:]].*(-[a-zA-Z]*[rR]|--recursive)'
  'drop[[:space:]]+table'
  'drop[[:space:]]+database'
  'truncate[[:space:]]+table'
  ':\(\)\{'
  'mkfs\.'
  'dd[[:space:]]+if=.*of=/dev/'
  'chmod[[:space:]]+-R[[:space:]]+777[[:space:]]+/'
  'curl[[:space:]]+.*\|[[:space:]]*(ba)?sh'
  'wget[[:space:]]+.*\|[[:space:]]*(ba)?sh'
  'npx[[:space:]]+.*\|[[:space:]]*(ba)?sh'
)

block_command() {
  local reason="$1"
  if [[ -f ".claude/.current-session-id" ]]; then
    DATA=$(jq -n \
      --arg cmd    "${COMMAND:0:200}" \
      --arg reason "$reason" \
      '{command: $cmd, reason: $reason}' 2>/dev/null) || DATA="{}"
    bash .claude/hooks/session-logger.sh "command_blocked" "$DATA" 2>/dev/null || true
  fi
  echo "Blocked: $reason" >&2
  exit 2
}

for pattern in "${BLOCKED_PATTERNS[@]}"; do
  # -i = case-insensitive, so SQL patterns catch lowercase too
  if echo "$COMMAND" | grep -iqE "$pattern" 2>/dev/null; then
    block_command "matched pattern: $pattern"
  fi
done

# Block push to main/master without explicit override via env var
if echo "$COMMAND" | grep -iqE 'git[[:space:]]+push.*[[:space:]]+(main|master)' 2>/dev/null; then
  if [[ "${ALLOW_PUSH_MAIN:-0}" != "1" ]]; then
    block_command "direct push to main/master (export ALLOW_PUSH_MAIN=1 to override)"
  fi
fi

exit 0
