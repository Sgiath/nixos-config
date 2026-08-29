---
name: agent-session-diagnostics
description: Diagnose evidence-only cases produced by agent-session-evidence, identify preventable root causes, decide whether remedies belong in project setup, project or global AGENTS.md, a workflow skill, the agent harness, or system configuration, and write one private Markdown file per finding. Use after collecting problematic coding-agent traces or when asked how to prevent repeated agent confusion, corrections, or stalled work.
compatibility: Requires a completed local agent-session-evidence run, Python 3, and read access to affected local projects and applicable agent configuration.
---

# Agent session diagnostics

Turn collected friction evidence into grounded preventive recommendations. Diagnose causes and placement; do not implement remedies unless the user separately asks.

Read [finding-format.md](references/finding-format.md) before writing findings. Use [diagnostic_run.py](scripts/diagnostic_run.py) to select the evidence run, create private output directories, derive stable IDs, enforce case coverage, and generate indexes.

The upstream `agent-session-evidence` bundle is immutable input. Never add diagnosis to its case files or reopen raw harness stores unless a required record is missing from the bundle and the case source map identifies it.

## Invocation and defaults

Accept a natural-language request or these flag-like arguments:

- `--evidence-run <directory>`: completed evidence run to diagnose.
- `--project <name|slug|path|remote>`: repeatable project filter.
- `--case <case-id>`: repeatable case filter.
- `--output <directory>`: diagnostic run directory.
- `--include-fixed`: reassess evidence cases already marked fixed by `agent-session-review`.
- `--review-state <file>`: override the review state used for fixed-case filtering.

Without an explicit evidence run, use the latest finished run containing cases. Without project or case filters, assess every unresolved case. The helper excludes evidence cases marked fixed by `agent-session-review`; use `--include-fixed` only when the user explicitly wants to reassess them. Filters narrow analysis, but every selected case must still be covered by a finding. Record filters in the diagnostic manifest when invoking the helper through an orchestrator.

Defaults:

- Evidence runs: `${XDG_STATE_HOME:-$HOME/.local/state}/agent-session-evidence/runs/`
- Diagnostic runs: `${XDG_STATE_HOME:-$HOME/.local/state}/agent-session-diagnostics/runs/<UTC-run-id>/`
- Review state: `${XDG_STATE_HOME:-$HOME/.local/state}/agent-session-review/state.json`

Artifacts can contain private company and personal context. Keep directories mode `0700` and files mode `0600`. Never upload findings or post them to a tracker.

## Workflow

### 1. Prepare the run

From this skill directory, run:

```bash
python3 scripts/diagnostic_run.py prepare [--evidence-run <dir>] [--output-dir <dir>] [--project <filter>]... [--case <case-id>]... [--include-fixed]
```

Pass project and case filters to `prepare`; coverage is computed from its selected unresolved inventory, not from later worker prompts. The manifest records how many fixed cases were skipped. Use the returned run directory and read `case-inventory.jsonl` plus the upstream manifest before dispatching analysis. Reject unfinished evidence runs, unsupported schemas, missing cases, invalid review state, or per-project manifest/file mismatches rather than guessing. If only an older manifest's aggregate case count is stale while every per-project count matches durable files, keep all files and record the helper's `input_warnings`; current collector finalization validates both its supplied counts and bundle manifest against durable case files.

### 2. Partition by project and dispatch immediately

Analyze one canonical project per worker so company contexts never mix. Give each worker every selected case for that project, its project index, and the actual repository paths recorded by the upstream manifest.

Dispatch every ready project worker concurrently, up to the harness subagent cap. Do not serialize projects into arbitrary waves. A project worker may analyze its cases together to merge duplicate causes and notice repeated project-specific failures.

Workers are read-only. They must not edit the affected project, AGENTS.md, skills, harness, system configuration, trackers, or documentation. They write only collision-safe candidate reports or return structured findings to the coordinator. Skip formatters, linters, and project test suites during diagnosis.

### 3. Establish current governing context

For each project, inspect only context relevant to the cases:

1. The case Markdown first.
2. Bundled transcripts and copied context only when the case leaves a causal question unresolved.
3. Current project code, config, commands, CI, development environment, and documentation implicated by the case.
4. The applicable project, parent, and global `AGENTS.md` or equivalent agent instructions.
5. The invoked skill when the failure occurred inside a skill workflow.
6. Harness or system configuration only when evidence points to a shared tool, scheduling, persistence, service, or environment mechanism.

Record current paths and note when current state postdates the evidence. Do not recommend a rule or mechanism that already exists; diagnose why it failed to govern the session instead.

### 4. Diagnose before recommending

For every case, build a short causal chain:

1. Observable failure from the evidence bundle.
2. Immediate mechanism that produced it.
3. Governing boundary that could have prevented, detected, or shortened it.
4. Counterfactual: what would probably have happened if the proposed remedy already existed?

Separate evidence from inference. User corrections and failing tool output are evidence; intent, model capability, and causation are usually inference. Lower confidence when the bundle is partial, linkage is weak, or the decisive runtime state is missing.

Do not mistake these for root causes:

- the final error message when an earlier setup or validation mismatch produced it
- model choice without comparative evidence
- a single handled tool error
- an intentional red test
- a user changing requirements
- a cancelled redundant worker when the parent completed the task and no reusable work was lost
- an upstream service failure that local setup could neither prevent nor detect earlier

A diagnosis may conclude `preventability: no`. That is preferable to a speculative rule.

### 5. Choose the narrowest effective remedy target

Apply this order, stopping at the first target that fully addresses the cause:

1. `project-code`: a product or library defect belongs in the implementation.
2. `project-config`: CI, formatter, type checker, build, environment, or repository configuration can encode the invariant.
3. `project-tooling`: a canonical command, script, fixture, check, or automation can make the correct path reproducible.
4. `project-agents`: a durable repository-specific behavioral constraint cannot reasonably be enforced by code or tooling.
5. `skill`: the failure is specific to a reusable workflow and should be fixed in that skill's steps, schema, or deterministic helper.
6. `harness`: the shared agent runtime, tool contract, scheduling, cancellation, persistence, or transcript behavior caused the failure.
7. `system`: machine-wide packages, services, environment, permissions, or operating-system configuration caused it.
8. `global-agents`: the behavioral rule applies across unrelated projects, is not already supplied by system/developer instructions, and cannot be enforced at a stronger technical boundary.
9. `none`: the incident is not preventable or evidence is insufficient to justify a change.

Prefer executable enforcement over prose. Do not add an AGENTS.md rule for facts that belong in code, CI, a script, or project documentation. Do not use global AGENTS.md as a dumping ground for one project's lesson.

A project worker may nominate a global candidate, but only the coordinator can promote it after comparing independent projects. Global promotion normally requires supporting cases from at least two project keys. Write promoted shared findings under `_cross-project`.

### 6. Design the smallest complete remedy

A recommendation must name:

- exact target file, component, command, or configuration boundary when known
- the behavior to add, remove, or change
- why it addresses the causal mechanism
- a verification scenario that would fail before the remedy and pass after it
- limitations when prevention is only partial

Reject remedies that merely say "be careful", restate generic engineering guidance, add redundant prompts, or create speculative abstraction. If an existing instruction was ignored, prefer deterministic enforcement or fix instruction discovery instead of duplicating the sentence.

Do not silently expand from diagnosis into implementation. Findings are proposals.

### 7. Consolidate across cases

After all project workers finish:

- merge findings with the same cause and remedy within a project
- keep independent causes separate even when they share a case
- compare nominated global, skill, harness, and system findings across projects
- promote truly shared mechanisms into `_cross-project`
- keep project-specific manifestations in their project even when the general advice sounds familiar
- ensure every selected case appears in at least one finding, including non-preventable assessments

One finding file describes one root cause and suggested remedy. Follow the exact schema and section order in [finding-format.md](references/finding-format.md). Derive its stable ID with `diagnostic_run.py id`.

### 8. Finalize and validate

Run:

```bash
python3 scripts/diagnostic_run.py finalize --run-dir <diagnostic-run>
```

Finalization must succeed. It rejects malformed findings, unsupported targets, cross-project leakage, non-preventable findings with a remedy target, preventable findings without one, duplicate IDs, and uncovered cases. It writes project and top-level indexes and marks the manifest complete.

Then review the generated indexes and spot-check at least one high-confidence finding, the lowest-confidence finding present, and every cross-project finding against cited evidence and current target files. Report the diagnostic run path, case and finding counts, and a short remedy-target breakdown. Do not claim any proposed remedy was applied.

When the user wants to inspect or act on the proposals, hand the completed run to `agent-session-review`. That skill keeps mutable review state outside this immutable diagnostic run.
