#!/usr/bin/env bash
# claude-boilerplate setup script
# Interactive — asks questions and applies changes before your first session.
set -euo pipefail

RESET='\033[0m'
BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'

ask() {
  local prompt="$1" default="${2:-}"
  if [[ -n "$default" ]]; then
    read -rp "$(echo -e "${CYAN}${prompt}${RESET} [${default}]: ")" answer
  else
    read -rp "$(echo -e "${CYAN}${prompt}${RESET}: ")" answer
  fi
  echo "${answer:-$default}"
}

confirm() {
  read -rp "$(echo -e "${CYAN}${1}${RESET} [y/N]: ")" answer
  [[ "${answer,,}" == "y" ]]
}

section() {
  echo -e "\n${BOLD}${1}${RESET}"
  printf '%s\n' "$(echo "$1" | sed 's/./-/g')"
}

# Safe string replacement — requires Python3. No fallback: the awk alternative
# has the same regex injection problem we're trying to avoid.
safe_replace_in_file() {
  local file="$1" search="$2" replace="$3"
  if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}✗ python3 not found — required for safe CLAUDE.md updates.${RESET}" >&2
    echo -e "  Install: brew install python3 (macOS) | apt install python3 (Ubuntu)" >&2
    echo -e "  Skipping replacement of: ${search}" >&2
    return 1
  fi
  python3 - "$file" "$search" "$replace" <<'PYEOF'
import sys
file, search, replace = sys.argv[1], sys.argv[2], sys.argv[3]
content = open(file).read()
content = content.replace(search, replace, 1)
open(file, 'w').write(content)
PYEOF
  fi
}

echo -e "${BOLD}claude-boilerplate setup${RESET}"
echo "Customizes your Claude Code config in 2 minutes."
echo ""

# ── Dependency checks ─────────────────────────────────────────────────────────
section "Checking dependencies"

MISSING_DEPS=false

if ! command -v jq >/dev/null 2>&1; then
  echo -e "${RED}✗ jq not found${RESET} — required for all hooks. Without it, safety guards and context injection are disabled."
  echo "  Install: brew install jq (macOS) | apt install jq (Ubuntu) | https://jqlang.org"
  MISSING_DEPS=true
else
  echo -e "${GREEN}✓${RESET} jq"
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo -e "${RED}✗ python3 not found${RESET} — required by setup.sh for safe file replacement."
  echo "  Install: brew install python3 (macOS) | apt install python3 (Ubuntu)"
  MISSING_DEPS=true
else
  echo -e "${GREEN}✓${RESET} python3"
fi

if ! command -v claude >/dev/null 2>&1; then
  echo -e "${YELLOW}⚠  Claude Code CLI not found${RESET}"
  echo "  Install from: https://claude.ai/code"
  echo "  (Setup will complete — install Claude Code before running 'claude')"
else
  echo -e "${GREEN}✓${RESET} claude"
fi

if [[ "$MISSING_DEPS" == true ]]; then
  echo -e "\n${RED}Install missing dependencies before using this boilerplate.${RESET}"
  echo "Setup will still write config files — hooks will degrade gracefully until fixed."
fi

# ── 1. Project basics ─────────────────────────────────────────────────────────
section "1. Project basics"

PROJECT_NAME=$(ask "Project name" "$(basename "$PWD")")
PROJECT_DESC=$(ask "One sentence: what does this project do and who is it for?")
SUCCESS_METRIC=$(ask "Primary success metric (e.g. 'time to first value < 5 min')")

# ── 2. Source paths ───────────────────────────────────────────────────────────
section "2. Source paths"

FRONTEND_DIR=$(ask "Frontend source directory" "src")
BACKEND_DIR=$(ask "Backend source directory (leave blank if none)" "server")
TEST_RUNNER=$(ask "Test runner (vitest/jest)" "vitest")

# ── 3. Multi-worktree / Agent Teams ──────────────────────────────────────────
section "3. Multi-worktree coordination"

echo "Agent Teams (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1) lets multiple Claude"
echo "instances share a task list when running in parallel worktrees."
AGENT_TEAMS=false
if confirm "Enable experimental Agent Teams coordination?"; then
  AGENT_TEAMS=true
fi

# ── 4. Project-specific rules ─────────────────────────────────────────────────
section "4. Project-specific rules"

EXTRA_RULES=$(ask "Any project-specific hard rules to add? (leave blank to skip)")

# ── Apply changes ─────────────────────────────────────────────────────────────
section "Applying changes"

# Update CLAUDE.md — use safe_replace_in_file (immune to sed injection)
DESCRIPTION_LINE="${PROJECT_DESC} The primary success metric is: ${SUCCESS_METRIC}."
safe_replace_in_file CLAUDE.md \
  "[FILL IN: one paragraph describing the product, the persona you are building for, and the primary success metric.]" \
  "$DESCRIPTION_LINE"
echo -e "${GREEN}✓${RESET} Updated CLAUDE.md"

if [[ -n "$EXTRA_RULES" ]]; then
  echo "8. **${EXTRA_RULES}**" >> CLAUDE.md
  echo -e "${GREEN}✓${RESET} Added project-specific rule to CLAUDE.md"
fi

# Update frontend path (use safe_replace_in_file for all substitutions)
if [[ "$FRONTEND_DIR" != "src" ]]; then
  safe_replace_in_file .claude/rules/frontend.md \
    '"src/**/*.tsx", "src/**/*.jsx"' \
    "\"${FRONTEND_DIR}/**/*.tsx\", \"${FRONTEND_DIR}/**/*.jsx\""
  echo -e "${GREEN}✓${RESET} Updated frontend path to ${FRONTEND_DIR}/"
fi

# Update backend path
if [[ -n "$BACKEND_DIR" && "$BACKEND_DIR" != "server" ]]; then
  safe_replace_in_file .claude/rules/backend.md \
    '"server/**/*.ts"' \
    "\"${BACKEND_DIR}/**/*.ts\""
  echo -e "${GREEN}✓${RESET} Updated backend path to ${BACKEND_DIR}/"
fi

# Update test runner — handle jest specially (no 'run' subcommand)
if [[ "$TEST_RUNNER" != "vitest" ]]; then
  if [[ "$TEST_RUNNER" == "jest" ]]; then
    safe_replace_in_file .claude/hooks/format-and-test.sh \
      "npx vitest run" "npx jest"
  else
    safe_replace_in_file .claude/hooks/format-and-test.sh \
      "npx vitest run" "npx ${TEST_RUNNER} run"
  fi
  echo -e "${GREEN}✓${RESET} Updated test runner to ${TEST_RUNNER}"
fi


# Agent Teams
if [[ "$AGENT_TEAMS" == true ]]; then
  grep -qxF "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1" .env.claude 2>/dev/null \
    || echo "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1" >> .env.claude
  # Add .env.claude to .gitignore so it's never committed
  grep -qxF ".env.claude" .gitignore 2>/dev/null || echo ".env.claude" >> .gitignore
  echo -e "${GREEN}✓${RESET} Agent Teams enabled (.env.claude created, added to .gitignore)"
  echo -e "  ${YELLOW}Source it before starting Claude: source .env.claude${RESET}"
fi

# Make hooks executable
chmod +x .claude/hooks/*.sh
echo -e "${GREEN}✓${RESET} Made all hooks executable"

# Initialize git if needed
if ! git rev-parse --git-dir >/dev/null 2>&1; then
  git init -q
  echo -e "${GREEN}✓${RESET} Initialized git repo"
fi

# Create docs/ folder structure
mkdir -p docs/decisions docs/research docs/flow

if [[ ! -f "docs/decisions/index.md" ]]; then
  printf '# Decisions Index\n\n> One row per decision. Newest at the bottom.\n> Full rationale: `docs/decisions/YYYY-MM-DD_topic.md`\n\n| Date | Decision | Status | File |\n|------|----------|--------|------|\n' \
    > docs/decisions/index.md
  echo -e "${GREEN}✓${RESET} Created docs/decisions/index.md"
fi

FIRST_DECISION="docs/decisions/$(date +%Y-%m-%d)_initial-setup.md"
if [[ ! -f "$FIRST_DECISION" ]]; then
  cat > "$FIRST_DECISION" <<EOF
# Initial Setup

**Date:** $(date +%Y-%m-%d)
**Status:** Active

## Decision
Set up claude-boilerplate for ${PROJECT_NAME}.

## Rationale
${PROJECT_DESC}

## Alternatives considered
N/A — initial project setup.

## Consequences
Claude Code config layer active. All agents, hooks, and commands wired.
EOF
  echo "| $(date +%Y-%m-%d) | Initial setup | Active | [initial-setup.md]($(date +%Y-%m-%d)_initial-setup.md) |" \
    >> docs/decisions/index.md
  echo -e "${GREEN}✓${RESET} Created first decision file"
fi

if [[ ! -f "docs/research/index.md" ]]; then
  printf '# Research Index\n\n> One row per research session. Newest at the bottom.\n> Full findings: `docs/research/YYYY-MM-DD_topic.md`\n\n| Date | Topic | Confidence | File |\n|------|-------|------------|------|\n' \
    > docs/research/index.md
  echo -e "${GREEN}✓${RESET} Created docs/research/index.md"
fi

# docs/flow/ is already in the boilerplate (index.md + main.md)

# Summary
echo ""
section "Done"
echo -e "Project:        ${BOLD}${PROJECT_NAME}${RESET}"
echo -e "Frontend:       ${FRONTEND_DIR}/"
[[ -n "$BACKEND_DIR" ]] && echo -e "Backend:        ${BACKEND_DIR}/"
echo -e "Test runner:    ${TEST_RUNNER}"
echo -e "Agent Teams:    $([ "$AGENT_TEAMS" = true ] && echo 'enabled' || echo 'disabled')"
echo ""
echo -e "Next steps:"
echo -e "  1. Fill in ${CYAN}docs/flow/main.md${RESET} with your primary user flow"
echo -e "  2. ${CYAN}git add .claude/ CLAUDE.md REFERENCE.md docs/ .gitignore${RESET}"
echo -e "  3. ${CYAN}git commit -m 'chore: add Claude Code configuration'${RESET}"
echo -e "  4. ${CYAN}claude${RESET}  (then run /init to finalize any remaining customization)"
echo ""
echo -e "${GREEN}Setup complete.${RESET}"
