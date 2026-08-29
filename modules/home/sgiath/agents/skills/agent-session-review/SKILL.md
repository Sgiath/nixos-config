---
name: agent-session-review
description: Turn a completed agent-session-diagnostics run into a private local HTML review page, copy an agent-ready fix prompt for each finding, and mark findings plus fully handled evidence cases fixed. Use after agent-session-diagnostics when the user wants to review findings, work through proposed remedies, or keep resolved evidence out of later diagnostic runs.
compatibility: Requires a completed local agent-session-diagnostics run, Python 3, and a browser reachable from the local machine.
---

# Agent session review

Present diagnostic findings for human review. This skill does not implement remedies. It provides the exact finding path in a short prompt, then records what the user has handled.

Use [review_report.py](scripts/review_report.py) for run selection, validation, HTML generation, the local server, and status changes. Do not hand-edit review state or finding frontmatter.

## Defaults

- Diagnostic runs: `${XDG_STATE_HOME:-$HOME/.local/state}/agent-session-diagnostics/runs/`
- Review state: `${XDG_STATE_HOME:-$HOME/.local/state}/agent-session-review/state.json`
- Generated reports: `${XDG_STATE_HOME:-$HOME/.local/state}/agent-session-review/reports/<diagnostic-run-id>/index.html`
- Server: an available port on `127.0.0.1`

The helper selects the newest completed diagnostic run when no run is supplied. It rejects unfinished runs, malformed findings, duplicate finding IDs, and findings that cite evidence outside the run inventory.

All inputs and outputs are private. Keep directories mode `0700` and files mode `0600`. Never publish a report, use `share-html-report`, add analytics, or send its contents to a tracker. Findings can contain company source, prompts, tool output, local paths, and private messages.

## Invocation

Accept a natural-language request or these flag-like arguments:

- `--diagnostic-run <directory>`: completed diagnostic run to review.
- `--port <number>`: loopback port. Use `0` when the caller can read the emitted URL.
- `--output <path>`: optional HTML snapshot path.

## Workflow

### 1. Start the private review server

From this skill directory, launch the helper through the harness process manager so it remains available while the user reviews the page:

```bash
python3 scripts/review_report.py serve \
  [--diagnostic-run <directory>] \
  [--port 0] \
  [--output <path>]
```

Do not run the server as an unmanaged foreground shell command. Do not bind it to a non-loopback address. The first stdout line is JSON containing `url`, `report_path`, `run_dir`, and `findings`. Operational errors go to stderr with the affected finding ID.

If a managed process API requires a readiness pattern, wait for the JSON line containing `"url"`. Use a stable process name scoped to the session, such as `agent-session-review`.

### 2. Open and verify the page

Open the emitted loopback URL in the local browser. Confirm that:

- the finding count matches the completed diagnostic manifest
- projects are separate, with `_cross-project` first when present
- findings within a project are grouped by remedy target
- search and remedy-target filters change the visible count
- opening a finding shows its complete Markdown, evidence case IDs, and absolute source path

The page is dependency-free and self-contained. It uses no remote CSS, fonts, scripts, images, or analytics.

### 3. Review findings

Each finding has two actions:

- `Copy fix prompt` copies exactly `Fix this issue /absolute/path/to/finding.md`.
- `Mark fixed` writes durable review state through the loopback server.

The prompt stays intentionally short. The finding file already contains the diagnosis, evidence, recommended remedy, placement rationale, and verification plan an implementation agent needs.

Marking a finding fixed does not modify the immutable diagnostic finding or evidence bundle. It records the stable finding ID, finding hash, run, evidence case IDs, and timestamp in the review state file.

An evidence case becomes fixed only after every finding in the reviewed run that cites it is fixed. This prevents one completed remedy from hiding a second independent remedy based on the same case. The page reports when shared evidence still has open findings.

### 4. Hand off fixes

When the user wants to implement a remedy, use the copied prompt in a new agent session or task. The implementation agent must read the named finding and follow the applicable project context. Do not combine unrelated finding fixes unless the user asks.

This review skill records status only. It never claims that a proposed remedy worked merely because the user marked the finding fixed.

### 5. Finish

Leave the managed server running while the user is actively reviewing. Stop it when the review is done or the session ends. Report the local URL, report snapshot path, diagnostic run path, total findings, and fixed count.

## Read-only snapshot

For a report that does not need status actions:

```bash
python3 scripts/review_report.py generate \
  [--diagnostic-run <directory>] \
  [--output <path>]
```

The generated page keeps `Mark fixed` disabled and explains that the local server is required. `Copy fix prompt`, search, filters, responsive layout, dark mode, and print styling still work.

## Resolution contract

`agent-session-diagnostics prepare` reads the review state by default and excludes evidence cases with `status: fixed`. Use its `--include-fixed` option only when the user explicitly wants to reassess handled evidence.

The evidence collector still revisits a source transcript when its fingerprint changes. A changed transcript can contain a new problem even when an older case from that session was fixed. Case IDs for the same problem thread must remain stable across evidence runs so the fixed-case marker continues to apply.

The review state is external mutable state. Diagnostic runs and evidence bundles remain immutable, reproducible inputs. Finding status must stay `proposed` in diagnostic frontmatter because the diagnostic validator owns that schema.
