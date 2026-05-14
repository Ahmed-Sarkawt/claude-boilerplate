#!/usr/bin/env bash
# PostToolUse Write|Edit|MultiEdit — when a route, API, or schema file changes,
# remind Claude to invoke doc-updater and consider recording a decision.
set -uo pipefail

if ! command -v jq >/dev/null 2>&1; then exit 0; fi

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")
[[ -z "$FILE_PATH" ]] && exit 0

# Only trigger for route, API, or schema files
SHOULD_TRIGGER=false
case "$FILE_PATH" in
  */routes/*|*/route/*|*/api/*|*/server/*|*/controllers/*|*/handlers/*) SHOULD_TRIGGER=true ;;
  *.sql|*.prisma|*.graphql|*.gql) SHOULD_TRIGGER=true ;;
esac
[[ "$SHOULD_TRIGGER" != "true" ]] && exit 0

# Skip test files
case "$FILE_PATH" in
  *.test.*|*.spec.*) exit 0 ;;
esac

# Skip if docs/ folder doesn't exist yet (project not set up)
[[ ! -d "docs" ]] && exit 0

jq -n --arg fp "$FILE_PATH" '{
  "additionalContext": ("ROUTE/API/SCHEMA CHANGED: `" + $fp + "` was modified. If this adds, removes, or changes a route, endpoint, or DB schema: (1) invoke doc-updater to sync docs/flow/ and docs/decisions/, (2) consider whether this decision should be recorded with `bash .claude/scripts/new-decision.sh`. Skip if this was a minor internal change.")
}'
