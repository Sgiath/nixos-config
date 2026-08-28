---
name: agent-session-evidence
description: Scan local Oh My Pi, Pi, OpenCode, oh-my-openagent/Oh My OpenAgents, and Grok conversations for places agents were confused, stuck, or corrected; connect follow-up fixes across sessions and harnesses; and save project-grouped evidence for a separate diagnostic agent. Use when the user wants to review local coding-agent history, collect agent friction, find corrections or stalled work, or prepare conversation evidence for later root-cause analysis.
compatibility: Requires local access to the harness data directories, Python 3 with sqlite3, and Git. Reads transcript stores without modifying them.
---

# Agent session evidence

Collect evidence of agent friction from local coding-agent sessions. Keep storage-specific complexity inside this skill and produce one stable handoff format for the separate diagnostic skill.

This skill finds and packages evidence. It does not decide why an agent failed, grade agents, recommend model or prompt changes, or repair the affected projects. Leave causal analysis to the downstream skill.

Read these before scanning:

- [storage-map.md](references/storage-map.md) for the source-verified harness stores and schemas.
- [handoff-format.md](references/handoff-format.md) for the incremental ledger and output contract.

Use [evidence_ledger.py](scripts/evidence_ledger.py) for ledger creation, pending-item selection, batch checkpoints, and run state. Do not duplicate its SQL in prompts or ad hoc scripts.

## Invocation and scope

Accept natural-language scope or these flag-like arguments:

- `--since <ISO date/time>`: include sessions whose activity overlaps the inclusive lower bound.
- `--until <ISO date/time>`: include sessions whose activity overlaps the inclusive upper bound.
- `--last <duration>`: shorthand such as `7d`, `24h`, or `2w`.
- `--project <name|path|remote>`: repeatable project filter. Match a canonical Git remote, repository path, repository name, or recorded project key.
- `--reprocess`: ignore prior successful ledger entries in scope, without deleting the ledger.
- `--output <directory>`: override the run output directory.

If the user gives no time range, scan every new or changed session that the ledger has not completed. If the user gives no project filter, include every project. Filters apply during metadata inventory, before transcript bodies are read. Do not mark sessions excluded by a filter as processed.

Resolve project filters against the metadata inventory. If a short name matches several repositories, include every match and list the resolved project keys in the run manifest rather than guessing one.

Defaults:

- State: `${XDG_STATE_HOME:-$HOME/.local/state}/agent-session-evidence/ledger.sqlite`
- Runs: `${XDG_STATE_HOME:-$HOME/.local/state}/agent-session-evidence/runs/<UTC-run-id>/`
- Detection schema version: `1`

Create state and run directories with mode `0700` and files with mode `0600`. These artifacts can contain private source, prompts, and tool output. Keep them local. Never upload them or post them to a tracker.

## Deterministic ledger helper

The helper is a bundled Python 3 CLI with its schema in `scripts/ledger_schema.sql`; it has no third-party dependencies. Run `python3 scripts/evidence_ledger.py --help` for the complete command interface.

1. Run `init` once for a new state database. Every command also applies safe schema initialization and migration.
2. Run `start-run --output-dir <run-dir> --filters-json '<json>'` before inventory processing. Keep the returned `run_id`.
3. Send metadata-only inventory records as JSONL to `pending --schema-version <version>`. Use `--input <path>` or standard input. The command emits only records that require work and adds `pending_reason`.
4. After a worker has durably written its batch files, send result records as JSONL to `checkpoint --run-id <id> --schema-version <version>`. The whole input batch validates before one transaction is committed. Records with `candidate` or `bundled` status must list `durable_paths` relative to the run output directory. Bundled source records must also list `case_ids`.
5. Run `finish-run` with final counts and coverage, then use `status` when a compact ledger summary is needed.

The JSONL record fields and status rules are in [handoff-format.md](references/handoff-format.md). Active sessions must be checkpointed as `partial`. Never call `checkpoint` before the referenced files exist.

## Workflow

### 1. Probe stores and versions

Probe all five harnesses even if one appears absent. Record executable version, resolved data root, schema variant, and availability in `manifest.json`.

Use the current installed source when a version or schema differs from [storage-map.md](references/storage-map.md). Do not guess a new schema from old field names. Missing harnesses are coverage notes, not fatal errors.

Open source stores read-only:

- Stream JSONL. Ignore only an invalid trailing record in a file that is still being written, and mark that session partial.
- Open SQLite with `mode=ro`, enable `PRAGMA query_only=ON`, and let SQLite read its WAL. Do not use `immutable=1` on a live WAL database.
- Never copy or back up the multi-gigabyte OpenCode database merely to query it.
- Never read credential stores such as `auth.json`, `credential`, or OMP secret keys.

### 2. Inventory metadata first

Build a lightweight inventory without loading transcript bodies into model context. Each inventory record needs:

- harness and storage version
- session ID and raw locator
- start, end, and last-modified times
- recorded cwd and extra workspace roots
- parent, fork, child, or subagent identifiers
- model/agent metadata when cheap to read
- source fingerprint
- active or partial status

For OpenCode, query session/project tables first and fetch message rows only for a selected batch. For OMP and Pi, read the title/header records before scanning remaining lines. For Grok, start with `summary.json`. Treat OpenCode and Grok search indexes, OMP `history.db`, and title indexes as accelerators only. Their absence never proves a transcript is absent.

Inventory nested OMP subagent JSONL files recursively. Do not confuse sibling `.log` artifacts with transcripts.

### 3. Canonicalize projects

Group by repository, not raw cwd. Worktrees and separate harnesses often record different paths for the same project.

Use this order:

1. Canonical Git remote URL, with credentials and a trailing `.git` removed.
2. Absolute `git rev-parse --git-common-dir` identity for worktrees without a remote.
3. Recorded repository root or harness project ID mapped back to its worktree.
4. Normalized absolute cwd for non-Git work.

A session can touch more than one repository. Assign each candidate problem thread to the repository containing the affected files. Put a genuinely cross-repository thread under `_cross-project` and link it from each project index.

Do not mix company contexts inside a worker or case. Process each canonical project independently. The top-level manifest may contain project names and counts, but one project's transcript content must not be passed to another project's worker.

### 4. Apply the incremental ledger

Use the ledger contract in [handoff-format.md](references/handoff-format.md). A session is pending when it is new, its fingerprint changed, its previous status is `partial` or `failed`, the detection schema version changed, or `--reprocess` applies.

Active sessions stay `partial` and must be reconsidered on the next run. Only record `no_signal`, `candidate`, or `bundled` after the batch result and its files are durable. Commit the ledger after every batch so interruption loses at most one batch.

For repository context, fingerprint relevant `.omo`, legacy `.sisyphus`, and referenced `.omp` files separately. Revisit linked cases when those files change even if the transcript did not.

### 5. Scan in bounded project batches

Never load all local history into one context. Use parallel subagents, with one canonical project per worker. A worker may receive sessions from several harnesses for that project because cross-harness linking is part of the task.

Default first-pass batch limit: 25 sessions or 16 MiB of decoded transcript text, whichever comes first. Reduce the batch when tool outputs are dense. Run at most eight workers concurrently. Pass file paths or local artifacts to workers instead of pasting transcript bodies into prompts.

The first pass is a candidate skim:

- user and assistant text
- tool names, status, error text, affected paths, commands, and test results
- branch, fork, compaction, reset, and subagent markers
- OMO plan/task identifiers and session links

Do not materialize large successful tool outputs during the skim. Fetch the full session and relevant externalized outputs only after a signal is found.

Each worker writes structured candidate records. The project coordinator links candidates only after every batch for that project has completed. It then materializes full evidence for linked sessions and updates the ledger.

### 6. Detect observable friction

A finding needs transcript evidence. Use these signal classes:

- `correction.explicit`: the user says the agent misunderstood, was wrong, violated a requirement, or must redo work.
- `correction.cross_session`: a later session, possibly in another harness, repairs, reverts, or replaces work from an earlier session on the same problem. This counts even when the user never explicitly says the first agent was wrong.
- `stuck.loop`: the agent repeats materially the same failed action, error, or abandoned approach without new information or state change.
- `stuck.unresolved`: the session ends after attempted work with a known failing check, unfinished requested behavior, or an explicit handoff caused by lack of progress.
- `confusion.requirement`: the agent acts against a stated requirement, repeatedly asks for information already present, or needs the user to restate the same constraint.
- `confusion.model`: the agent maintains contradictory accounts of the code or runtime and changes direction only after contradictory evidence or user correction.

Do not count a single handled tool error, an intentional red test in TDD, ordinary exploration, or a genuine user change of mind as friction.

Quote exact evidence and include enough surrounding turns to distinguish these cases. Record confidence in detection and linkage, but do not infer a cause.

### 7. Link work across sessions and harnesses

A shared project is necessary but insufficient. Link sessions into one case when at least one strong problem fingerprint agrees:

- the same ticket, plan, task, branch, commit, or explicit session reference
- overlapping changed files or symbols plus the same requested behavior
- the same distinctive error, failed test, command, or runtime symptom
- a later session that reverts or replaces edits from the earlier session
- an OMO boulder, plan, task, continuation marker, team run, or parent session that joins them

Use time proximity and semantic similarity only as supporting evidence. Never merge sessions merely because they occurred close together in the same repository.

Order the linked sessions chronologically. Treat a later harness that successfully fixes the same failing behavior as a cross-session correction. Preserve ambiguity when two problem threads could be related but the evidence is weak.

### 8. Add repository context

For every candidate project, inspect the source-verified OMO context paths in [storage-map.md](references/storage-map.md):

- `.omo/plans/*.md` and legacy `.sisyphus/plans/*.md`
- `.omo/boulder.json`
- `.omo/notepads/<plan>/`
- `.omo/run-continuation/<session>.json`
- `.omo/goal/`, `.omo/ulw-loop/`, team state/inboxes/tasks, and OpenCode task files when their IDs link to the case

Include relevant plan sections, checklist state, task descriptions, session IDs, learnings, decisions, and evidence. Preserve the repository-relative path, modification time, Git status, and content hash. Also include referenced project-local `.omp` artifacts when an OMP session depends on them.

Plans are context, not proof that work happened. Reconcile them with transcript tool activity and verification output.

### 9. Materialize the handoff bundle

Write the exact structure from [handoff-format.md](references/handoff-format.md). Group cases under canonical projects. Include a complete normalized transcript for every session used by a case, not every scanned session.

A case must contain:

- a neutral description of the task or problem
- signal classes and detection/linkage confidence
- all harness/session IDs and raw source locators
- chronological user, agent, and tool evidence
- the original requirement and every later correction
- relevant commands, failures, changed paths, diffs, commits, branches, and verification results
- linked OMO or project context
- what the later session changed or fixed
- unresolved ambiguity, missing records, compaction, truncation, or partial-session notes

Keep cause and remedy sections absent. The downstream skill should be able to read the bundle and decide why the friction occurred without reopening every harness store.

Redact credential values, bearer tokens, private keys, and secrets found incidentally in transcript content. Preserve the surrounding command/error shape, record that redaction occurred, and keep the raw source locator and hash. Do not copy binary attachments; record path, MIME type, size, and hash, and copy only text needed to understand the case.

### 10. Finish the run

Write final counts to the manifest: stores found, sessions inventoried, skipped unchanged, processed, partial, failed, candidates, cases, and projects. Include the exact time and project filters and every coverage gap.

Report the run directory and a short per-project case count. Do not provide causal analysis in chat.