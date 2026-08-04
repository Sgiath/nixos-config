## ASD-STE100 Simplified Technical English

Always respond using ASD-STE100 Simplified Technical English. It is a controlled writing standard. Aerospace and defense groups made it. It helps people write clear technical text.

Key rules:
- **Use approved words only.** The standard gives a word list. Each word has one meaning.
- **Use one word for one idea.** Do not use two words for the same thing.
- **Write short sentences.** Use 20 words or less for instructions.
- **Use active voice.** Write "Turn the switch", not "The switch must be turned".
- **Write short paragraphs.** Keep one topic in each paragraph.

The goal is easy reading. Many readers are not native English speakers. Clear text helps them do the work in a safe and correct way.

## Writing code

- Keep implementation files under ~500 lines of code; split/refactor as needed. The test files can be much longer, do not concern yourself with their length at all
- Choose the simplest implementation that fully meets the current requirements. Avoid speculative abstractions, configuration, and indirection. If a problem can be solved in a simpler way, propose it.
- Grow the system in layers. Start from the smallest version that works end-to-end, and add each new capability on top of a product that already works. Never trade a working product for unfinished complexity.
- Keep components and modules modular and concerns clearly separated.
- Make architectural decisions for the long term. Do not accept a stopgap that only works for now and is meant to be replaced later.
- When implementing bug fix or new functionality, prefer using test-driven development approach

## Writing tests

Test externally observable behavior, public APIs, contracts, regressions, and meaningful invariants. Avoid tests coupled to private helpers or mirroring the current implementation structure unless that internal behavior is independently consequential.

## Debug Logging

Features must log errors, unexpected exceptions, and operational issues with enough context to debug failures. Long-running jobs must also log start, progress checkpoints, and completion so a stuck run can be diagnosed from logs. In general everything should have enough logs so we can use them to debug if anything goes unexpected.

## Work contexts

The user works for multiple companies plus his own personal work. Each context has its own
tracker, docs, and forge. **Never mix contexts**: don't read one company's tools while working
in another's repo, and never write into a company tool.

| Context | Repos | Tracker (MCP) | Ticket ids | Docs (MCP) | Forge |
| --- | --- | --- | --- | --- | --- |
| **Personal** | `~/develop/sgiath/*`, `~/nixos`, anything else | Linear (`linear`) | `SGI-123` | — | GitHub |
| **CrazyEgg** | `~/develop/crazyegg/*` | Shortcut (`shortcut`) | `sc-12345`, Shortcut URL, "story" | Notion (`notion-crazyegg`) | GitHub |
| **Remote** | `~/develop/remote/*` | Linear (`linear-remote`) | any Linear id that is **not** `SGI-` | Notion (`notion-remote`) | GitLab |

To add a new client later: add a row here (repo root, tracker MCP, id pattern, docs MCP, forge) and
nothing else in this file should need to change.

### Read vs write

- **Personal Linear (`linear`) is the only tracker you may write to.** Create/update issues,
  comments, and relations freely. This is the **work surface**: granular tickets, blocking edges,
  agent progress. When a skill says "issue tracker" or "publish tickets", it means personal Linear
  (or the repo's own configured tracker) — never a company tracker.
- **All company tools are read-only** (`shortcut`, `linear-remote`, `notion-crazyegg`,
  `notion-remote`): pull context freely, but never create/update issues, post comments, or edit
  pages without explicit per-task permission from the user. Writes appear under the user's name.
- Company trackers/docs are **input**: they group human-facing context and resources for a task,
  not granular progress. The granular breakdown lives in personal Linear.
- Personal Linear issues derived from a company ticket must link back to that ticket's URL.
  Personal tickets with no company counterpart are normal too.

### Disambiguating "ticket"

1. Explicit id/URL wins: `sc-XXXXX`/`#XXXXX` → Shortcut; `SGI-###` → personal Linear;
   any other `ABC-###` Linear id → Remote Linear.
2. No id → infer from cwd via the repo column above.
3. Bare "ticket" while discussing company work → that company's tracker; while breaking down or
   tracking agent work → personal Linear.
4. Still ambiguous → ask. Never guess across companies.
