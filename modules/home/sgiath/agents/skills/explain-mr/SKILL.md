---
name: explain-mr
description: Explain every logical production-code addition in a GitLab MR with unpublished line-level draft review comments grounded in original Linear and Notion requirements. Use when asked to "explain this MR", "add explanatory review comments", "comment why each change is needed", or invoked as /explain-mr.
---

# Explain MR

Add an unpublished GitLab draft review comment to every logical production-code addition in an MR. Each comment explains what the addition does, why it exists, and why the originating ticket needs it. Cite original Linear issues or Notion requirements, never generated plans.

## Scope

- Default to the MR for the current branch. Accept an explicit MR IID or URL when supplied.
- Comment production code only.
- Exclude Markdown, documentation, tests, test helpers, fixtures, snapshots, generated files, lockfiles, and embedded rule examples whose purpose is testing.
- Comment additions only. Do not anchor comments to deletion-only changes.
- Cover every logical addition, not every literal added line. Separate comments are expected for distinct wiring, business rules, terminal outputs, helpers, migrations, runtime configuration, or version bumps. Do not comment an import or alias separately when the same explanation belongs on the code that uses it.

## Deterministic Gates

- Load the `gitlab-access` skill and verify `glab auth status` before doing anything else.
- Verify the target project, MR IID, source branch, target branch, and MR URL before posting.
- This repository is Remote company work. Read Remote Linear through `linear-remote` and Remote Notion through `notion-remote`. Never write to either source system.
- Do not use generated plans, remediation plans, implementation plans, repository Markdown, or test descriptions as requirement sources. Follow links back to the original Linear issue and Notion user story or acceptance criteria.
- Never send internal ticket, Notion, or code content to web search. The GitLab Draft Notes API documentation is public; product requirements are not.
- Draft notes are GitLab writes. Post only when the current request explicitly says to add, create, submit, or draft comments, or explicitly invokes `/explain-mr`. If the user asks for a preview, stop before the POST calls.
- Never publish drafts. Do not call the Notes API, Discussions API, `glab mr note`, `draft_notes/:id/publish`, or `draft_notes/bulk_publish`.
- Preserve all existing drafts. Never edit, delete, or publish a pre-existing draft.
- Make the workflow idempotent: list existing drafts first and skip an intended comment when the same path, line, and materially identical explanation already exists.

## Phase 1: Discover the MR and its original sources

1. Load `gitlab-access`, then verify authentication:

   ```bash
   glab auth status
   ```

2. Resolve the MR. For the current branch:

   ```bash
   glab mr view --output json
   ```

   Record:

   - `project_id`
   - `iid`
   - `web_url`
   - `source_branch`
   - `target_branch`
   - `diff_refs.base_sha`
   - `diff_refs.start_sha`
   - `diff_refs.head_sha`

   Stop if there is no open MR or if the MR is not the one the user intended.

3. Fetch the complete MR changes:

   ```bash
   glab api "projects/<project_id>/merge_requests/<iid>/changes"
   ```

4. Identify the originating Remote Linear issue from the MR description, branch, title, or explicit user input. Fetch it with `linear-remote`, including relations. Follow directly relevant linked issues when they own a requirement implemented by the MR.

5. Follow Notion user-story or acceptance-criteria links from those Linear issues with `notion-remote`. Prefer the most specific original source:

   1. Notion acceptance criterion or full user story.
   2. Remote Linear issue description.
   3. A related Remote Linear issue that owns the requirement.

   The MR description can help locate sources, but it is not the source of truth. Never cite a generated plan merely because the MR links to it.

## Phase 2: Inventory logical production-code additions

1. Filter the MR changes before drafting comments:

   - Exclude paths ending in `.md`.
   - Exclude `test/`, `tests/`, `spec/`, fixtures, snapshots, and files matching `*_test.exs` or equivalent test naming.
   - Exclude generated files and lockfiles.
   - In implementation files, exclude added examples or fixtures used only as tests.
   - Include runtime source, migrations, production configuration, and engine-version changes when they alter behavior.

2. Read each remaining diff and group added lines into logical units. Typical units are:

   - rule-chain or dependency wiring;
   - a new business rule or calculation;
   - an ungated intermediate introduced to preserve internal math;
   - a public/terminal gate introduced to enforce output semantics;
   - a shared production helper;
   - a schema, migration, or input mapping;
   - an immutable engine-version bump.

3. Anchor each unit to its first representative added line. The anchor must be a valid `new_line` in the MR diff. For a new file, use the new path as both `old_path` and `new_path`, matching the GitLab changes payload.

4. Before posting, verify that every production-code addition is covered exactly once. A comment may explain several tightly coupled added lines in one hunk, but must not hide a separate design decision.

## Phase 3: Write source-grounded explanations

Each comment should be concise and answer all three questions:

1. **What was added?** Name the rule, boundary, helper, wiring, or behavior.
2. **Why is it needed?** Explain the failure, invariant, calculation sequence, or output contract it establishes.
3. **Why does the originating ticket need it?** Connect it explicitly to the end-to-end behavior requested by the ticket.

Use inline source links, for example:

```markdown
This keeps the regular calculation as an ungated intermediate so the aggregate path can subtract the real regular-only tax even when the public output is zero. [NEOPOL-69](https://linear.app/remote/issue/NEOPOL-69/...) needs that distinction to return the correct supplemental FIT through the API; the aggregate formula comes from [ST-US-CALC-005](https://app.notion.com/p/...).
```

Writing rules:

- State the rationale directly; do not narrate the diff.
- Cite the originating ticket in every comment when the user asks why each addition is needed for that ticket.
- Add the more specific Notion story or related Linear issue when it owns the calculation detail.
- Do not mention generated plans, plan filenames, implementation phases, or sibling MRs.
- Do not claim a requirement that the original sources do not contain. If the rationale is an implementation invariant rather than a product requirement, say so and connect it to the sourced behavior it protects.
- Avoid repetitive boilerplate while keeping each comment understandable on its own.

## Phase 4: Create unpublished line-level drafts

GitLab's Draft Notes API is the required mechanism. Ordinary notes and discussions publish immediately and are forbidden here.

### List existing drafts

```bash
glab api --hostname gitlab.com \
  "projects/<project_id>/merge_requests/<iid>/draft_notes"
```

Draft notes are visible only to their author until published.

### Create one draft

Endpoint:

```text
POST /projects/:project_id/merge_requests/:iid/draft_notes
```

JSON payload:

```json
{
  "note": "<source-grounded explanation>",
  "position": {
    "base_sha": "<diff_refs.base_sha>",
    "start_sha": "<diff_refs.start_sha>",
    "head_sha": "<diff_refs.head_sha>",
    "position_type": "text",
    "old_path": "<old_path from changes payload>",
    "new_path": "<new_path from changes payload>",
    "new_line": 42
  }
}
```

Send JSON through stdin. The `Content-Type` header is required; omitting it can return HTTP 415:

```bash
python - <<'PY'
import json
import subprocess

payload = {
    "note": "<comment>",
    "position": {
        "base_sha": "<base_sha>",
        "start_sha": "<start_sha>",
        "head_sha": "<head_sha>",
        "position_type": "text",
        "old_path": "<old_path>",
        "new_path": "<new_path>",
        "new_line": 42,
    },
}

subprocess.run(
    [
        "glab",
        "api",
        "--hostname",
        "gitlab.com",
        "--method",
        "POST",
        "--header",
        "Content-Type: application/json",
        "projects/<project_id>/merge_requests/<iid>/draft_notes",
        "--input",
        "-",
    ],
    input=json.dumps(payload),
    text=True,
    check=True,
)
PY
```

For multiple comments, send them sequentially and record every returned draft ID. On failure, stop and report how many drafts were created before the failure; do not retry blindly or publish anything.

### Position failures

If GitLab rejects a position:

1. Re-fetch the MR and changes.
2. Confirm the diff refs have not changed.
3. Confirm the anchor is an added `new_line`, not merely a context or removed line.
4. Recalculate the new line from the hunk header and current-side line counter.
5. Retry only the failed draft with corrected position data.

## Phase 5: Verify without publishing

1. List drafts again with the Draft Notes API.
2. Identify the newly returned draft IDs.
3. Assert that:

   - the number of new drafts equals the number of planned logical additions;
   - every draft has a line position;
   - every draft path is production code;
   - no draft targets Markdown, tests, fixtures, snapshots, generated files, or lockfiles;
   - every note cites an original Linear or Notion source;
   - no pre-existing draft changed;
   - all new notes remain drafts.

4. Report the count and MR URL. Do not include test or CI summaries in GitLab comments.

## Official API Reference

- [GitLab Draft Notes API](https://docs.gitlab.com/api/draft_notes/)
