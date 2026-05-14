---
description: Analyze session logs — view activity, estimated costs, token usage, agents invoked, files changed, and repeated patterns. Use after any session to understand what happened, or across sessions to find inefficiencies.
---

## Quick summary

Read `.claude/logs/session-summary.md` for a human-readable summary of every past session (one entry per session).

## Current session detail

Read the active session JSONL:

```bash
cat ".claude/logs/sessions/$(cat .claude/.current-session-id 2>/dev/null).jsonl"
```

## Historical analysis

List recent sessions:
```bash
ls -lt .claude/logs/sessions/ | head -10
```

For each session file you want to analyze, read it and extract:

1. **Overview**
   - Date, branch, duration (diff between `session_start` and `session_end` timestamps)
   - Total user prompts (count of `user_prompt` events)

2. **Token usage**
   - Sum `input_tokens_approx` across all `user_prompt` events → estimated input tokens from prompts
   - If `session_end.data.input_tokens` is non-zero → use Claude Code's actual count
   - Note: output tokens are not captured without Stop hook metadata from Claude Code

3. **Cost**
   - From `session_end.data.cost_usd` if available
   - If `n/a`: accurate cost requires Claude Code to expose metadata in the Stop hook — not yet available in all versions

4. **Files changed**
   - All unique `file_path` values from `file_saved` events
   - Group by directory to see which areas were most active

5. **Agents invoked**
   - All `agent_stop` events → agent names + frequency
   - Flag any agent invoked 3+ times in one session as a candidate for a new rule or automation

6. **Commands blocked**
   - All `command_blocked` events → command snippets and patterns that triggered
   - If any: review whether the pattern was legitimate or a false positive

7. **Repeated tasks across sessions**
   - Read the last 5 session files
   - Find agent names appearing in `agent_stop` events across all sessions
   - Identify the top 3 most-invoked agents over time — these are the highest-value automation candidates

## Report format

```
## Session Analysis: <session_id>
### Overview
- Date / Branch / Duration / Prompts

### Token & cost
- Input tokens (approx or actual) / Output tokens / Cost

### Activity
- Files changed: <list>
- Agents: <agent(count)>
- Commands blocked: <count>

### Patterns
- Repeated agents (3x+): <list>
- Hottest file (modified most): <file>
- Recommendation: <one actionable suggestion based on patterns>
```

If cost data is unavailable from Claude Code, note: "Accurate token counts require Stop hook metadata. Prompt-based approximation shown (chars ÷ 4)."
