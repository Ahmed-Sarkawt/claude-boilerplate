#!/usr/bin/env bash
# Creates a research session file with correct naming and appends an index row.
# Usage: bash .claude/scripts/new-research.sh <slug> <title> <confidence>
# Returns the file path on stdout so the caller knows where to write content.
#
# slug:       kebab-case, 3-5 words (e.g. react-server-components)
# title:      human-readable topic (e.g. "React Server Components in Next.js 14")
# confidence: High | Medium | Low
set -euo pipefail

SLUG="${1:?Usage: new-research.sh <slug> <title> <confidence>}"
TITLE="${2:?Missing title}"
CONFIDENCE="${3:-Medium}"
DATE=$(date +%Y-%m-%d)
FILENAME="${DATE}_${SLUG}.md"
FILEPATH="docs/research/${FILENAME}"

mkdir -p docs/research

# Don't overwrite an existing file — append a suffix instead
if [[ -f "$FILEPATH" ]]; then
  FILEPATH="docs/research/${DATE}_${SLUG}-2.md"
  FILENAME="${DATE}_${SLUG}-2.md"
fi

cat > "$FILEPATH" <<EOF
# ${TITLE}

**Date:** ${DATE}
**Requested by:** researcher agent
**Confidence:** ${CONFIDENCE}

## Question


## Answer


## Key findings
-

## Sources
-

## Gaps

EOF

# Append index row
echo "| ${DATE} | ${TITLE} | ${CONFIDENCE} | [${FILENAME}](${FILENAME}) |" \
  >> docs/research/index.md

# Return the path so the researcher knows where to write
echo "$FILEPATH"
