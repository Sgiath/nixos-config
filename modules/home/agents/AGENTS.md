# Working with Sgiath

## Preferences

- Prefer boring, direct code and deletion over speculative abstractions or dependencies. For internal API replacements, migrate callers and remove the old path rather than keeping a compatibility layer; preserve required external compatibility.
- Avoid stopgaps meant to be replaced. If a deliberate simplification has a known ceiling, leave a `FIXME:` naming the limitation and what would justify changing it.
- Keep implementation modules around 500 lines or less when a cohesive split exists; test files may be longer.
- Prefer test-first development for bug fixes and new behavior. Keep tests that defend observable contracts, not tests that mirror the implementation or merely prove work was done.
- Long-running jobs should expose start, useful progress, completion, and diagnosable failures without noisy routine logging.

## Completion and permissions

Continue through the requested implementation and relevant local verification, fixing failures caused by your changes. A first pass is not a review checkpoint unless I asked for one. Stop at the requested outcome rather than adding adjacent features.

Local edits and non-production checks within the task do not need repeated approval. Ask when a consequential product choice cannot be resolved from context, or when the next step needs access or authorization you do not have. Production changes, publishing, and destructive operations need task-specific authorization.

Use Worktrunk (`wt`) to create and remove worktrees. Respect an explicit request to work in the main worktree.

## Pull and merge requests

- Attach review comments to a relevant line or range, or reply to an existing thread; no floating general review comments.
- Assign the authenticated user when creating a PR or MR.

## Work contexts

Never mix contexts: don't read one company's tools from another's repo.

| Context | Repos | Tracker (MCP) | Ticket ids | Docs (MCP) | Forge |
|---|---|---|---|---|---|
| **Personal** | `~/develop/sgiath/*`, `~/nixos`, anything else | Linear (`linear`) | `SGI-123` | — | GitHub |
| **CrazyEgg** | `~/develop/crazyegg/*` | Shortcut (`shortcut`) | `sc-12345`, Shortcut URL, "story" | Notion (`notion-crazyegg`) | GitHub |
| **Remote** | `~/develop/remote/*` | Linear (`linear-remote`) | any Linear id that is **not** `SGI-` | Notion (`notion-remote`) | GitLab |

### Read vs write

- **Write only personal Linear (`linear`).** Company trackers and docs are read-only unless I explicitly permit a write for this task.
- Company trackers/docs are input. Agent progress lives in personal Linear. A personal issue derived from a company ticket must link that URL; personal-only issues are fine.
- You may post to `slack-crazyegg` and reply to threads when needed for the task or asked. Read the channel or thread context first; keep messages short and direct.

### Resolving "ticket"

Explicit ids and URLs win: `sc-XXXXX` or Shortcut URL → Shortcut; `SGI-###` → personal Linear; any other `ABC-###` → Remote Linear. Otherwise use the repo context above: company work uses its tracker; agent breakdown uses personal Linear. Ask only if that still leaves the context ambiguous.
