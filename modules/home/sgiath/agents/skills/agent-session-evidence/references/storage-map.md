# Harness storage map

Verified against the locally installed builds and their source on 2026-08-28. Probe versions before every scan. If a schema has changed, inspect the matching installed source and update the run manifest instead of forcing old assumptions.

## Oh My Pi 18.0.9

Source package: `@oh-my-pi/pi-coding-agent`, repository `can1357/oh-my-pi`, primarily `packages/coding-agent/src/session/`. Installed source was recovered from the Nix derivation for `omp/18.0.9`.

Paths are resolved by `packages/utils/src/dirs.ts`:

- Default transcript root: `~/.omp/agent/sessions/`.
- `PI_CONFIG_DIR` changes `.omp`; `PI_CODING_AGENT_DIR` overrides the agent directory.
- `OMP_PROFILE` or `PI_PROFILE` selects `~/.omp/profiles/<name>/agent/`.
- After explicit XDG migration, data can be under `$XDG_DATA_HOME/omp/`; the `agent/` segment is flattened, so sessions become `$XDG_DATA_HOME/omp/sessions/`.

`session-paths.ts` maps a cwd below home to `-<home-relative-path>` and a cwd below the temporary directory to `-tmp-...`. Absolute external paths use legacy `--<encoded-absolute-path>--`. Include old legacy and short-lived hashed directories during inventory because the migration code can leave both during interrupted moves.

A main session is `<timestamp>_<uuidv7>.jsonl`. Scan recursively: child/subagent transcripts live inside the main session's sibling artifact directory as `<parent-session-dir>/<agentId>.jsonl`.

Physical JSONL layout from `session-entries.ts` and `session-manager.ts`:

1. A fixed 256-byte JSON `title` slot, updated in place.
2. A `session` header with version 3, `id`, `timestamp`, `cwd`, optional `additionalDirectories`, `parentSession`, `previousSessionFiles`, title fields, and provider cache key.
3. Tree entries with `id`, `parentId`, and timestamp. Types include `message`, `model_change`, `thinking_level_change`, `service_tier_change`, `compaction`, `branch_summary`, `reset_boundary`, `session_init`, `mode_change`, `credential_pin`, `ttsr_injection`, `custom`, `custom_message`, `label`, and `title_change`.

Follow `parentId` when reconstructing a branch. The file contains abandoned branches too. Compaction appends a summary and `firstKeptEntryId`; raw earlier entries normally remain. Full-file atomic rewrites occur for migration, relocation, repair, and maintenance, so fingerprints must notice changed files rather than assume append-only content.

Large strings can be truncated at 500,000 characters by `session-persistence.ts`. Images are externalized to the content-addressed blob store. Truncated tool output is kept under the sibling artifact directory as `<id>.<tool>.log` and referenced by `artifact://<id>`. Include relevant text artifacts and nested child JSONL files.

`~/.omp/agent/history.db` contains unique user prompts plus latest `cwd` and `session_id`, and `session_titles` contains titles. These are accelerators, not complete transcripts. `agent.db` is auth, settings, cache, and usage metadata only.

Primary source symbols:

- `session-entries.ts`: `SessionHeader`, `SessionEntry`, `CompactionEntry`, `SessionInitEntry`.
- `session-manager.ts`: `#lineFor`, `#fileBody`, `#appendToSessionFile`, `fork`, `forkFrom`, `createBranchedSession`.
- `session-paths.ts`: `getDefaultSessionDirName`, `computeDefaultSessionDir`, terminal breadcrumbs.
- `session-persistence.ts`: `prepareEntryForPersistence`.
- `artifacts.ts`: `ArtifactManager`.
- `history-storage.ts` and `title-index.ts`: prompt/title indexes.

## Pi 0.84.3

Installed package: `@earendil-works/pi-coding-agent` 0.84.3. Matching source: `earendil-works/pi` tag `v0.84.3`, `packages/coding-agent/src/core/session-manager.ts` and `src/config.ts`.

- Default: `~/.pi/agent/sessions/--<cwd-encoded>--/<timestamp>_<sessionId>.jsonl`.
- `PI_CODING_AGENT_DIR` overrides the agent directory.
- `PI_CODING_AGENT_SESSION_DIR` overrides session storage; `--session-dir` can override it again.
- `--session-file` can open a session outside its usual project directory. Trust the header cwd.

Line 1 is a version 3 `session` header with UUIDv7 `id`, timestamp, cwd, and optional absolute `parentSession`. Later lines are tree entries with an 8-hex `id`, `parentId`, and timestamp. Types include `message`, model/thinking changes, `compaction`, `branch_summary`, extension `custom` and `custom_message`, `label`, and `session_info`.

Messages retain user/assistant/tool-result roles, content blocks, tool call IDs, model/provider, usage, and message timestamps. Compaction changes model context but leaves raw entries on disk. Forks create a new file with `parentSession`; branches remain in the same tree. Most writes append, while migrations and selected branch operations rewrite the file.

Sibling directories named after a session hold attachments or exported artifacts, not another transcript unless a contained file itself has a valid session header.

## OpenCode 1.18.25+cb7d8b2

Installed source was recovered from the Nix derivation. Current core paths and schema are in:

- `packages/core/src/global.ts`
- `packages/core/src/database/database.ts`
- `packages/core/src/session/sql.ts`
- `packages/schema/src/session-message.ts`
- `packages/core/src/tool-output-store.ts`

Data root is XDG data plus `opencode`, normally `~/.local/share/opencode/`. The database path is:

- `OPENCODE_DB` when set. An absolute value is used directly; a relative value is below the data root.
- `opencode.db` for `latest`, `beta`, and `prod`, or when `OPENCODE_DISABLE_CHANNEL_DB` is true.
- `opencode-<channel>.db` for another installation channel.

Multiple databases can exist side by side (e.g. `opencode.db` plus `opencode-next.db` from another schema/channel generation). Probe each with `mode=ro` and enumerate tables dynamically; skip databases whose `session` table is empty, and record skipped ones in the run manifest. Do not assume the newest-named file is the live one.

The database uses WAL, normal synchronous mode, foreign keys, and a busy timeout. Open it read-only with WAL visibility.

Current core tables:

- `session`: `id`, `project_id`, `workspace_id`, `parent_id`, slug, directory/path, title, creating version, summary/diff metadata, model/agent, token/cost data, revert/permission data, created/updated/compaction/archive timestamps.
- `session_message`: ordered records keyed by session and unique `seq`. The JSON `data` plus table `type` reconstructs user, assistant, system, shell, synthetic, agent/model switch, and compaction messages.
- `message` and `part`: legacy transcript representation. `message.data` has message metadata; ordered `part.data` rows carry text, reasoning, tool calls/results, step markers, files, and snapshots.
- `todo`, `project`, `project_directory`, `worktree`, `workspace`, and snapshot/event tables add task and repository context.

The installed runtime database also contained `session_v2` from another schema/channel generation. Enumerate tables dynamically. When duplicate session IDs exist, retain every source row in the normalized record and choose the newest update only for inventory ordering.

`packages/schema/src/session-message.ts` defines tool states and content. Completed/error tool records can point at `outputPaths`. Large output is written to `$DATA/opencode/tool-output/tool_*` by `ToolOutputStore`; copy only files referenced by candidate records. Repository snapshots live under `$DATA/opencode/snapshot/` and can explain reverted or replaced changes.

Do not use the rebuildable OpenCode search/event projections as the sole transcript source. Do not inspect `auth.json`, `credential`, or authentication tables.

## oh-my-openagent 4.19.4

Active plugin package: `oh-my-openagent`, formerly `oh-my-opencode`; the user may also call it Oh My OpenAgents or OMO. Installed source is under OpenCode's package cache, with server behavior in `dist/index.js` and TUI behavior in `dist/tui.js`.

The plugin does not persist conversation bodies. Main, child, background, and compaction transcripts remain OpenCode sessions. Join them through OpenCode session IDs and `parent_id`.

Useful plugin and project context:

- `<project>/.omo/plans/*.md`; legacy `<project>/.sisyphus/plans/*.md`.
- `<project>/.omo/boulder.json`: active/multiple work, plan name/path, status, timestamps, `session_ids`, `session_origins`, agent, worktree, and per-task session data.
- `<project>/.omo/notepads/<plan>/`: plan learnings and decisions.
- `<project>/.omo/run-continuation/<sessionID>.json`: session ID, update time, and continuation source states.
- `<project>/.omo/goal/<sessionID>/` and `.omo/ulw-loop/<sessionID>/goals.json`.
- `$XDG_DATA_HOME/opencode/storage/oh-my-openagent/tui-state/<sha1(projectDir)[0:16]>.json`: six-second TUI projection only, useful for live state but not historical truth.
- `$XDG_CONFIG_HOME/opencode/tasks/<listId>/T-<uuid>.json`: task subject, description, status, dependency IDs, owner, parent, and `threadID` session link.
- Team base, default `~/.omo/`: `runtime/<teamRunId>/state.json`, member inboxes, numeric tasks, claims, worktrees, and team declarations. `leadSessionId` and member `sessionId` link back to OpenCode.
- Per-session marker stores: `$XDG_DATA_HOME/opencode/storage/directory-readme/` and `agent-usage-reminder/`.

The background task registry itself is memory-only. After a crash, spawned OpenCode sessions may survive without a plugin task record. Search OpenCode child sessions even when no background metadata remains.

Source anchors in the 4.19.4 bundle:

- `dist/index.js` around 88415: run-continuation markers.
- around 96318: `.omo`, boulder, plans, notepads, and legacy plans.
- around 107155: goal stores.
- around 133215: task schema and storage.
- around 138853: background child-session creation.
- around 16158: team runtime paths and state.
- `dist/tui.js` around 81622: project-hash TUI mirror.

## Grok Build 1.0.5

Installed CLI is xAI Grok Build. Source matched `xai-org/grok-build` commit `d6a22a1aed70b58d30a0f82a1a2a76ce1301631e` and the 1.0.5 changelog.

`GROK_HOME` overrides the default `~/.grok`. Sessions live at:

`$GROK_HOME/sessions/<url-encoded-cwd>/<session-id>/`

Long cwd names use a readable slug plus BLAKE3 suffix and a `.cwd` marker.

Important files:

- `summary.json`: session/project index. It includes `info.id/cwd`, parent/fork fields, session kind, source workspace/worktree, Git root/remotes/head, timestamps, model, agent, sandbox profile, and counts.
- `updates.jsonl`: authoritative append-only ACP `session/update` envelope stream. It contains user/agent chunks, tool call updates, rewind markers, and compaction checkpoints. Use this for evidence and replay.
- `chat_history.jsonl`: derived model-facing `ConversationItem` cache. It can be rewritten or pruned by compaction and rebuilt from `updates.jsonl`.
- `plan.json`, `signals.json`, `prompt_context.json`, `rewind_points.jsonl`, `feedback.jsonl`, `btw_history.jsonl`, `hunk_records.jsonl`, `prompts/`, `system_prompt.txt`, and compaction checkpoint/request directories.
- `subagents/` contains child metadata only. Child transcripts are normal top-level session directories whose summaries carry parent/session-kind fields.
- `$GROK_HOME/sessions/session_search.sqlite` is a rebuildable FTS cache of titles and concatenated user prompts. It is not the transcript source.

`updates.jsonl` timestamps are Unix seconds; summary times are RFC3339. Client-supplied session IDs are possible, so do not assume every ID is UUIDv7.

Primary source symbols:

- `xai-grok-home/src/lib.rs`: Grok home resolution.
- `xai-grok-config/src/paths.rs`: cwd encoding.
- `xai-grok-shell/src/session/persistence.rs`: summary schema.
- `xai-grok-shell/src/session/storage/jsonl/mod.rs`: authoritative update storage.
- `xai-grok-sampling-types/src/conversation.rs`: chat history items.
- `xai-grok-session-search/src/fts.rs`: rebuildable search index.