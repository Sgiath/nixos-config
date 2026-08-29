# Handoff and ledger format

This is the interface between the evidence collector and `agent-session-diagnostics`. Keep it stable. Add fields without renaming or removing existing fields; bump `schema_version` for an incompatible change.

## Incremental ledger

Default path:

`$XDG_STATE_HOME/agent-session-evidence/ledger.sqlite`

When `XDG_STATE_HOME` is unset, use `~/.local/state/agent-session-evidence/ledger.sqlite`.

Set `PRAGMA journal_mode=WAL`, `PRAGMA synchronous=NORMAL`, `PRAGMA foreign_keys=ON`, and a busy timeout. Keep the database and its parent directory private.

Minimum schema:

```sql
CREATE TABLE IF NOT EXISTS meta (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS runs (
  run_id TEXT PRIMARY KEY,
  started_at TEXT NOT NULL,
  finished_at TEXT,
  schema_version INTEGER NOT NULL,
  filters_json TEXT NOT NULL,
  output_dir TEXT NOT NULL,
  status TEXT NOT NULL,
  counts_json TEXT,
  coverage_json TEXT
);

CREATE TABLE IF NOT EXISTS source_items (
  harness TEXT NOT NULL,
  session_id TEXT NOT NULL,
  raw_locator TEXT NOT NULL,
  fingerprint TEXT NOT NULL,
  project_key TEXT,
  started_at TEXT,
  ended_at TEXT,
  active INTEGER NOT NULL DEFAULT 0,
  status TEXT NOT NULL,
  schema_version INTEGER NOT NULL,
  processed_at TEXT,
  last_run_id TEXT,
  case_ids_json TEXT,
  error TEXT,
  PRIMARY KEY (harness, session_id, raw_locator)
);

CREATE INDEX IF NOT EXISTS source_items_project_time
  ON source_items(project_key, started_at, ended_at);

CREATE TABLE IF NOT EXISTS context_files (
  project_key TEXT NOT NULL,
  path TEXT NOT NULL,
  fingerprint TEXT NOT NULL,
  status TEXT NOT NULL,
  schema_version INTEGER NOT NULL DEFAULT 1,
  processed_at TEXT,
  last_run_id TEXT,
  linked_session_ids_json TEXT,
  error TEXT,
  PRIMARY KEY (project_key, path)
);
```

Allowed `source_items.status` values:

- `no_signal`: completed scan with no qualifying evidence.
- `candidate`: qualifying signal found; bundle materialization is pending.
- `bundled`: qualifying evidence is durable in one or more case bundles.
- `partial`: source was active, had a torn trailing record, or could not yet be read completely.
- `failed`: processing failed and must be retried.

Pending rules:

- No ledger row exists.
- The current fingerprint differs.
- Status is `partial`, `failed`, or `candidate` without a durable case.
- The run's detection schema version differs.
- `--reprocess` includes the item.

A filtered-out item gets no ledger update. An active item is always `partial`, even if a candidate was found, so later appended turns are scanned. Write the bundle first, then commit `bundled` in the same batch checkpoint. Do not use in-memory success as a checkpoint.

### Ledger helper JSONL

Run `python3 scripts/evidence_ledger.py --help` from the skill root. The CLI reads one JSON object per line from standard input unless `--input <path>` is given. It writes JSONL to standard output and errors to standard error.

Inventory records passed to `pending` use one of these shapes:

```json
{"kind":"source_item","harness":"omp","session_id":"...","raw_locator":"/absolute/source","fingerprint":"...","project_key":"...","started_at":null,"ended_at":null,"active":false}
{"kind":"context_file","project_key":"...","path":".omo/plans/work.md","fingerprint":"..."}
```

The command emits only pending records and adds `pending_reason`: `new`, `active`, `fingerprint_changed`, `partial`, `failed`, `candidate`, `schema_changed`, or `reprocess`.

Checkpoint records keep their inventory fields and add `status`. They may also include `error`, `case_ids`, or `linked_session_ids` as appropriate. A `candidate` or `bundled` record must include `durable_paths`, an array of files relative to the run output directory. The CLI rejects missing files, absolute paths, and paths that escape the run directory. A bundled source item must include at least one case ID.

`checkpoint` reads and validates the complete JSONL input before opening its transaction. A malformed line or invalid record leaves the whole batch uncommitted.

Typical flow is two checkpoint passes: after each batch, commit scanned sessions as `no_signal`/`candidate`/`partial`; after cases are materialized, commit a second pass that upgrades case sessions to `bundled` with `case_ids` and re-checkpoints active sessions back to `partial`. A session materialized into a case beyond its original batch (e.g. a parent session pulled in by linking) gets its first checkpoint in that second pass.

`context_file` checkpoint records follow the same rules as source items: they require `status` and, for `bundled`, `durable_paths` pointing at the copied file under the run output directory.

### Fingerprints

Fingerprints must be cheap during inventory and sensitive to appended or rewritten data:

- OMP/Pi JSONL: session ID, file device/inode when available, byte size, nanosecond mtime, and a hash of the first and last complete records. Include child JSONL and referenced artifact fingerprints separately.
- OpenCode: database identity plus session ID, session update time, message count/max sequence/max update time, part count/max update time for legacy rows, and the creating version/schema table. Do not hash the whole database.
- Grok: session ID plus size/mtime/hash tuple for `summary.json` and `updates.jsonl`; include the last complete update envelope. Track mutable context files separately.
- OMO and repository context: canonical path, size, nanosecond mtime, and SHA-256 content hash for text files.

The run manifest records the exact fingerprint algorithm. If the algorithm changes, bump the detection schema version.

## Run bundle

Directory layout:

```text
<run>/
  manifest.json
  projects/
    <project-slug>/
      index.md
      candidates.jsonl
      cases/
        <case-id>.md
      transcripts/
        <harness>_<session-id>.jsonl
      context/
        <repository-relative files>
```

`project-slug` is readable and collision-safe: sanitized repository name plus the first 12 hex characters of SHA-256 over the canonical project key.

### manifest.json

Required fields:

```json
{
  "schema_version": 1,
  "run_id": "UTC timestamp plus random suffix",
  "started_at": "RFC3339",
  "finished_at": "RFC3339 or null",
  "filters": {
    "since": null,
    "until": null,
    "last": null,
    "projects": [],
    "reprocess": false
  },
  "detection_schema_version": 1,
  "state_db": "absolute path",
  "stores": [],
  "resolved_projects": [],
  "counts": {
    "inventoried": 0,
    "skipped_unchanged": 0,
    "processed": 0,
    "partial": 0,
    "failed": 0,
    "candidates": 0,
    "cases": 0
  },
  "coverage_gaps": [],
  "redactions": []
}
```

Each store entry records harness, executable version, data root, schema variant, source version/commit when known, and availability. Each project entry records canonical key, display name, remotes, repository/worktree paths, context classification, output path, and counts.

### candidates.jsonl

One JSON object per observed signal before cross-session merging:

```json
{
  "candidate_id": "cand_<stable hash>",
  "project_key": "canonical project identity",
  "harness": "omp|pi|opencode|omo|grok",
  "session_id": "source session id",
  "signal": "correction.explicit",
  "confidence": "high|medium|low",
  "timestamp": "RFC3339",
  "summary": "neutral observable description",
  "evidence_refs": [],
  "problem_fingerprints": {
    "tickets": [],
    "plans": [],
    "branches": [],
    "commits": [],
    "paths": [],
    "symbols": [],
    "commands": [],
    "errors": [],
    "tests": []
  },
  "possible_links": [],
  "batch_id": "project-local batch id"
}
```

The summary states what happened, not why.

### Normalized transcripts

Write a complete normalized JSONL transcript for each session included in a case. Preserve every available branch/event record, not only the active model context. One line per normalized record:

```json
{
  "schema_version": 1,
  "harness": "omp",
  "session_id": "...",
  "source": {
    "locator": "absolute DB/file locator",
    "record_id": "source row/entry/update id",
    "sequence": 0,
    "raw_type": "message",
    "fingerprint": "..."
  },
  "project_key": "...",
  "timestamp": "RFC3339 or null",
  "role": "system|developer|user|assistant|tool|event|metadata",
  "kind": "text|reasoning|tool_call|tool_result|compaction|branch|fork|reset|session|other",
  "content": "text or null",
  "data": {},
  "links": {
    "parent_record_id": null,
    "parent_session_id": null,
    "tool_call_id": null,
    "child_session_id": null
  },
  "redactions": []
}
```

`data` keeps source fields that do not fit the normalized columns. Preserve enough raw structure to reconstruct ordering, branches, tool states, model/agent selection, usage, compaction, and source-specific relationships. Do not flatten multiple content blocks into an order that did not exist.

For OpenCode external `outputPaths`, OMP `artifact://`, or Grok sidecars, add metadata records with path, MIME type, byte size, SHA-256, copied destination when included, and any source retention warning.

### Case markdown

Each `cases/<case-id>.md` is an evidence handoff with this exact section order:

```markdown
---
schema_version: 1
case_id: case_...
project_key: ...
signals: [...]
detection_confidence: high|medium|low
linkage_confidence: high|medium|low
sessions: [...]
started_at: ...
ended_at: ...
status: evidence-only
---

# <neutral task/problem description>

## Scope
## Session chain
## Original requirement
## Observable friction
## Corrections and later work
## Commands, changes, and verification
## Repository and OMO context
## Missing or ambiguous evidence
## Source map
```

Rules for case content:

- `Session chain` is chronological and names harness, session ID, agent/model when known, cwd/worktree, start/end time, parent/fork relationship, and what joins it to the case.
- `Observable friction` quotes exact user/assistant/tool evidence with normalized transcript record IDs and raw locators.
- `Corrections and later work` includes explicit corrections and implicit cross-session repairs. State exactly what the later session changed, reverted, or got passing.
- `Commands, changes, and verification` separates attempted, failed, and successful results.
- `Repository and OMO context` copies relevant plan/task/boulder/notepad/continuation/team facts with paths and hashes. A plan checkbox is not proof of execution.
- `Missing or ambiguous evidence` records compacted, truncated, pruned, active, corrupt, unavailable, weakly linked, and redacted data.
- `Source map` lists every original path/table/row and copied transcript/context file.

Do not add root-cause, blame, recommendations, or remediation sections.

### Project index

`index.md` contains:

- canonical project identity and all known worktree/clone paths
- applied time/project filters
- sessions inventoried, skipped, processed, partial, and failed by harness
- a chronological case table with signals, sessions, and confidence
- unmerged low-confidence candidates
- context files included
- coverage gaps

The index links to cases and normalized transcript files. It does not summarize causes.

## Redaction

Redact only secret values, not commands or errors around them. Use stable placeholders such as `[REDACTED:bearer-token:sha256-12]` so repeated appearances remain correlatable without revealing the value.

Never open or copy dedicated credential stores. If a transcript embeds a credential incidentally:

1. Replace the value in normalized and Markdown output.
2. Record type, count, stable hash prefix, and source locator in `manifest.redactions`.
3. Preserve the source record hash so a trusted local diagnostic agent can verify provenance without the bundle containing the secret.

Binary files stay outside the bundle unless the user explicitly asks to include them. Record their metadata and source locator.