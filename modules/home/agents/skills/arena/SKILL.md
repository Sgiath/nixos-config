---
name: arena
description: "Use for /arena or an explicit request for competing parallel attempts and synthesis."
disable-model-invocation: true
---

# Arena

Produce parallel candidates, choose a base, and adapt the strongest parts into one verified artifact.

## Frame and generate

Define the artifact and 3–6 concrete acceptance criteria. Candidates receive the same task and grounding; reserve the scoring rubric for selection.

Use the harness’s configured or available arena runners, honoring any user-selected models. Prefer model diversity where supported. Choose additional runners for distinct design directions; repeated instances of one model can suit generation-heavy tasks. Give every candidate an isolated worktree or `/tmp/arena-<slug>/candidate-<n>/` directory.

Launch candidates together with the harness's background subagent mechanism. Each writes its artifact and a short rationale naming alternatives considered and rejected. Record failed candidates as dropouts and continue with the available outputs.

## Judge and synthesize

After candidates finish, launch one read-only judge, using a different model family than the parent where available. Give it the rubric and path-labelled candidates. While it scores each criterion and recommends a base, inspect every candidate's artifact and rationale.

Compare criterion-level scores with the judge; resolve disagreements using the actual artifacts and rationales. Prefer the easier-to-maintain interface when candidates tie. Adapt useful parts from losing candidates without mixing incompatible designs. If candidates converge, no graft is needed; if divergence exposes missing requirements, reframe rather than average them.

## Deliver

Verify the synthesized artifact against the acceptance criteria. Fix failed integration or revisit the framing when the requirements were wrong.

Return the artifact and a short synthesis note alongside it: base and reason, judge's verdict, grafts and their sources, rejected alternatives, dropouts, and verification result.
