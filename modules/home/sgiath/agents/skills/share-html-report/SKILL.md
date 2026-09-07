---
name: share-html-report
description: "Publish a conversation-based HTML report to sgiath.dev only when explicitly asked to share, host, publish, or run this skill."
compatibility: Requires SSH/SCP access to vesta.local and write access to /data/www/sgiath.dev/llm
disable-model-invocation: true
---

# Share HTML Report

Publication is public. A request to create local HTML alone does not authorize upload. Before writing, remove irrelevant sensitive details; if essential content is sensitive or its public-sharing authorization is unclear, ask one precise question and stop. Never publish secrets, personal/customer data, private messages/recordings, or unclear confidential material.

## Output

Create exactly one themed HTML file in a `mktemp` workspace outside the repository. Use the current UTC date and an ASCII kebab-case slug: `/data/www/sgiath.dev/llm/YYYY-MM-DD-<topic-slug>.html`, served at `https://sgiath.dev/llm/YYYY-MM-DD-<topic-slug>.html`. Do not overwrite an existing report without explicit replacement authorization; append `-HHMMSS` otherwise. Remove temporary artifacts on success or failure; never add a report to Git.

## References

- [Theme and graph contract](references/theme.md): shared assets, semantic layout, utility classes, graph eligibility/schema, analytics. Read before building.
- [Build and publish workflow](references/publishing.md): safety gate, temporary paths, static checks, bounded optional screenshot, SSH/SCP, asset checks, collision handling, checksum/HTTP verification, and cleanup. Read before execution.
- [Rendered sample](references/sample.html), [stylesheet](references/report.css).

Use semantic desktop-only HTML; do not add mobile compatibility. Prefer tables/lists/steps to graphs. Load graph scripts only when non-linear relationships and useful drag/pan/zoom justify them.

Return the public URL, checksum-match and local-cleanup confirmations, and whether the optional single-screenshot check ran. Do not claim success before deployment verification.
