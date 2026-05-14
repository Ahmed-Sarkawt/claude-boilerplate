#!/usr/bin/env bash
# PostToolUse for Write/Edit/MultiEdit — format the file, run sibling tests, log the save.
# Always exits 0 (non-blocking). Test failures are shown but never stop Claude.
set -uo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // ""' 2>/dev/null || echo "")

[[ -z "$FILE_PATH" || ! -f "$FILE_PATH" ]] && exit 0

# ── Prettier formatting ───────────────────────────────────────────────────────
if command -v npx >/dev/null 2>&1; then
  case "$FILE_PATH" in
    *.ts|*.tsx|*.js|*.jsx|*.json|*.css|*.md)
      npx prettier --write --log-level=error "$FILE_PATH" 2>/dev/null || true
      ;;
  esac
fi

# ── Log the file save event ───────────────────────────────────────────────────
if [[ -f ".claude/.current-session-id" ]] && command -v jq >/dev/null 2>&1; then
  EXT="${FILE_PATH##*.}"
  LINES=$(wc -l < "$FILE_PATH" 2>/dev/null | tr -d ' ' || echo "0")
  DATA=$(jq -n \
    --arg fp   "$FILE_PATH" \
    --arg ext  "$EXT" \
    --argjson  lines "$LINES" \
    '{file_path: $fp, ext: $ext, line_count: $lines}' 2>/dev/null) || DATA="{}"
  bash .claude/hooks/session-logger.sh "file_saved" "$DATA" 2>/dev/null || true
fi

# ── Run sibling test file (npx guard matches the prettier guard above) ────────
if command -v npx >/dev/null 2>&1; then
  mkdir -p .claude/logs
  BASE="${FILE_PATH%.tsx}"; BASE="${BASE%.ts}"
  for ext in ".test.tsx" ".test.ts" ".spec.tsx" ".spec.ts"; do
    TEST_FILE="${BASE}${ext}"
    if [[ -f "$TEST_FILE" ]]; then
      : > .claude/logs/last-test-run.txt
      if npx vitest run "$TEST_FILE" --silent 2>&1 \
          | tee .claude/logs/last-test-run.txt \
          | tail -n 15; then
        true
      else
        echo "⚠️  Tests failed for $TEST_FILE — see above" >&2
      fi
      break
    fi
  done
fi

exit 0
