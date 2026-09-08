---
name: jellyfin-naming
description: "Use when renaming or moving movies, TV series, or music for Jellyfin matching."
disable-model-invocation: true
---

# Jellyfin naming

Read the matching format reference before planning moves: [movies](references/movies.md), [series](references/series.md), or [music](references/music.md). Use [shared rules](references/shared.md) for forbidden characters, IDs, sidecars, stacking, 3D, and extras. This skill does not define books, audiobooks, or music-video layouts.

## Move contract

- One movie or album per folder; shows use series → `Season NN` → episodes (`Season 00` for specials). Movie basenames match their folder exactly before version/part suffixes.
- Use verified provider titles, years, and IDs; omit unknown years/IDs. Music tags are authoritative. Do not churn correctly tagged music for cosmetics.
- Never use `< > : " / \ | ? *` inside a path component. Do not combine versions (` - 1080p`) with stacked parts (`-cd1`).
- Keep all sidecars, images, and extras with their media; rename matching sidecar basenames too. Do not overwrite targets.
- Do not remux, transcode, rewrite tags, or delete sources unless asked. Keep extensions except the documented audio-only container renames.

Read [the move workflow](references/moving.md) for classification, dry-run tables, commands, templates, and verification. Present every planned file move; wait for approval for large/destructive sets or populated destinations. Ask about ambiguous identities. After moving, verify media/sidecar placement and report moved count, skipped items, and source leftovers.
