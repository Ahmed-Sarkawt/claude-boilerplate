#!/usr/bin/env bash
# Stop hook — logs session end, writes session summary. Runs async (never blocks).
set -uo pipefail

mkdir -p .claude/logs/sessions

SESSION_ID=$(cat .claude/.current-session-id 2>/dev/null || echo "unknown")
LOG_FILE=".claude/logs/sessions/${SESSION_ID}.jsonl"
TS_END=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)
BRANCH=$(git branch --show-current 2>/dev/null || echo "none")

INPUT=$(cat 2>/dev/null || echo "{}")
COST_USD=$(echo "$INPUT"     | jq -r '.cost_usd       // "n/a"' 2>/dev/null || echo "n/a")
INPUT_TOKENS=$(echo "$INPUT" | jq -r '.input_tokens   // 0'     2>/dev/null || echo "0")
OUTPUT_TOKENS=$(echo "$INPUT"| jq -r '.output_tokens  // 0'     2>/dev/null || echo "0")

if command -v jq >/dev/null 2>&1; then
  DATA=$(jq -n \
    --arg branch  "$BRANCH" \
    --arg cost    "$COST_USD" \
    --arg in_tok  "$INPUT_TOKENS" \
    --arg out_tok "$OUTPUT_TOKENS" \
    '{branch: $branch, cost_usd: $cost, input_tokens: $in_tok, output_tokens: $out_tok}' \
    2>/dev/null) || DATA="{}"
  bash .claude/hooks/session-logger.sh "session_end" "$DATA" 2>/dev/null || true
fi

if [[ -f "$LOG_FILE" ]] && command -v jq >/dev/null 2>&1; then

  PROMPT_COUNT=$(jq -r 'select(.event == "user_prompt")' "$LOG_FILE" 2>/dev/null | wc -l | tr -d ' ')
  FILES_SAVED=$(jq -r 'select(.event == "file_saved") | .data.file_path' "$LOG_FILE" 2>/dev/null \
    | sort -u | tr '\n' ', ' | sed 's/,$//' | head -c 300)
  FILES_COUNT=$(jq -r 'select(.event == "file_saved") | .data.file_path' "$LOG_FILE" 2>/dev/null \
    | sort -u | wc -l | tr -d ' ')
  BLOCKED=$(jq -r 'select(.event == "command_blocked")' "$LOG_FILE" 2>/dev/null | wc -l | tr -d ' ')
  AGENTS_RAW=$(jq -r 'select(.event == "agent_stop") | .data.agent' "$LOG_FILE" 2>/dev/null)
  AGENTS_SUMMARY=$(echo "$AGENTS_RAW" | sort | uniq -c | sort -rn \
    | awk '{print $2"("$1"x)"}' | tr '\n' ' ' | head -c 200)
  PROMPT_CHARS=$(jq -r 'select(.event == "user_prompt") | .data.char_count // 0' \
    "$LOG_FILE" 2>/dev/null | awk '{s+=$1} END {print s+0}')

  # Duration — use Python3 for correct cross-platform ISO 8601 parsing with timezone.
  # Falls back to each platform's date command, then gives up gracefully.
  START_TS=$(jq -r 'select(.event == "session_start") | .ts' "$LOG_FILE" 2>/dev/null | head -1)
  DURATION="unknown"
  if [[ -n "$START_TS" ]]; then
    START_EPOCH=$(python3 -c "
from datetime import datetime
ts = '$START_TS'
try:
    dt = datetime.fromisoformat(ts)
    print(int(dt.timestamp()))
except Exception:
    print(0)
" 2>/dev/null) || \
    START_EPOCH=$(date -d "$START_TS" +%s 2>/dev/null) || \
    START_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${START_TS%%[+-]*}" +%s 2>/dev/null) || \
    START_EPOCH=0

    if [[ "${START_EPOCH:-0}" -gt 0 ]]; then
      SECS=$(( $(date +%s) - START_EPOCH ))
      DURATION="${SECS}s ($(( SECS / 60 ))m)"
    fi
  fi

  REPEATED=""
  while IFS= read -r line; do
    COUNT=$(echo "$line" | awk '{print $1}')
    AGENT=$(echo "$line" | awk '{print $2}')
    [[ "${COUNT:-0}" -ge 3 ]] && REPEATED="${REPEATED} ${AGENT}(${COUNT}x)"
  done < <(echo "$AGENTS_RAW" | sort | uniq -c | sort -rn)

  SUMMARY_FILE=".claude/logs/session-summary.md"
  {
    echo ""
    echo "## ${SESSION_ID}"
    echo "- **Date:** ${TS_END}"
    echo "- **Branch:** ${BRANCH}"
    echo "- **Duration:** ${DURATION}"
    echo "- **User prompts:** ${PROMPT_COUNT}"
    echo "- **Files modified:** ${FILES_COUNT}${FILES_SAVED:+ — ${FILES_SAVED}}"
    echo "- **Agents invoked:** ${AGENTS_SUMMARY:-none}"
    echo "- **Dangerous commands blocked:** ${BLOCKED}"
    echo "- **User prompt chars:** ${PROMPT_CHARS} (token counts require Claude Code Stop hook data)"
    if [[ "$COST_USD" != "n/a" && "$COST_USD" != "0" ]]; then
      echo "- **Cost (from Claude Code):** \$${COST_USD} | in: ${INPUT_TOKENS} | out: ${OUTPUT_TOKENS}"
    else
      echo "- **Cost:** not provided by Claude Code (Stop hook metadata unavailable)"
    fi
    [[ -n "$REPEATED" ]] && echo "- **⚠ Repeated agent calls (3x+):** ${REPEATED} — consider adding a rule or skill"
  } >> "$SUMMARY_FILE"

fi

echo "[${TS_END}] end — ${SESSION_ID} — branch:${BRANCH} prompts:${PROMPT_COUNT:-?} files:${FILES_COUNT:-?}" \
  >> .claude/logs/sessions.log 2>/dev/null || true

exit 0
