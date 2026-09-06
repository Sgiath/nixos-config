---
name: conventional-commit
description: "Use when creating or splitting Git commits, or drafting or reviewing Conventional Commit messages."
---

# Conventional Commit

Use `type(scope): subject`, with optional body and footer separated by blank lines. Scope may be omitted when none is useful; breaking changes use `!` before the colon.

## Messages

- Types: `feat`, `fix`, `docs`, `test`, `refactor`, `perf`, `style`, `build`, `ci`, `chore`, unless the repo has another convention. Dependencies and lockfiles normally use `build`.
- Choose a short lowercase scope and a specific imperative subject without a final period.
- Add a body for non-obvious reasons, tradeoffs, migrations, or risks; wrap it readably. Use `BREAKING CHANGE:` for breaking-change detail when helpful.
- Include `Fixes sc-12345` for a known Shortcut ticket, or `Fixes TEAM-123` for a known Linear issue instead. Use only IDs established in the request, branch, or context; otherwise omit the footer.
- Read [the specification](references/specs.md) for edge cases.

## Creating commits

A request to draft or review a message is not a request to commit. When committing is requested, inspect `git status --short`, `git diff`, and untracked files. For “commit everything”, cover all intended changes, grouped by logical intent rather than file list.

Stage each coherent, buildable unit deliberately with pathspecs or `git add -p`; inspect `git diff --cached` before committing. Keep inseparable implementation, regression coverage, and generated changes together; split independent concerns. Check that the message type, scope, and real ticket/breaking-change footers match the staged change.

Ask before including secrets, huge generated artifacts, machine-local state, or apparently unrelated files. Do not rewrite, revert, or discard user changes without explicit instruction. Run relevant checks when practical and report checks not run.

Finish with created commits and remaining uncommitted changes.
