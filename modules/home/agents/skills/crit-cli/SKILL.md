---
name: crit-cli
description: "Use for Crit comments, review JSON, sharing/unpublishing, and GitHub or GitLab review sync; not the interactive review loop."
user-invocable: false
---

# Crit CLI

Use `crit` for the interactive loop only after an explicit `/crit` or request to use Crit, never from a generic “review” request.

- [Comments and review JSON](references/comments.md): reading, sessions, scopes, anchors, authoring, bulk schema, replies, and plan targeting.
- [Forge sync and sharing](references/publishing.md): pull/push, review events, publication, visibility, QR codes, and deletion tokens.

Pass `--author 'Hermes'` for CLI comments; line numbers refer to the file on disk, not the diff. Resolve only when explicitly asked (including JSON `resolve`).

Publishing or pushing feedback requires user authorization; loading this reference is not permission to publish or approve. When sessions are ambiguous, use `crit status --json` and `--session <id>` rather than guessing.
