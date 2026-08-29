---
name: research
description: Investigate a question against high-trust primary sources and capture the findings as a Markdown file in the repo. Use when the user wants a topic researched, docs or API facts gathered, or reading legwork delegated to a background agent.
---

Launch parallel research subagents to build a grounded answer to the current question or decision.

Use fresh context, not forked context, unless I explicitly ask for forked context. Researchers and scouts should inspect sources directly instead of relying on the main conversation history.

Use a combination of `librarian` and `scout` subagents:
- Use `librarian` for web, docs, standards, ecosystem, recent changes, benchmarks, and primary-source evidence.
- Use `scout` for local codebase context, existing implementation patterns, repo constraints, and files that would be affected.

1. Investigate the question against **primary sources** — official docs, source code, specs, first-party APIs and academic papers — not a secondary write-up of them. Follow every claim back to the source that owns it.
2. *Practical tradeoffs* - at least one subagent should also compare options, risks, edge cases, maintenance cost, and what would be easiest to validate.

Adapt the angles when the question calls for it:
- Library/API questions: include official docs and recent examples.
- Architecture decisions: include local module boundaries, dependency direction, and migration cost.
- Debugging questions: include likely failure modes, local call paths, and exact error evidence.
- UI/product questions: include user flow, accessibility, design precedent, and implementation constraints.
- Time-sensitive topics: include a recent-developments angle and prefer 2026/2025 sources.

## Result

Write the findings to a single Markdown file, citing each claim's source. Save it where the repo already keeps such notes; match the existing convention, and if there is none, put it in `.agents/research/`
