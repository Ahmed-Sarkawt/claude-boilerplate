#!/usr/bin/env bash
# PostToolUse — queues source files for review. Human-in-the-loop via /review.
# Handles Write, Edit, and MultiEdit.
# Writes two files:
#   .claude/.review-queue.txt       — plain list of paths (one per line, deduped)
#   .claude/.review-queue-meta.jsonl — one JSON object per queued file with rich context
set -uo pipefail

INPUT=$(cat)

TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // "unknown"' 2>/dev/null || echo "unknown")

FILE_PATHS=$(echo "$INPUT" | jq -r '
  if .tool_input.file_path and (.tool_input.file_path | type) == "string" then
    .tool_input.file_path
  elif .tool_input.files then
    .tool_input.files[].file_path
  else
    empty
  end' 2>/dev/null || echo "")

[[ -z "$FILE_PATHS" ]] && exit 0

SESSION_ID=$(cat .claude/.current-session-id 2>/dev/null || echo "unknown")
QUEUED_AT=$(date -Iseconds 2>/dev/null || date +%Y-%m-%dT%H:%M:%S)

queue_file() {
  local FILE_PATH="$1"
  [[ -z "$FILE_PATH" ]] && return

  # Skip known non-source locations
  case "$FILE_PATH" in
    */node_modules/*|*/.git/*|*/dist/*|*/build/*|*/.next/*|*/coverage/*) return ;;
    */.claude/*|*/docs/*|*/public/*|*/static/*|*/__pycache__/*) return ;;
    *.log|*.lock|*.txt|*.md|*.json) return ;;
  esac

  # Skip test files
  case "$FILE_PATH" in
    *.test.*|*.spec.*|*/__tests__/*|*/test/*) return ;;
  esac

  # Only queue recognised source file types
  case "$FILE_PATH" in
    *.ts|*.tsx|*.js|*.jsx|*.mjs|*.cjs) ;;
    *.py|*.go|*.rs|*.rb|*.java|*.php|*.swift|*.kt) ;;
    *.sql|*.graphql|*.gql) ;;
    *) return ;;
  esac

  QUEUE_FILE=".claude/.review-queue.txt"
  META_FILE=".claude/.review-queue-meta.jsonl"
  mkdir -p .claude

  # Plain queue — deduped filename list (unchanged format, backward-compatible)
  grep -qxF "$FILE_PATH" "$QUEUE_FILE" 2>/dev/null || echo "$FILE_PATH" >> "$QUEUE_FILE"

  # Rich metadata — one JSON object per file per edit event (not deduped — captures all edits)
  IS_NEW_FILE=false
  [[ "$TOOL_NAME" == "Write" ]] && IS_NEW_FILE=true
  if command -v jq >/dev/null 2>&1; then
    jq -n \
      --arg path       "$FILE_PATH" \
      --arg edit_type  "$TOOL_NAME" \
      --arg queued_at  "$QUEUED_AT" \
      --arg session_id "$SESSION_ID" \
      --argjson is_new "$IS_NEW_FILE" \
      '{path: $path, edit_type: $edit_type, queued_at: $queued_at, session_id: $session_id, is_new_file: $is_new}' \
      >> "$META_FILE"
  fi

  # Session log
  if command -v jq >/dev/null 2>&1; then
    DATA=$(jq -n --arg fp "$FILE_PATH" '{file_path: $fp}' 2>/dev/null) || DATA="{}"
    bash .claude/hooks/session-logger.sh "review_queued" "$DATA" 2>/dev/null || true
  fi

  echo "📋 Queued for review: $FILE_PATH (run /review when ready)"
}

while IFS= read -r path; do
  queue_file "$path"
done <<< "$FILE_PATHS"

exit 0
