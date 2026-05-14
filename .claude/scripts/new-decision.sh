#!/usr/bin/env bash
# Creates a decision file with correct naming and appends an index row.
# Usage: bash .claude/scripts/new-decision.sh <slug> <title>
# Returns the file path on stdout.
#
# slug:  kebab-case, 3-5 words (e.g. auth-strategy)
# title: human-readable title (e.g. "Authentication Strategy")
set -euo pipefail

SLUG="${1:?Usage: new-decision.sh <slug> <title>}"
TITLE="${2:?Missing title}"
DATE=$(date +%Y-%m-%d)
FILENAME="${DATE}_${SLUG}.md"
FILEPATH="docs/decisions/${FILENAME}"

mkdir -p docs/decisions

if [[ -f "$FILEPATH" ]]; then
  FILEPATH="docs/decisions/${DATE}_${SLUG}-2.md"
  FILENAME="${DATE}_${SLUG}-2.md"
fi

cat > "$FILEPATH" <<EOF
# ${TITLE}

**Date:** ${DATE}
**Status:** Active

## Decision


## Rationale


## Alternatives considered


## Consequences

EOF

echo "| ${DATE} | ${TITLE} | Active | [${FILENAME}](${FILENAME}) |" \
  >> docs/decisions/index.md

echo "$FILEPATH"
