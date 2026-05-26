# Claude Code Artifacts and Routines — Boilerplate Integration Research

**Date:** 2026-05-25
**Requested by:** researcher agent
**Confidence:** High

## Question

What are Claude Code "artifacts" and "routines/scheduled tasks"? What exactly can a developer boilerplate add to support these features — hooks, settings, agent definitions, commands, docs?

## Answer

"Artifacts" has two distinct meanings in the Anthropic ecosystem that must not be conflated. First, claude.ai UI Artifacts are the rich content side-panel feature on claude.ai (web) — standalone, renderable outputs like React apps, HTML, SVGs, Mermaid diagrams, and downloadable files. They are a user-facing product feature, not a developer API or CLI concept. Second, "filesystem artifacts" is an informal SDK doc term for SKILL.md files that define agent capabilities. Third, the Files API (/v1/files) is a separate beta REST API for persisting files server-side across API calls, relevant only to Client SDK or Agent SDK applications.

For routines: Claude Code has three scheduling mechanisms. Session-scoped /loop (CronCreate/CronList/CronDelete tools, 7-day expiry, requires open session). Desktop Scheduled Tasks (persistent on your machine, requires Desktop app open, stored as SKILL.md at ~/.claude/scheduled-tasks/). Cloud Routines (Anthropic-managed infrastructure, survives machine off, supports Schedule/API/GitHub triggers, research preview, minimum 1-hour interval).

## Key findings

- Artifacts in the Claude Code CLI context are not a formal feature — the term maps to Skills (SKILL.md filesystem files) and has no special API
- claude.ai Artifacts (web side-panel) are entirely separate from Claude Code CLI; do not conflate them
- The Files API (platform.claude.com) is a beta REST API for persisting files by file_id — useful for Agent SDK apps that repeatedly reference large documents, not for CLI boilerplate
- Files API limits: 500 MB per file, 500 GB per org, upload/delete/list operations are free, content counts as input tokens
- Files API requires beta header anthropic-beta: files-api-2025-04-14 and is not available on Bedrock or Vertex AI
- Uploaded files cannot be downloaded — only files created by skills or code execution tool can be downloaded via GET /v1/files/{file_id}/content
- /loop is a bundled skill wrapping CronCreate/CronList/CronDelete, requires v2.1.72+, up to 50 tasks/session
- .claude/loop.md replaces the built-in maintenance prompt for bare /loop; project-level takes precedence over ~/.claude/loop.md; 25,000 byte limit
- /loop tasks expire after 7 days automatically; restores on --resume if within expiry window
- CLAUDE_CODE_DISABLE_CRON=1 disables the scheduler entirely — important to document
- Desktop Scheduled Tasks store their prompt as a SKILL.md at ~/.claude/scheduled-tasks/<name>/SKILL.md
- A Desktop task can reschedule itself via the update_scheduled_task MCP tool from within a running session
- Cloud Routines require claude.ai subscription login — /schedule silently returns "Unknown command" if ANTHROPIC_API_KEY, ANTHROPIC_AUTH_TOKEN, DISABLE_TELEMETRY, DO_NOT_TRACK, or CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC is set
- Minimum CLI version for /schedule is v2.1.81
- Cloud Routines API trigger uses beta header anthropic-beta: experimental-cc-routine-2026-04-01
- Routines only push to claude/-prefixed branches by default; unrestricted push must be explicitly enabled per repo
- Routines count against daily run cap (one-off runs are exempt); usage credits can extend this
- Agent SDK credit (new June 15 2026): Agent SDK and claude -p usage on subscription plans draws from a new monthly Agent SDK credit, separate from interactive limits
- MCP connectors for Routines must be configured on claude.ai; local MCP servers (claude mcp add) do not appear in the connectors list
- GitHub-triggered routines require the Claude GitHub App installed separately (not just /web-setup)

## Sources

- https://code.claude.com/docs/en/scheduled-tasks — Official Claude Code docs: /loop, CronCreate/CronList/CronDelete, loop.md, jitter, expiry, disable flags
- https://code.claude.com/docs/en/routines — Official Claude Code docs: Cloud Routines, /schedule, triggers (schedule/API/GitHub), environments, connectors
- https://code.claude.com/docs/en/desktop-scheduled-tasks — Official Claude Code docs: Desktop Scheduled Tasks, SKILL.md storage, permissions, missed runs
- https://platform.claude.com/docs/en/build-with-claude/files — Official Anthropic Platform docs: Files API, file_id, limits, billing
- https://code.claude.com/docs/en/agent-sdk/overview — Official Claude Code docs: Agent SDK capabilities, tools, hooks, sessions
- https://code.claude.com/docs/en/agent-sdk/skills — Official Claude Code docs: Skills as filesystem artifacts, SKILL.md structure, settingSources
- https://support.claude.com/en/articles/9487310-what-are-artifacts-and-how-do-i-use-them — Official Anthropic help: claude.ai UI Artifacts feature

## Gaps

- Exact schema for mcp**scheduled-tasks**\* MCP tools (Desktop app) not publicly documented
- Cloud Routines /fire endpoint is "research preview" — request/response shapes may change
- Agent SDK credit monthly limits per plan tier not publicly documented at time of research
- Cloud Routines cannot be defined in project files — they are account-level only (confirmed gap: no project-level routines config)
