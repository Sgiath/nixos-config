# Forge sync and sharing

Publish or push only with user authorization.

## GitHub PR / GitLab MR Integration

```bash
crit pull [number|url]                                   # Fetch PR/MR review comments into the review file
crit push [--dry-run] [--event <type>] [-m <msg>] [n]    # Post review comments to a PR/MR
crit pull --forge gitlab 42                              # Force GitLab when auto-detect is ambiguous
```

Requires `gh` CLI installed and authenticated. PR number is auto-detected from the current branch.

`--event` values: `comment` (default), `approve`, `request-changes`. `-m` adds a review-level body message.

## Sharing

```bash
crit share <file> [file...]                          # Upload and print URL
crit share --qr <file>                               # Also print QR code (terminal only)
crit share --org <slug> <file>                       # Share under an organization
crit share --org <slug> --visibility unlisted <file> # Org share with explicit visibility
crit unpublish [file...]                              # Remove shared review
```

- **Always relay the output** — copy the URL (and QR if used) into your response. Don't make the user dig through tool output.
- **`--qr` is terminal-only** — skip in mobile apps, web chat UIs, or anywhere Unicode block characters won't render correctly.
- **`--org <slug>`** shares under an organization. Visibility defaults to `organization` (members only). Override with `--visibility` (`organization`, `unlisted`, `public`).
- If a review file exists, comments for the shared files are included automatically.
- **Unpublish uses the persisted delete token** in the review file — no extra args needed.