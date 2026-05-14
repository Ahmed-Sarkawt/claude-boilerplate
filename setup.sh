#!/usr/bin/env bash
# claude-boilerplate setup script
set -euo pipefail

RESET='\033[0m'
BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'

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

# Safe string replacement — requires Python3.
safe_replace_in_file() {
  local file="$1" search="$2" replace="$3"
  if ! command -v python3 >/dev/null 2>&1; then
    echo -e "${RED}✗ python3 not found — required for safe file updates.${RESET}" >&2
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
}

echo -e "${BOLD}claude-boilerplate setup${RESET}"
echo ""

# ── Mode selection ─────────────────────────────────────────────────────────────
echo -e "${BOLD}How do you want to set up?${RESET}"
echo -e "  ${GREEN}[1]${RESET} Auto      — sensible defaults, two questions only"
echo -e "  ${DIM}[2]${RESET} Basic     — recommended, 5 questions ${DIM}(default)${RESET}"
echo -e "  ${DIM}[3]${RESET} Advanced  — all options: branches, hooks, rules, and more"
echo ""
read -rp "$(echo -e "${CYAN}Mode${RESET} [2]: ")" MODE_CHOICE
MODE_CHOICE="${MODE_CHOICE:-2}"

case "$MODE_CHOICE" in
  1) SETUP_MODE="auto" ;;
  3) SETUP_MODE="advanced" ;;
  *) SETUP_MODE="basic" ;;
esac

echo -e "Running ${BOLD}${SETUP_MODE}${RESET} setup.\n"

# ── Dependency checks ──────────────────────────────────────────────────────────
section "Checking dependencies"

MISSING_DEPS=false

if ! command -v jq >/dev/null 2>&1; then
  echo -e "${RED}✗ jq not found${RESET} — required for all hooks. Without it, safety guards and context injection silently disable."
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

# ── Defaults (all modes start here) ───────────────────────────────────────────
FRONTEND_DIR="src"
BACKEND_DIR="server"
TEST_RUNNER="vitest"
AGENT_TEAMS=false
EXTRA_RULES=""
PUSH_STRATEGY="branch"   # branch | main
SUCCESS_METRIC=""

# ── 1. Project basics (every mode) ────────────────────────────────────────────
section "1. Project basics"

PROJECT_NAME=$(ask "Project name" "$(basename "$PWD")")
PROJECT_DESC=$(ask "One sentence: what does this project do and who is it for?")

# ── 2. Basic mode questions ────────────────────────────────────────────────────
if [[ "$SETUP_MODE" == "basic" || "$SETUP_MODE" == "advanced" ]]; then
  section "2. Source paths & tooling"

  FRONTEND_DIR=$(ask "Frontend source directory" "src")
  BACKEND_DIR=$(ask "Backend source directory (leave blank if none)" "server")
  TEST_RUNNER=$(ask "Test runner (vitest/jest)" "vitest")
  SUCCESS_METRIC=$(ask "Primary success metric (e.g. 'time to first value < 5 min')")

  section "3. Multi-worktree coordination"

  echo "Agent Teams (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1) lets multiple Claude"
  echo "instances share a task list when running in parallel worktrees."
  if confirm "Enable experimental Agent Teams?"; then
    AGENT_TEAMS=true
  fi
fi

# ── 3. Advanced mode questions ─────────────────────────────────────────────────
if [[ "$SETUP_MODE" == "advanced" ]]; then
  section "4. Git push strategy"

  echo "Controls whether Claude can push directly to main."
  echo ""
  echo -e "  ${GREEN}[1]${RESET} Feature branches only  — Claude always pushes to a branch, never main ${DIM}(default, safer)${RESET}"
  echo -e "  ${DIM}[2]${RESET} Allow push to main      — Claude can push directly to main"
  echo ""
  read -rp "$(echo -e "${CYAN}Strategy${RESET} [1]: ")" PUSH_CHOICE
  if [[ "${PUSH_CHOICE:-1}" == "2" ]]; then
    PUSH_STRATEGY="main"
  fi

  section "5. Project-specific rules"

  EXTRA_RULES=$(ask "Any project-specific hard rules to add? (leave blank to skip)")
fi

# ── Apply changes ──────────────────────────────────────────────────────────────
section "Applying changes"

# CLAUDE.md — project description
DESCRIPTION_LINE="${PROJECT_DESC}"
[[ -n "$SUCCESS_METRIC" ]] && DESCRIPTION_LINE="${DESCRIPTION_LINE} The primary success metric is: ${SUCCESS_METRIC}."
safe_replace_in_file CLAUDE.md \
  "[FILL IN: one paragraph describing the product, the persona you are building for, and the primary success metric.]" \
  "$DESCRIPTION_LINE"
echo -e "${GREEN}✓${RESET} Updated CLAUDE.md"

if [[ -n "$EXTRA_RULES" ]]; then
  echo "8. **${EXTRA_RULES}**" >> CLAUDE.md
  echo -e "${GREEN}✓${RESET} Added project-specific rule to CLAUDE.md"
fi

# Frontend path
if [[ "$FRONTEND_DIR" != "src" ]]; then
  safe_replace_in_file .claude/rules/frontend.md \
    '"src/**/*.tsx", "src/**/*.jsx"' \
    "\"${FRONTEND_DIR}/**/*.tsx\", \"${FRONTEND_DIR}/**/*.jsx\""
  echo -e "${GREEN}✓${RESET} Updated frontend path to ${FRONTEND_DIR}/"
fi

# Backend path
if [[ -n "$BACKEND_DIR" && "$BACKEND_DIR" != "server" ]]; then
  safe_replace_in_file .claude/rules/backend.md \
    '"server/**/*.ts"' \
    "\"${BACKEND_DIR}/**/*.ts\""
  echo -e "${GREEN}✓${RESET} Updated backend path to ${BACKEND_DIR}/"
fi

# Test runner
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

# Push strategy
if [[ "$PUSH_STRATEGY" == "main" ]]; then
  grep -qxF "ALLOW_PUSH_MAIN=1" .env.claude 2>/dev/null \
    || echo "ALLOW_PUSH_MAIN=1" >> .env.claude
  grep -qxF ".env.claude" .gitignore 2>/dev/null || echo ".env.claude" >> .gitignore
  echo -e "${GREEN}✓${RESET} Push to main allowed (.env.claude, added to .gitignore)"
  echo -e "  ${YELLOW}Source before starting Claude: source .env.claude && claude${RESET}"
else
  echo -e "${GREEN}✓${RESET} Push strategy: feature branches only"
fi

# Agent Teams
if [[ "$AGENT_TEAMS" == true ]]; then
  grep -qxF "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1" .env.claude 2>/dev/null \
    || echo "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1" >> .env.claude
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

# ── Summary ────────────────────────────────────────────────────────────────────
echo ""
section "Done"
echo -e "Project:        ${BOLD}${PROJECT_NAME}${RESET}"
echo -e "Setup mode:     ${SETUP_MODE}"
echo -e "Frontend:       ${FRONTEND_DIR}/"
[[ -n "$BACKEND_DIR" ]] && echo -e "Backend:        ${BACKEND_DIR}/"
echo -e "Test runner:    ${TEST_RUNNER}"
echo -e "Push strategy:  $([ "$PUSH_STRATEGY" = "main" ] && echo 'allow push to main' || echo 'feature branches only')"
echo -e "Agent Teams:    $([ "$AGENT_TEAMS" = true ] && echo 'enabled' || echo 'disabled')"
echo ""
echo -e "Next steps:"
echo -e "  1. Fill in ${CYAN}docs/flow/main.md${RESET} with your primary user flow"
echo -e "  2. ${CYAN}git add .claude/ CLAUDE.md REFERENCE.md docs/ .gitignore${RESET}"
echo -e "  3. ${CYAN}git commit -m 'chore: add Claude Code configuration'${RESET}"
echo -e "  4. ${CYAN}claude${RESET}  (then run /init to finalize any remaining customization)"
echo ""
echo -e "${GREEN}Setup complete.${RESET}"
