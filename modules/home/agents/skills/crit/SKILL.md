---
name: crit
description: "Run an interactive Crit review only when the user invokes /crit or explicitly asks to use Crit."
---

# Review with Crit

A generic review request does not authorize Crit. For programmatic comments, JSON, or forge sync, use `crit-cli` instead.

Read [the review loop](references/review-loop.md) when invoked. It covers mode detection, foreground launch, feedback, replies, and repeat rounds. Wait for each foreground command to finish; do not read feedback early or replace Finish Review with a chat confirmation. Use the command printed by Crit to start the next round; stop when approved with no comments.

- Resolve comments only at the user's explicit request.
- Confirm network exposure: Crit has no authentication; reachable users can read the repo and post comments that may trigger agents. Keep it on loopback behind Tailscale Serve or an SSH tunnel.
- Publish only when asked to share; relay the resulting URL. Network and sharing commands are in the same reference.
