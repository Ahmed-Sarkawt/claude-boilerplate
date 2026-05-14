#!/usr/bin/env bash
# claude-boilerplate setup script
#
# Interactive (human at a terminal):
#   bash setup.sh
#
# Non-interactive (Claude Code or CI — pass all answers as flags):
#   bash setup.sh --mode auto --name "My App" --desc "A task manager for devs"
#   bash setup.sh --mode advanced --name "My App" --desc "..." \
#     --frontend src --backend server --test-runner vitest \
#     --push-strategy branch --model-tier balanced \
#     --format-on-save yes --session-logs yes \
#     --commit-signing no --branch-prefix feat \
#     --review-sensitivity strict --agent-teams no
set -euo pipefail

RESET='\033[0m'
BOLD='\033[1m'
CYAN='\033[36m'
GREEN='\033[32m'
YELLOW='\033[33m'
RED='\033[31m'
DIM='\033[2m'

# ── Defaults ───────────────────────────────────────────────────────────────────
SETUP_MODE=""
PROJECT_NAME=""
PROJECT_DESC=""
SUCCESS_METRIC=""
FRONTEND_DIR="src"
BACKEND_DIR="server"
TEST_RUNNER="vitest"
PUSH_STRATEGY="branch"
MODEL_TIER="balanced"
FORMAT_ON_SAVE=true
SESSION_LOGS=true
COMMIT_SIGNING=false
BRANCH_PREFIX=""
REVIEW_SENSITIVITY="strict"
AGENT_TEAMS=false
EXTRA_RULES=""
NON_INTERACTIVE=false

# ── Flag parsing ───────────────────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --mode)             SETUP_MODE="$2";           shift 2 ;;
    --name)             PROJECT_NAME="$2";          shift 2 ;;
    --desc)             PROJECT_DESC="$2";          shift 2 ;;
    --metric)           SUCCESS_METRIC="$2";        shift 2 ;;
    --frontend)         FRONTEND_DIR="$2";          shift 2 ;;
    --backend)          BACKEND_DIR="$2";           shift 2 ;;
    --test-runner)      TEST_RUNNER="$2";           shift 2 ;;
    --push-strategy)    PUSH_STRATEGY="$2";         shift 2 ;;
    --model-tier)       MODEL_TIER="$2";            shift 2 ;;
    --format-on-save)   [[ "$2" == "no" ]] && FORMAT_ON_SAVE=false;   shift 2 ;;
    --session-logs)     [[ "$2" == "no" ]] && SESSION_LOGS=false;      shift 2 ;;
    --commit-signing)   [[ "$2" == "yes" ]] && COMMIT_SIGNING=true;    shift 2 ;;
    --branch-prefix)    BRANCH_PREFIX="$2";         shift 2 ;;
    --review-sensitivity) REVIEW_SENSITIVITY="$2";  shift 2 ;;
    --agent-teams)      [[ "$2" == "yes" ]] && AGENT_TEAMS=true;       shift 2 ;;
    --extra-rules)      EXTRA_RULES="$2";           shift 2 ;;
    *) echo "Unknown flag: $1" >&2; exit 1 ;;
  esac
done

# If any flag was provided, skip all interactive prompts
[[ -n "$SETUP_MODE$PROJECT_NAME$PROJECT_DESC" ]] && NON_INTERACTIVE=true

# ── Helpers ────────────────────────────────────────────────────────────────────
ask() {
  local prompt="$1" default="${2:-}"
  if [[ "$NON_INTERACTIVE" == true ]]; then
    echo "${default}"
    return
  fi
  if [[ -n "$default" ]]; then
    read -rp "$(echo -e "${CYAN}${prompt}${RESET} [${default}]: ")" answer
  else
    read -rp "$(echo -e "${CYAN}${prompt}${RESET}: ")" answer
  fi
  echo "${answer:-$default}"
}

confirm() {
  if [[ "$NON_INTERACTIVE" == true ]]; then
    # In non-interactive mode, caller sets the variable directly via flags
    return 1
  fi
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
    echo -e "${RED}✗ python3 not found — required for safe file updates.${RESET}" >&2
    echo -e "  Install: brew install python3 (macOS) | apt install python3 (Ubuntu)" >&2
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

# In-place settings.json edit via jq (jq is a required dep — already checked).
update_settings() {
  local filter="$1"
  local tmp
  tmp=$(mktemp)
  jq "$filter" .claude/settings.json > "$tmp" && mv "$tmp" .claude/settings.json
}

# ── Header ─────────────────────────────────────────────────────────────────────
echo -e "${BOLD}claude-boilerplate setup${RESET}"
[[ "$NON_INTERACTIVE" == true ]] && echo -e "${DIM}Running in non-interactive mode.${RESET}"
echo ""

# ── Mode selection (interactive only) ─────────────────────────────────────────
if [[ "$NON_INTERACTIVE" == false && -z "$SETUP_MODE" ]]; then
  echo -e "${BOLD}How do you want to set up?${RESET}"
  echo -e "  ${GREEN}[1]${RESET} Auto      — sensible defaults, two questions only"
  echo -e "  ${DIM}[2]${RESET} Basic     — recommended, 5 questions ${DIM}(default)${RESET}"
  echo -e "  ${DIM}[3]${RESET} Advanced  — all options: models, branches, hooks, and more"
  echo ""
  read -rp "$(echo -e "${CYAN}Mode${RESET} [2]: ")" MODE_CHOICE
  case "${MODE_CHOICE:-2}" in
    1) SETUP_MODE="auto" ;;
    3) SETUP_MODE="advanced" ;;
    *) SETUP_MODE="basic" ;;
  esac
fi

[[ -z "$SETUP_MODE" ]] && SETUP_MODE="basic"
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

# ── 1. Project basics (every mode) ────────────────────────────────────────────
section "1. Project basics"

[[ -z "$PROJECT_NAME" ]] && PROJECT_NAME=$(ask "Project name" "$(basename "$PWD")")
[[ -z "$PROJECT_DESC" ]] && PROJECT_DESC=$(ask "One sentence: what does this project do and who is it for?")

# ── 2. Basic questions ────────────────────────────────────────────────────────
if [[ "$SETUP_MODE" == "basic" || "$SETUP_MODE" == "advanced" ]]; then
  section "2. Source paths & tooling"

  FRONTEND_DIR=$(ask "Frontend source directory" "$FRONTEND_DIR")
  BACKEND_DIR=$(ask "Backend source directory (leave blank if none)" "$BACKEND_DIR")
  TEST_RUNNER=$(ask "Test runner (vitest/jest)" "$TEST_RUNNER")
  SUCCESS_METRIC=$(ask "Primary success metric (e.g. 'time to first value < 5 min')" "$SUCCESS_METRIC")

  section "3. Multi-worktree coordination"

  echo "Agent Teams (CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1) lets multiple Claude"
  echo "instances share a task list when running in parallel worktrees."
  if [[ "$NON_INTERACTIVE" == false ]] && confirm "Enable experimental Agent Teams?"; then
    AGENT_TEAMS=true
  fi
fi

# ── 3. Advanced questions ─────────────────────────────────────────────────────
if [[ "$SETUP_MODE" == "advanced" ]]; then

  section "4. Git push strategy"
  if [[ "$NON_INTERACTIVE" == false ]]; then
    echo "Controls whether Claude can push directly to main."
    echo ""
    echo -e "  ${GREEN}[1]${RESET} Feature branches only  — Claude always pushes to a branch, never main ${DIM}(default, safer)${RESET}"
    echo -e "  ${DIM}[2]${RESET} Allow push to main      — Claude can push directly to main"
    echo ""
    read -rp "$(echo -e "${CYAN}Strategy${RESET} [1]: ")" PUSH_CHOICE
    [[ "${PUSH_CHOICE:-1}" == "2" ]] && PUSH_STRATEGY="main"
  fi

  section "5. Default model tier"
  if [[ "$NON_INTERACTIVE" == false ]]; then
    echo "Controls which Claude model powers each agent."
    echo ""
    echo -e "  ${DIM}[1]${RESET} Economy   — haiku for all agents (fastest, cheapest)"
    echo -e "  ${GREEN}[2]${RESET} Balanced  — sonnet for primary, haiku for utility ${DIM}(default)${RESET}"
    echo -e "  ${DIM}[3]${RESET} Powerful  — opus for primary, sonnet for utility"
    echo ""
    read -rp "$(echo -e "${CYAN}Tier${RESET} [2]: ")" MODEL_CHOICE
    case "${MODEL_CHOICE:-2}" in
      1) MODEL_TIER="economy" ;;
      3) MODEL_TIER="powerful" ;;
      *) MODEL_TIER="balanced" ;;
    esac
  fi

  section "6. Auto-format on save"
  if [[ "$NON_INTERACTIVE" == false ]]; then
    echo "Runs Prettier + the file's sibling test automatically on every file save."
    if ! confirm "Enable auto-format and test on save?"; then
      FORMAT_ON_SAVE=false
    fi
  fi

  section "7. Session logging"
  if [[ "$NON_INTERACTIVE" == false ]]; then
    echo "Writes every prompt and session summary to .claude/logs/. Used by /session-log."
    if ! confirm "Enable session logging?"; then
      SESSION_LOGS=false
    fi
  fi

  section "8. Commit signing"
  if [[ "$NON_INTERACTIVE" == false ]]; then
    echo "Requires GPG. Sets git config commit.gpgsign=true and adds a hard rule to CLAUDE.md."
    if confirm "Enforce signed commits?"; then
      COMMIT_SIGNING=true
    fi
  fi

  section "9. Branch naming convention"
  if [[ "$NON_INTERACTIVE" == false ]]; then
    echo "Adds a hard rule to CLAUDE.md so Claude always names branches consistently."
    echo "Examples: feat, fix, claude, chore"
    BRANCH_PREFIX=$(ask "Branch prefix (leave blank to skip)")
  fi

  section "10. Review sensitivity"
  if [[ "$NON_INTERACTIVE" == false ]]; then
    echo "Controls which findings the code-reviewer includes in its output."
    echo ""
    echo -e "  ${GREEN}[1]${RESET} Strict   — reports 🔴 Block, 🟡 Recommend, and 🟢 Note ${DIM}(default)${RESET}"
    echo -e "  ${DIM}[2]${RESET} Normal   — reports 🔴 Block and 🟡 Recommend only"
    echo -e "  ${DIM}[3]${RESET} Relaxed  — reports 🔴 Block only"
    echo ""
    read -rp "$(echo -e "${CYAN}Sensitivity${RESET} [1]: ")" REVIEW_CHOICE
    case "${REVIEW_CHOICE:-1}" in
      2) REVIEW_SENSITIVITY="normal" ;;
      3) REVIEW_SENSITIVITY="relaxed" ;;
      *) REVIEW_SENSITIVITY="strict" ;;
    esac
  fi

  section "11. Project-specific rules"
  if [[ "$NON_INTERACTIVE" == false ]]; then
    EXTRA_RULES=$(ask "Any project-specific hard rules to add? (leave blank to skip)")
  fi
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

# Model tier
if [[ "$MODEL_TIER" != "balanced" ]]; then
  PRIMARY_AGENTS=(code-reviewer researcher test-writer ux-auditor)
  UTILITY_AGENTS=(bug-fixer research-executor doc-updater)

  if [[ "$MODEL_TIER" == "economy" ]]; then
    for agent in "${PRIMARY_AGENTS[@]}"; do
      safe_replace_in_file ".claude/agents/${agent}.md" "model: sonnet" "model: haiku"
    done
  elif [[ "$MODEL_TIER" == "powerful" ]]; then
    for agent in "${PRIMARY_AGENTS[@]}"; do
      safe_replace_in_file ".claude/agents/${agent}.md" "model: sonnet" "model: opus"
    done
    for agent in "${UTILITY_AGENTS[@]}"; do
      safe_replace_in_file ".claude/agents/${agent}.md" "model: haiku" "model: sonnet"
    done
  fi
  echo -e "${GREEN}✓${RESET} Model tier: ${MODEL_TIER}"
fi

# Auto-format on save
if [[ "$FORMAT_ON_SAVE" == false ]]; then
  update_settings \
    '(.hooks.PostToolUse) |= map(select(any(.hooks[]; .command | contains("format-and-test")) | not))'
  echo -e "${GREEN}✓${RESET} Auto-format on save disabled"
fi

# Session logging
if [[ "$SESSION_LOGS" == false ]]; then
  update_settings 'del(.hooks.UserPromptSubmit) | del(.hooks.Stop)'
  echo -e "${GREEN}✓${RESET} Session logging disabled"
fi

# Commit signing
if [[ "$COMMIT_SIGNING" == true ]]; then
  if git rev-parse --git-dir >/dev/null 2>&1; then
    git config commit.gpgsign true
  fi
  echo "8. **Sign all commits. Always use \`git commit -S\`. Never use \`--no-gpg-sign\`.**" >> CLAUDE.md
  echo -e "${GREEN}✓${RESET} Commit signing enforced (git config + CLAUDE.md rule)"
  echo -e "  ${YELLOW}Requires a GPG key: https://docs.github.com/authentication/managing-commit-signature-verification${RESET}"
fi

# Branch naming convention
if [[ -n "$BRANCH_PREFIX" ]]; then
  echo "8. **Branch names must follow \`${BRANCH_PREFIX}/<short-description>\` (e.g. \`${BRANCH_PREFIX}/add-login\`). Never push directly to main unless ALLOW_PUSH_MAIN=1 is set.**" >> CLAUDE.md
  echo -e "${GREEN}✓${RESET} Branch naming convention: ${BRANCH_PREFIX}/<description>"
fi

# Extra project-specific rules
if [[ -n "$EXTRA_RULES" ]]; then
  echo "8. **${EXTRA_RULES}**" >> CLAUDE.md
  echo -e "${GREEN}✓${RESET} Added project-specific rule to CLAUDE.md"
fi

# Review sensitivity
if [[ "$REVIEW_SENSITIVITY" == "normal" ]]; then
  cat >> .claude/agents/code-reviewer.md <<'EOF'

## Review threshold

Report **🔴 Block** and **🟡 Recommend** findings only. Do not include **🟢 Note** findings in your output.
EOF
  echo -e "${GREEN}✓${RESET} Review sensitivity: normal (Block + Recommend)"
elif [[ "$REVIEW_SENSITIVITY" == "relaxed" ]]; then
  cat >> .claude/agents/code-reviewer.md <<'EOF'

## Review threshold

Report **🔴 Block** findings only. Do not include **🟡 Recommend** or **🟢 Note** findings in your output.
EOF
  echo -e "${GREEN}✓${RESET} Review sensitivity: relaxed (Block only)"
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
echo -e "Project:          ${BOLD}${PROJECT_NAME}${RESET}"
echo -e "Setup mode:       ${SETUP_MODE}"
echo -e "Frontend:         ${FRONTEND_DIR}/"
[[ -n "$BACKEND_DIR" ]] && echo -e "Backend:          ${BACKEND_DIR}/"
echo -e "Test runner:      ${TEST_RUNNER}"
echo -e "Push strategy:    $([ "$PUSH_STRATEGY" = "main" ] && echo 'allow push to main' || echo 'feature branches only')"
echo -e "Model tier:       ${MODEL_TIER}"
echo -e "Format on save:   $([ "$FORMAT_ON_SAVE" = true ] && echo 'enabled' || echo 'disabled')"
echo -e "Session logging:  $([ "$SESSION_LOGS" = true ] && echo 'enabled' || echo 'disabled')"
echo -e "Commit signing:   $([ "$COMMIT_SIGNING" = true ] && echo 'enabled' || echo 'disabled')"
[[ -n "$BRANCH_PREFIX" ]] && echo -e "Branch prefix:    ${BRANCH_PREFIX}/"
echo -e "Review:           ${REVIEW_SENSITIVITY}"
echo -e "Agent Teams:      $([ "$AGENT_TEAMS" = true ] && echo 'enabled' || echo 'disabled')"
echo ""
echo -e "Next steps:"
echo -e "  1. Fill in ${CYAN}docs/flow/main.md${RESET} with your primary user flow"
echo -e "  2. ${CYAN}git add .claude/ CLAUDE.md REFERENCE.md docs/ .gitignore${RESET}"
echo -e "  3. ${CYAN}git commit -m 'chore: add Claude Code configuration'${RESET}"
echo -e "  4. ${CYAN}claude${RESET}  (then run /init to finalize any remaining customization)"
echo ""
echo -e "${GREEN}Setup complete.${RESET}"
