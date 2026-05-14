#!/usr/bin/env bash
# PostToolUse — queues source files for review. Human-in-the-loop via /review.
# Handles Write, Edit, and MultiEdit (which may pass a single file_path or an array).
set -uo pipefail

INPUT=$(cat)

# Extract file path(s) — handles both single string (Write/Edit/MultiEdit)
# and a potential files array format if Claude Code changes the MultiEdit schema.
FILE_PATHS=$(echo "$INPUT" | jq -r '
  if .tool_input.file_path and (.tool_input.file_path | type) == "string" then
    .tool_input.file_path
  elif .tool_input.files then
    .tool_input.files[].file_path
  else
    empty
  end' 2>/dev/null || echo "")

[[ -z "$FILE_PATHS" ]] && exit 0

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
  mkdir -p .claude
  grep -qxF "$FILE_PATH" "$QUEUE_FILE" 2>/dev/null || echo "$FILE_PATH" >> "$QUEUE_FILE"

  if [[ -f ".claude/.current-session-id" ]] && command -v jq >/dev/null 2>&1; then
    DATA=$(jq -n --arg fp "$FILE_PATH" '{file_path: $fp}' 2>/dev/null) || DATA="{}"
    bash .claude/hooks/session-logger.sh "review_queued" "$DATA" 2>/dev/null || true
  fi

  echo "📋 Queued for review: $FILE_PATH (run /review when ready)"
}

# Process each file path (handles single or multiple)
while IFS= read -r path; do
  queue_file "$path"
done <<< "$FILE_PATHS"

exit 0
