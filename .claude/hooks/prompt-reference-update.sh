#!/usr/bin/env bash
# PostToolUse Write — when a new file is created, prompt Claude to add a row to REFERENCE.md.
# Only fires on Write (new file creation), not Edit or MultiEdit (modifications to existing files).
set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then exit 0; fi

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name // ""' 2>/dev/null || echo "")

# Only new file creation
[[ "$TOOL_NAME" != "Write" ]] && exit 0

FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
[[ -z "$FILE_PATH" ]] && exit 0

# Skip non-source locations
case "$FILE_PATH" in
  */node_modules/*|*/.git/*|*/dist/*|*/build/*|*/.next/*) exit 0 ;;
  */.claude/*|*/coverage/*|*/__pycache__/*) exit 0 ;;
  *.log|*.lock) exit 0 ;;
esac

# Only prompt if REFERENCE.md exists
[[ ! -f "REFERENCE.md" ]] && exit 0

# Skip if already indexed
if grep -qF "$FILE_PATH" REFERENCE.md 2>/dev/null; then exit 0; fi

# Use --arg to safely handle any characters in the file path
jq -n --arg fp "$FILE_PATH" \
  '{"additionalContext": ("NEW FILE: `" + $fp + "` was just created and is not yet in REFERENCE.md. Add a one-line entry for it under the appropriate section. Format: | `" + $fp + "` | <what this file does — one line> |")}'
