#!/usr/bin/env bash
# Core session logger — called by other hooks to write structured JSONL entries.
# Usage: bash .claude/hooks/session-logger.sh <event> [json_data]
# json_data must be valid JSON. Omit for bare event entries.
set -uo pipefail

EVENT="${1:-unknown}"
DATA="${2:-{}}"

LOG_DIR=".claude/logs/sessions"
SESSION_FILE=".claude/.current-session-id"

mkdir -p "$LOG_DIR" 2>/dev/null || exit 0

SESSION_ID=$(cat "$SESSION_FILE" 2>/dev/null || echo "no-session")
LOG_FILE="${LOG_DIR}/${SESSION_ID}.jsonl"
TS=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%SZ)

if command -v jq >/dev/null 2>&1; then
  jq -n \
    --arg ts    "$TS" \
    --arg sid   "$SESSION_ID" \
    --arg evt   "$EVENT" \
    --argjson d "$DATA" \
    '{ts: $ts, session_id: $sid, event: $evt, data: $d}' \
    >> "$LOG_FILE" 2>/dev/null || true
else
  # Fallback — minimal escaping, good enough for grep/analysis
  printf '{"ts":"%s","session_id":"%s","event":"%s","data":%s}\n' \
    "$TS" "$SESSION_ID" "$EVENT" "$DATA" >> "$LOG_FILE" 2>/dev/null || true
fi

exit 0
