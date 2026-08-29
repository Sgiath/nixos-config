# Diagnostic finding format

The diagnostic run is a private, derived companion to one completed `agent-session-evidence` run. It must remain local because findings can quote private source, prompts, tool output, and company context.

## Directory layout

```text
<diagnostic-run>/
  manifest.json
  case-inventory.jsonl
  index.md
  projects/
    <project-slug>/
      index.md
      findings/
        <finding-id>.md
    _cross-project/
      index.md
      findings/
        <finding-id>.md
```

`diagnostic_run.py prepare` creates the manifest, inventory, and project directories. `finalize` validates finding files, requires every evidence case to be covered, and writes the indexes.

## Finding identity

One finding represents one root cause and one remedy placement. Merge cases only when the same causal failure and remedy apply. Split a case when independent causes require different remedies.

Derive the ID with the helper so reruns remain stable:

```bash
python3 scripts/diagnostic_run.py id \
  --case-id case_... \
  --root-cause-key '<short durable cause identity>' \
  --remedy-target project-tooling
```

Pass every contributing case with another `--case-id`. The helper sorts and deduplicates them before hashing.

## Required Markdown

The filename must be `<finding_id>.md`. Use inline YAML lists; the deterministic validator intentionally accepts only the small frontmatter subset below.

```markdown
---
schema_version: 1
finding_id: finding_...
project_slug: project-slug
project_key: canonical project identity
evidence_cases: [case_..., case_...]
preventability: yes|partial|no
confidence: high|medium|low
remedy_target: project-code|project-config|project-tooling|project-agents|global-agents|skill|harness|system|none
status: proposed
---

# Concise causal finding

## Diagnosis
State what failed and distinguish the root cause from the observed symptom. Mark material inference as inference.

## Evidence
Cite exact case sections, transcript record IDs, current project files, and existing instructions that support or contradict the diagnosis.

## Root cause
Give the shortest causal chain that explains the evidence. State what remains unknown.

## Preventability
Use `yes` only when a concrete counterfactual would probably have prevented the failure. Use `partial` when it would only reduce likelihood, shorten recovery, or improve detection. Use `no` for incidental, external, or unsupported failures.

## Recommended remedy
Propose the smallest concrete change. For `preventability: no`, say that no preventive change is justified and do not invent one.

## Placement rationale
Explain why the remedy belongs at the selected target and why that scope is neither too narrow nor too broad.

## Alternatives rejected
Name plausible but weaker placements or changes and explain why they would not address the cause.

## Verification plan
Describe an observable check that would prove the proposed remedy prevents or catches the failure. Do not claim the remedy has been implemented.

## Source map
List every evidence case and current project, instruction, skill, harness, or system file inspected.
```

A non-preventable finding must use `remedy_target: none`. Every other finding must choose a concrete target.

## Cross-project findings

Use `projects/_cross-project/findings/` with both `project_slug` and `project_key` set to `_cross-project` when a finding cites cases from at least two distinct project slugs. A case already emitted by the evidence collector under `projects/_cross-project/cases/` also qualifies by itself because its case bundle is the source-verified cross-project link. Cross-project remedy targets are limited to `global-agents`, `skill`, `harness`, `system`, or `none`.

Do not move a finding to `_cross-project` merely because its lesson sounds generic. Require repeated evidence across projects or a source-verified shared mechanism that caused failures in more than one project.

## Coverage

Every input case must appear in at least one finding, including cases that yield `preventability: no`. This records that the case was assessed without padding the output with speculative recommendations. A case may appear in several findings when independent causes are supported.
