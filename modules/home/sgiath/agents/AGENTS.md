# Engineering guidelines

## Understand before changing

Read the task and trace the affected code path end to end before editing. For bug fixes, treat the report as a symptom: inspect every caller of the code you plan to change and fix the root cause at the shared boundary when possible.

Do not confuse a small diff with a good diff. The smallest change in the wrong place is another bug.

## Prefer the simplest complete solution

Work through this order and stop at the first option that fully meets the current requirement:

1. Do not build it if it is unnecessary or speculative.
2. Reuse an existing helper, utility, type, or pattern from the codebase.
3. Use the standard library.
4. Use a native platform feature.
5. Use an already-installed dependency.
6. Use a direct, small implementation.
7. Add new structure or dependencies only when the simpler options do not hold.

Choose the simplest implementation that fully meets the current requirement. Prefer deletion over addition, boring code over clever code, and fewer files over unnecessary indirection. Do not add speculative abstractions, configuration, extension points, factories, interfaces with one implementation, or boilerplate for hypothetical future needs. Propose the simpler path when you see one.

When two approaches are equally small, choose the one that handles edge cases correctly. Question complexity when a smaller solution covers the requirement, but do not simplify away anything the user explicitly requested. Propose bold ideas when they would meaningfully improve the product or architecture.

## Design and implementation

- Ship the smallest end-to-end version first, then layer capabilities onto a working product. Never trade a working product for unfinished complexity.
- Keep modules cohesive and concerns clearly separated. Split or refactor implementation files that grow beyond roughly 500 lines; test files may be longer.
- Treat architecture as a long-term decision. Do not introduce a stopgap that is already meant to be replaced later.
- A deliberate simplification may have a known ceiling. Mark it with a `FIXME:` comment that names the limitation and the condition or upgrade path that would justify changing it.
- Avoid new dependencies when the codebase, standard library, or platform already provides a sufficient solution.
- Comment usage and reasoning, not every line. Prefer a brief note above the function or the language's module/API documentation, such as `@moduledoc` or `@doc`. Update comments whenever the code changes.

Never be "lazy" about understanding the problem, validation at trust boundaries, error handling that prevents data loss, security, accessibility, or explicitly requested behavior. Real hardware also needs calibration controls because clocks drift and sensors vary.

## Testing

Use test-driven development for bug fixes and new functionality.

Tests defend externally observable behavior, public APIs, contracts, and meaningful invariants. Avoid tests coupled to private helpers, endless smoke tests, tests that merely mirror the implementation, and "regression" tests for features that have been deleted.

Every non-trivial change should leave behind the smallest runnable check that would fail if the behavior broke. Use one focused test or self-check when that is sufficient; add broader coverage only when the behavior or risk warrants it. Trivial one-line changes do not require ceremonial tests.

## Debug logging

Always log errors, unexpected exceptions, and operational failures with enough context to diagnose them. Long-running jobs must log their start, useful progress checkpoints, and completion so stalled work can be identified. Keep routine logging proportional and actionable rather than noisy.

## Pull and merge requests

- Attach PR/MR review comments to a relevant line or range, or reply to an existing comment. Never leave floating general review comments.
- When creating a PR or MR, always assign the authenticated user through `gh`, `glab`, or the relevant MCP integration.

## Work contexts

Never mix contexts: don't read one company's tools from another's repo.

| Context | Repos | Tracker (MCP) | Ticket ids | Docs (MCP) | Forge |
|---|---|---|---|---|---|
| **Personal** | `~/develop/sgiath/*`, `~/nixos`, anything else | Linear (`linear`) | `SGI-123` | — | GitHub |
| **CrazyEgg** | `~/develop/crazyegg/*` | Shortcut (`shortcut`) | `sc-12345`, Shortcut URL, "story" | Notion (`notion-crazyegg`) | GitHub |
| **Remote** | `~/develop/remote/*` | Linear (`linear-remote`) | any Linear id that is **not** `SGI-` | Notion (`notion-remote`) | GitLab |

### Read vs write

- **Write only personal Linear (`linear`).** Company tools (`shortcut`, `linear-remote`, `notion-crazyegg`, `notion-remote`) are read-only unless the user explicitly permits a write for this task.
- Company trackers/docs are input. Agent progress lives in personal Linear. A personal issue derived from a company ticket must link that URL; personal-only issues are fine.
- you can post to `slack-crazyegg` and reply to threads if needed or asked. The messages should be direct, short and to the point, using the `humanizer` skill, to avoid all AI-like writing traps. Consider each message in context of previous meassages in the channel or threat

### Disambiguating "ticket"

1. Explicit id/URL wins: `sc-XXXXX` / Shortcut URL → Shortcut; `SGI-###` → personal Linear; any other `ABC-###` → Remote Linear.
2. No id → infer from cwd via the table.
3. Bare "ticket": company work → that company's tracker; agent breakdown → personal Linear.
4. Still ambiguous → ask. Never guess across companies.
